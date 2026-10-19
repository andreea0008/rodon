#!/bin/bash
# =============================================================================
# release_update_win.sh - publishes the Windows version of RodON for WinSparkle
# (run on the Mac: the Sparkle EdDSA key and the SSH key live there)
#
#   ./release_update_win.sh RodON-Setup-1.2.3.0.exe
#   ./release_update_win.sh RodON-Setup-1.2.3.0.exe --force   # re-upload the same version
#
# What it does:
#   1. Takes the version from the file name (RodON-Setup-<version>.exe)
#   2. Signs the installer with the same EdDSA key as Sparkle (sign_update)
#   3. Generates updates/appcast-windows.xml
#   4. Uploads the exe, then the appcast (rsync over SSH)
#   5. Checks that both are reachable over HTTPS and the size matches
# =============================================================================
set -euo pipefail

# ---------- Settings (same as release_update.sh) ----------
PROJECT_DIR="$HOME/Develop/RodonVpn"
UPDATES_DIR="$PROJECT_DIR/updates"
SPARKLE_BIN="/opt/homebrew/Caskroom/sparkle/2.7.0/bin"
SERVER="root@2.28.64.194"
SSH_KEY="$HOME/.ssh/rodon"
REMOTE_DIR="/var/www/rodon/updates"
PUBLIC_URL="https://2-28-64-194.sslip.io/updates"
APPCAST="appcast-windows.xml"
# Silent install, no prompts; the installer restarts RodON itself
INSTALLER_ARGS="/SILENT /SUPPRESSMSGBOXES /NORESTART /CLOSEAPPLICATIONS"
# ----------------------------------------------------------

step() { echo; echo "==> $*"; }
die()  { echo "ERROR: $*" >&2; exit 1; }

SRC="${1:-}"; FORCE=0
[ "${2:-}" = "--force" ] && FORCE=1
[ -n "$SRC" ] || die "usage: $0 RodON-Setup-<version>.exe [--force]"
[ -f "$SRC" ] || die "file not found: $SRC"
[ -x "$SPARKLE_BIN/sign_update" ] || die "sign_update not found in $SPARKLE_BIN"
[ -f "$SSH_KEY" ] || die "SSH key not found: $SSH_KEY"
SSH_OPTS=(-i "$SSH_KEY" -o IdentitiesOnly=yes -o ConnectTimeout=10)

# ---------- 1. Version ----------
NAME=$(basename "$SRC")
VERSION=$(echo "$NAME" | sed -nE 's/^RodON-Setup-([0-9]+(\.[0-9]+)*)\.exe$/\1/p')
[ -n "$VERSION" ] || die "cannot read version from '$NAME' (expected RodON-Setup-1.2.3.0.exe)"
VERSION=$(echo "$VERSION" | sed -E 's/\.0$//')   # 1.2.3.0 -> 1.2.3 (as in ProductVersion)
echo "Version: $VERSION"

mkdir -p "$UPDATES_DIR"
DST="$UPDATES_DIR/$NAME"
if [ -f "$DST" ] && ! cmp -s "$SRC" "$DST" && [ $FORCE -eq 0 ]; then
  die "$NAME already exists and differs. Bump the version or use --force"
fi
[ "$SRC" -ef "$DST" ] || cp -f "$SRC" "$DST"

# ---------- 2. Signature ----------
step "Signing with Sparkle EdDSA key"
SIG=$("$SPARKLE_BIN/sign_update" "$DST")          # sparkle:edSignature="..." length="..."
echo "$SIG" | grep -q 'sparkle:edSignature=' || die "sign_update returned: $SIG"
echo "OK: $SIG"

# ---------- 3. appcast ----------
step "Generating $APPCAST"
PUBDATE=$(LC_ALL=C date -u "+%a, %d %b %Y %H:%M:%S +0000")
cat > "$UPDATES_DIR/$APPCAST" <<XML
<?xml version="1.0" encoding="utf-8"?>
<rss version="2.0" xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle">
  <channel>
    <title>RodON for Windows</title>
    <item>
      <title>RodON $VERSION</title>
      <pubDate>$PUBDATE</pubDate>
      <sparkle:version>$VERSION</sparkle:version>
      <sparkle:shortVersionString>$VERSION</sparkle:shortVersionString>
      <enclosure url="$PUBLIC_URL/$NAME"
                 sparkle:os="windows"
                 sparkle:installerArguments="$INSTALLER_ARGS"
                 $SIG
                 type="application/octet-stream"/>
    </item>
  </channel>
</rss>
XML
echo "OK"

# ---------- 4. Upload ----------
step "Uploading to $SERVER:$REMOTE_DIR"
ssh "${SSH_OPTS[@]}" "$SERVER" "mkdir -p '$REMOTE_DIR'" \
  || die "SSH failed. VPN off? IP banned by fail2ban?"
rsync -av --progress -e "ssh ${SSH_OPTS[*]}" "$DST" "$SERVER:$REMOTE_DIR/$NAME"
rsync -av -e "ssh ${SSH_OPTS[*]}" "$UPDATES_DIR/$APPCAST" "$SERVER:$REMOTE_DIR/$APPCAST"

# ---------- 5. HTTPS check ----------
step "Verifying over HTTPS"
for url in "$PUBLIC_URL/$APPCAST" "$PUBLIC_URL/$NAME"; do
  code=$(curl -s -o /dev/null -w "%{http_code}" -I "$url" || echo 000)
  [ "$code" = "200" ] && echo "OK   $code  $url" || die "FAIL $code  $url"
done
REMOTE_SIZE=$(curl -sI "$PUBLIC_URL/$NAME" | awk 'tolower($1)=="content-length:"{print $2}' | tr -d '\r')
LOCAL_SIZE=$(stat -f%z "$DST")
[ "$REMOTE_SIZE" = "$LOCAL_SIZE" ] || die "size on server ($REMOTE_SIZE) != local ($LOCAL_SIZE)"
echo "OK   size $LOCAL_SIZE bytes"

echo
echo "Released RodON $VERSION for Windows"
echo "Feed: $PUBLIC_URL/$APPCAST"
