set -euo pipefail
 
# ─────────────────────────── НАЛАШТУВАННЯ ───────────────────────────
PROJECT_DIR="$HOME/Develop/RodonVpn"
XCODE_BUILD="$PROJECT_DIR/build/Qt_6_11_2_for_macOS_Release/Release"
XCODE_APP="$XCODE_BUILD/RodON.app"
 
QT="$HOME/Qt/6.11.2/macos"
SPARKLE_SRC="/opt/homebrew/Caskroom/sparkle/2.7.0/Sparkle.framework"
 
STAGING="$PROJECT_DIR/build/dmg-staging"
APP="$STAGING/RodON.app"
DMG="$PROJECT_DIR/RodON.dmg"
 
SIGN="Developer ID Application: Andrii Leochko (H8GLL2MY9E)"
NOTARY_PROFILE="notarytool-rodon"
 
APP_ENT="$PROJECT_DIR/ios/rodon-macos-nosandbox.entitlements"
EXT_ENT="$PROJECT_DIR/ios/RodonTunnel-macos.entitlements"
 
EXT_ID="com.rodon.vpn.app.tunnel"
EXT_DST="$APP/Contents/Library/SystemExtensions/$EXT_ID.systemextension"
 
LSREG=/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister
 
QT_FRAMEWORKS=(
  QtCore QtGui QtNetwork QtOpenGL QtDBus QtConcurrent QtPrintSupport QtWidgets QtSvg
  QtQml QtQmlCore QtQmlModels QtQmlMeta QtQmlWorkerScript
  QtQuick QtQuickLayouts QtQuickTemplates2 QtQuickEffects
  QtQuickControls2 QtQuickControls2Impl
  QtQuickControls2Basic QtQuickControls2BasicStyleImpl
  QtQuickControls2MacOSStyleImpl
  QtQuickControls2Fusion QtQuickControls2FusionStyleImpl
  QtQuickControls2Material QtQuickControls2MaterialStyleImpl
  QtShaderTools QtLottie
  QtQuickDialogs2 QtQuickDialogs2QuickImpl QtQuickDialogs2Utils
)
QT_PLUGIN_DIRS=(platforms styles tls iconengines imageformats networkinformation)
QML_MODULES=(QtQuick QtQml QtCore Qt5Compat Qt)
 
notarize() {  # notarize <file> — падає, якщо статус не Accepted
  local out id
  out=$(xcrun notarytool submit "$1" --keychain-profile "$NOTARY_PROFILE" --wait 2>&1) || true
  echo "$out"
  id=$(echo "$out" | awk '/^ *id:/{print $2; exit}')
  if ! echo "$out" | grep -q "status: Accepted"; then
    echo "ERROR: нотаризація не пройшла. Лог:"
    [ -n "$id" ] && xcrun notarytool log "$id" --keychain-profile "$NOTARY_PROFILE"
    exit 1
  fi
}
 
sign() {  # sign <path> [entitlements]
  if [ -n "${2:-}" ]; then
    codesign --force --options runtime --timestamp --sign "$SIGN" --entitlements "$2" "$1"
  else
    codesign --force --options runtime --timestamp --sign "$SIGN" "$1"
  fi
}
 
[ -d "$XCODE_APP" ] || { echo "ERROR: немає $XCODE_APP — зроби Release build у Qt Creator"; exit 1; }
 
# ─────────────────────────── [1/10] staging ───────────────────────────
echo "==> [1/10] Copy Xcode bundle to staging"
rm -rf "$STAGING"
mkdir -p "$STAGING"
ditto "$XCODE_APP" "$APP"
 
# ─────────────────────────── [2/10] System Extension ───────────────────────────
echo "==> [2/10] Embed System Extension as $EXT_ID.systemextension"
TUNNEL_SRC=""
for cand in \
  "$XCODE_APP/Contents/Library/SystemExtensions/$EXT_ID.systemextension" \
  "$XCODE_APP/Contents/Library/SystemExtensions/RodonTunnel.systemextension" \
  "$XCODE_BUILD/RodonTunnel.systemextension"; do
  [ -d "$cand" ] && { TUNNEL_SRC="$cand"; break; }
done
[ -n "$TUNNEL_SRC" ] || { echo "ERROR: RodonTunnel.systemextension не знайдено"; exit 1; }
echo "    source: $TUNNEL_SRC"
 
rm -rf "$APP/Contents/PlugIns/RodonTunnel.systemextension" "$APP/Contents/PlugIns/RodonTunnel.appex"
rm -rf "$APP/Contents/Library/SystemExtensions"
mkdir -p "$APP/Contents/Library/SystemExtensions"
ditto "$TUNNEL_SRC" "$EXT_DST"

EXT_BUILD=$(date +%Y%m%d%H%M)
/usr/libexec/PlistBuddy -c "Set :CFBundleVersion $EXT_BUILD" "$EXT_DST/Contents/Info.plist"
echo "Extension CFBundleVersion = $EXT_BUILD"

[ "$(/usr/libexec/PlistBuddy -c 'Print CFBundlePackageType' "$EXT_DST/Contents/Info.plist")" = "SYSX" ] \
  || { echo "ERROR: CFBundlePackageType extension != SYSX"; exit 1; }
[ "$(/usr/libexec/PlistBuddy -c 'Print CFBundleIdentifier' "$EXT_DST/Contents/Info.plist")" = "$EXT_ID" ] \
  || { echo "ERROR: CFBundleIdentifier extension != $EXT_ID"; exit 1; }
 
# ─────────────────────────── [3/10] Qt frameworks ───────────────────────────
echo "==> [3/10] Copy Qt frameworks"
mkdir -p "$APP/Contents/Frameworks"
for fw in "${QT_FRAMEWORKS[@]}"; do
  src="$QT/lib/$fw.framework"
  if [ -d "$src" ]; then
    rm -rf "$APP/Contents/Frameworks/$fw.framework"
    ditto "$src" "$APP/Contents/Frameworks/$fw.framework"
    # прибрати хедери і debug-символи
    rm -rf "$APP/Contents/Frameworks/$fw.framework/Headers" \
           "$APP/Contents/Frameworks/$fw.framework/Versions/A/Headers" \
           "$APP/Contents/Frameworks/$fw.framework/"*.prl \
           "$APP/Contents/Frameworks/$fw.framework/Versions/A/"*_debug 2>/dev/null || true
  else
    echo "    warn: $fw.framework нема у Qt"
  fi
done
 
# ─────────────────────────── [4/10] Sparkle ───────────────────────────
echo "==> [4/10] Copy Sparkle framework"
rm -rf "$APP/Contents/Frameworks/Sparkle.framework"
ditto "$SPARKLE_SRC" "$APP/Contents/Frameworks/Sparkle.framework"
 
# ─────────────────────────── [5/10] Qt plugins ───────────────────────────
echo "==> [5/10] Copy Qt plugins"
mkdir -p "$APP/Contents/PlugIns"
for d in "${QT_PLUGIN_DIRS[@]}"; do
  [ -d "$QT/plugins/$d" ] || continue
  rm -rf "$APP/Contents/PlugIns/$d"
  ditto "$QT/plugins/$d" "$APP/Contents/PlugIns/$d"
done
find "$APP/Contents/PlugIns" -name "*.dSYM" -prune -exec rm -rf {} + 2>/dev/null || true
find "$APP/Contents/PlugIns" -name "*_debug.dylib" -delete 2>/dev/null || true
 
# ─────────────────────────── [6/10] QML ───────────────────────────
echo "==> [6/10] Copy QML modules (без .o/.cpp.o та objects-*)"
mkdir -p "$APP/Contents/Resources/qml"
for m in "${QML_MODULES[@]}"; do
  [ -d "$QT/qml/$m" ] || continue
  rm -rf "$APP/Contents/Resources/qml/$m"
  rsync -a \
    --exclude 'objects-*' --exclude '*.o' --exclude '*.cpp.o' \
    --exclude '*.dSYM' --exclude '*_debug.dylib' --exclude 'test/' \
    "$QT/qml/$m" "$APP/Contents/Resources/qml/"
done
 
cat > "$APP/Contents/Resources/qt.conf" <<'EOF'
[Paths]
Plugins = PlugIns
Qml2Imports = Resources/qml
EOF
 
# ─────────────────────────── [7/10] Signing ───────────────────────────
echo "==> [7/10] Sign (inside-out)"
 
# 7.1 усі dylib (plugins, qml)
find "$APP/Contents/PlugIns" "$APP/Contents/Resources/qml" -type f -name "*.dylib" -print0 |
  while IFS= read -r -d '' f; do sign "$f"; done
 
# 7.2 Qt frameworks
for fw in "$APP/Contents/Frameworks/"Qt*.framework; do sign "$fw"; done
 
# 7.3 інші dylib у Frameworks
find "$APP/Contents/Frameworks" -maxdepth 1 -type f -name "*.dylib" -print0 |
  while IFS= read -r -d '' f; do sign "$f"; done
 
# 7.4 Sparkle (знизу вгору)
SP="$APP/Contents/Frameworks/Sparkle.framework/Versions/B"
for x in "$SP/XPCServices/"*.xpc; do sign "$x"; done
sign "$SP/Autoupdate"
sign "$SP/Updater.app"
sign "$APP/Contents/Frameworks/Sparkle.framework"
 
# 7.5 System Extension
sign "$EXT_DST" "$EXT_ENT"
 
# 7.6 сама апка (останньою)
sign "$APP" "$APP_ENT"
 
echo "==> Verify"
codesign --verify --deep --strict --verbose=2 "$APP"
if codesign -d --entitlements - "$APP" 2>/dev/null | grep -q get-task-allow; then
  echo "ERROR: get-task-allow у підписі"; exit 1
fi
codesign -d --entitlements - "$APP" 2>/dev/null | grep -q "system-extension.install" \
  || { echo "ERROR: немає com.apple.developer.system-extension.install"; exit 1; }
echo "    ✅ signature OK"
 
# ─────────────────────────── [8/10] Notarize app + staple inside ───────────────────────────
echo "==> [8/10] Notarize app bundle"
ZIP="$STAGING/RodON-notarize.zip"
rm -f "$ZIP"
ditto -c -k --keepParent "$APP" "$ZIP"
notarize "$ZIP"
rm -f "$ZIP"

echo "    staple app"
xcrun stapler staple "$APP"
xcrun stapler validate "$APP"
codesign --verify --deep --strict "$APP" || { echo "ERROR: підпис апки зламаний після staple"; exit 1; }
 
# ─────────────────────────── [9/10] DMG ───────────────────────────
echo "==> [9/10] Create + sign DMG"
rm -f "$DMG"
if command -v create-dmg >/dev/null 2>&1; then
  create-dmg \
    --volname "RodON" \
    --window-size 540 380 \
    --icon-size 110 \
    --icon "RodON.app" 140 180 \
    --app-drop-link 400 180 \
    "$DMG" "$APP"
else
  hdiutil create -volname "RodON" -srcfolder "$APP" -ov -format UDZO "$DMG"
fi
codesign --force --timestamp --sign "$SIGN" "$DMG"
 
# ─────────────────────────── [10/10] Notarize DMG ───────────────────────────
echo "==> [10/10] Notarize + staple DMG"
notarize "$DMG"
xcrun stapler staple "$DMG"
xcrun stapler validate "$DMG"
 
# ─────────────────────────── cleanup LaunchServices ───────────────────────────
# Копія апки поза /Applications з тим самим bundle id ламає активацію System Extension
echo "==> Cleanup staging copy from LaunchServices"
"$LSREG" -u "$APP" 2>/dev/null || true
#rm -rf "$APP"
# мертві записи від тимчасових томів create-dmg
#"$LSREG" -dump 2>/dev/null \
 # | awk '/^path:/{p=$0} /^identifier: +com\.rodon\.vpn\.app$/{print p}' \
  #| sed -E 's/^path: +//; s/ \(0x[0-9a-f]+\)$//' | sort -u \
  #| grep -E '^/Volumes/|/dmg-staging/' \
  #| while IFS= read -r p; do "$LSREG" -u "$p" 2>/dev/null || true; done
 
echo ""
echo "═══════════════════════════════════════"
echo "✅ DONE: $DMG"
du -h "$DMG" | cut -f1
echo "Встановлення: відкрий DMG → перетягни в /Applications → Eject DMG"
echo "═══════════════════════════════════════"
 
