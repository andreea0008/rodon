#!/bin/bash

set -euo pipefail

# ---------- Налаштування ----------
PROJECT_DIR="$HOME/Develop/RodonVpn"
DMG_SRC="$PROJECT_DIR/RodON.dmg"
STAGED_APP="$PROJECT_DIR/build/dmg-staging/RodON.app"
UPDATES_DIR="$PROJECT_DIR/updates"

SPARKLE_BIN="/opt/homebrew/Caskroom/sparkle/2.7.0/bin"

SERVER="root@2.28.64.194"
SSH_KEY="$HOME/.ssh/rodon"
REMOTE_DIR="/var/www/rodon/updates"
PUBLIC_URL="https://2-28-64-194.sslip.io/updates"
# ----------------------------------

FORCE=0
[ "${1:-}" = "--force" ] && FORCE=1

step() { echo; echo "==> $*"; }
die()  { echo "ERROR: $*" >&2; exit 1; }

SSH_OPTS=(-i "$SSH_KEY" -o IdentitiesOnly=yes -o ConnectTimeout=10)

# ---------- 0. Передумови ----------
step "Checking prerequisites"
[ -f "$DMG_SRC" ]                       || die "немає $DMG_SRC — спершу запусти macos_build.sh"
[ -d "$STAGED_APP" ]                    || die "немає $STAGED_APP — спершу запусти macos_build.sh"
[ -x "$SPARKLE_BIN/generate_appcast" ]  || die "немає generate_appcast у $SPARKLE_BIN"
[ -f "$SSH_KEY" ]                       || die "немає SSH-ключа $SSH_KEY"

# DMG має бути новішим за застейджену апку (тобто зібраний з неї)
if [ "$STAGED_APP" -nt "$DMG_SRC" ]; then
  die "RodON.app у dmg-staging новіший за RodON.dmg — DMG застарів, перезбери"
fi

# ---------- 1. Версія ----------
PLIST="$STAGED_APP/Contents/Info.plist"
VERSION=$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" "$PLIST")
BUILD=$(/usr/libexec/PlistBuddy -c "Print :CFBundleVersion" "$PLIST")
[ -n "$VERSION" ] || die "не вдалося прочитати CFBundleShortVersionString"
echo "Version: $VERSION (build $BUILD)"

DMG_NAME="RodON-$VERSION.dmg"
DMG_DST="$UPDATES_DIR/$DMG_NAME"

# ---------- 2. Нотаризація ----------
step "Checking notarization"
xcrun stapler validate "$DMG_SRC" >/dev/null 2>&1 \
  || die "DMG не нотаризований/не застеплений — Gatekeeper його заблокує"
spctl -a -t open --context context:primary-signature -v "$DMG_SRC" 2>&1 | grep -q "accepted" \
  || die "spctl не приймає DMG"
echo "OK: notarized and accepted by Gatekeeper"

# ---------- 3. EdDSA-ключ ----------
step "Checking Sparkle EdDSA key"
APP_PUBKEY=$(/usr/libexec/PlistBuddy -c "Print :SUPublicEDKey" "$PLIST" 2>/dev/null || true)
KEYCHAIN_PUBKEY=$("$SPARKLE_BIN/generate_keys" -p 2>/dev/null | tail -1 | tr -d '[:space:]' || true)
[ -n "$APP_PUBKEY" ]      || die "в Info.plist апки немає SUPublicEDKey — апка не прийме оновлення"
[ -n "$KEYCHAIN_PUBKEY" ] || die "у Keychain немає приватного EdDSA-ключа Sparkle (generate_keys -p порожньо)"
[ "$APP_PUBKEY" = "$KEYCHAIN_PUBKEY" ] \
  || die "SUPublicEDKey в апці ($APP_PUBKEY) ≠ ключ у Keychain ($KEYCHAIN_PUBKEY)"
echo "OK: $APP_PUBKEY"

FEED=$(/usr/libexec/PlistBuddy -c "Print :SUFeedURL" "$PLIST" 2>/dev/null || true)
if [ "$FEED" != "$PUBLIC_URL/appcast.xml" ]; then
  echo "WARNING: SUFeedURL в апці = '$FEED'"
  echo "         очікується      = '$PUBLIC_URL/appcast.xml'"
  echo "         Ця версія сама не шукатиме оновлень за цим сервером."
fi

# ---------- 4. Копія DMG ----------
step "Preparing $DMG_NAME"
mkdir -p "$UPDATES_DIR"
if [ -f "$DMG_DST" ] && [ $FORCE -eq 0 ]; then
  if cmp -s "$DMG_SRC" "$DMG_DST"; then
    echo "Already prepared (identical), continuing"
  else
    die "$DMG_NAME уже існує і відрізняється. Підвищ версію або запусти з --force"
  fi
else
  cp -f "$DMG_SRC" "$DMG_DST"
  echo "Copied → $DMG_DST"
fi

# ---------- 5. appcast ----------
step "Generating appcast.xml"
"$SPARKLE_BIN/generate_appcast" --download-url-prefix "$PUBLIC_URL/" "$UPDATES_DIR"
grep -q "$DMG_NAME" "$UPDATES_DIR/appcast.xml" || die "appcast.xml не містить $DMG_NAME"
grep -q "sparkle:edSignature" "$UPDATES_DIR/appcast.xml" || die "в appcast.xml немає підпису edSignature"
echo "OK: appcast.xml contains $DMG_NAME with signature"

# ---------- 6. Заливка ----------
step "Uploading to $SERVER:$REMOTE_DIR"
ssh "${SSH_OPTS[@]}" "$SERVER" "mkdir -p '$REMOTE_DIR'" \
  || die "SSH не підключається. Перевір: VPN вимкнений? IP не в бані fail2ban? ключ $SSH_KEY є на сервері?"

# DMG спершу, appcast останнім — щоб клієнти не побачили запис на ще не залитий файл
rsync -av --progress -e "ssh ${SSH_OPTS[*]}" --exclude 'appcast.xml' --exclude '.*' \
  "$UPDATES_DIR/" "$SERVER:$REMOTE_DIR/"
rsync -av -e "ssh ${SSH_OPTS[*]}" "$UPDATES_DIR/appcast.xml" "$SERVER:$REMOTE_DIR/appcast.xml"

# ---------- 7. Перевірка по HTTPS ----------
step "Verifying over HTTPS"
check() {
  local url="$1" code
  code=$(curl -s -o /dev/null -w "%{http_code}" -I "$url" || echo "000")
  if [ "$code" = "200" ]; then echo "OK   $code  $url"; else echo "FAIL $code  $url"; return 1; fi
}
check "$PUBLIC_URL/appcast.xml"
check "$PUBLIC_URL/$DMG_NAME"

REMOTE_SIZE=$(curl -sI "$PUBLIC_URL/$DMG_NAME" | awk 'tolower($1)=="content-length:"{print $2}' | tr -d '\r')
LOCAL_SIZE=$(stat -f%z "$DMG_DST")
[ "$REMOTE_SIZE" = "$LOCAL_SIZE" ] \
  || die "розмір на сервері ($REMOTE_SIZE) ≠ локальний ($LOCAL_SIZE)"
echo "OK   size $LOCAL_SIZE bytes"

echo
echo "Released RodON $VERSION (build $BUILD)"
echo "Feed: $PUBLIC_URL/appcast.xml"
