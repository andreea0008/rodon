#!/bin/bash
set -euo pipefail

# ═══════════════════════════════════════════════════════
#  RodON macOS DMG build
#  Xcode signature preserved, Qt embedded manually
# ═══════════════════════════════════════════════════════

# ── Config ──
SOURCE_APP="$HOME/Develop/RodonVpn/build/Qt_6_11_2_for_macOS_Release/Release/RodON.app"
STAGING="$HOME/Develop/RodonVpn/build/dmg-staging"
APP="$STAGING/RodON.app"
QT="$HOME/Qt/6.11.2/macos"
SPARKLE="/opt/homebrew/Caskroom/sparkle/2.7.0/Sparkle.framework"
DMG="$HOME/Develop/RodonVpn/RodON.dmg"
SIGN="Developer ID Application: Andrii Leochko (H8GLL2MY9E)"

[ -d "$SOURCE_APP" ] || { echo "ERROR: збери Release в Qt Creator: $SOURCE_APP"; exit 1; }

echo "==> [1/6] Copy Xcode bundle to staging"
rm -rf "$STAGING" && mkdir -p "$STAGING"
cp -R "$SOURCE_APP" "$APP"

echo "==> [2/6] Copy Qt frameworks (minimal set)"
mkdir -p "$APP/Contents/Frameworks"
QT_FRAMEWORKS=(
    # Core
    QtCore QtGui QtNetwork QtOpenGL QtDBus
    QtConcurrent QtPrintSupport QtWidgets QtSvg
    # QML runtime
    QtQml QtQmlCore QtQmlModels QtQmlMeta QtQmlWorkerScript
    # Quick
    QtQuick QtQuickLayouts QtQuickTemplates2 QtQuickEffects
    # Controls + styles
    QtQuickControls2 QtQuickControls2Impl
    QtQuickControls2Basic QtQuickControls2BasicStyleImpl
    QtQuickControls2MacOSStyleImpl
    QtQuickControls2Fusion QtQuickControls2FusionStyleImpl
    QtQuickControls2Material QtQuickControls2MaterialStyleImpl
    # Effects & Lottie
    QtShaderTools QtLottie
    # Dialogs (потрібне для QML)
    QtQuickDialogs2 QtQuickDialogs2QuickImpl QtQuickDialogs2Utils
)
for fw in "${QT_FRAMEWORKS[@]}"; do
    [ -d "$QT/lib/$fw.framework" ] && cp -R "$QT/lib/$fw.framework" "$APP/Contents/Frameworks/"
done

echo "==> [3/6] Copy Sparkle framework"
if [ -d "$SPARKLE" ]; then
    cp -R "$SPARKLE" "$APP/Contents/Frameworks/"
else
    echo "    WARNING: Sparkle not at $SPARKLE"
fi

echo "==> [4/6] Copy Qt plugins"
mkdir -p "$APP/Contents/PlugIns"
for plugin_dir in platforms styles iconengines imageformats tls; do
    [ -d "$QT/plugins/$plugin_dir" ] && cp -R "$QT/plugins/$plugin_dir" "$APP/Contents/PlugIns/"
done
mkdir -p "$APP/Contents/PlugIns/sqldrivers"
cp "$QT/plugins/sqldrivers/libqsqlite.dylib" "$APP/Contents/PlugIns/sqldrivers/" 2>/dev/null || true

echo "==> [5/6] Copy QML modules"
mkdir -p "$APP/Contents/Resources/qml"
QML_MODULES=(
    "QtQuick"
    "QtQml"
    "QtCore"
    "Qt5Compat"
    "Qt"
)
for mod in "${QML_MODULES[@]}"; do
    [ -d "$QT/qml/$mod" ] && cp -R "$QT/qml/$mod" "$APP/Contents/Resources/qml/"
done

echo "==> Add qt.conf"
cat > "$APP/Contents/Resources/qt.conf" << 'EOF'
[Paths]
Plugins = PlugIns
Qml2Imports = Resources/qml
EOF

echo "==> Test staging bundle"
pkill -x RodON 2>/dev/null || true
sleep 1
"$APP/Contents/MacOS/RodON" &
sleep 3
if pgrep -x RodON > /dev/null; then
    echo "    ✅ Staging RUNS"
    pkill -x RodON || true
else
    echo "    ❌ Staging failed — see output above"
    exit 1
fi

echo "==> [6/6] Create DMG"
rm -f "$DMG"
if command -v create-dmg >/dev/null 2>&1; then
    create-dmg --volname "RodON" --window-size 500 320 --icon-size 100 \
      --icon "RodON.app" 130 150 --app-drop-link 370 150 \
      "$DMG" "$APP" 2>/dev/null || \
    hdiutil create -volname "RodON" -srcfolder "$APP" -ov -format UDZO "$DMG"
else
    hdiutil create -volname "RodON" -srcfolder "$APP" -ov -format UDZO "$DMG"
fi

codesign --force --sign "$SIGN" "$DMG"

echo ""
echo "═══════════════════════════════════════"
echo "✅ DONE: $DMG"
du -sh "$DMG"
echo "═══════════════════════════════════════"
echo ""
echo "Тест:"
echo "  sudo rm -rf /Applications/RodON.app"
echo "  open '$DMG'"
echo "  # перетягни RodON.app у Applications у Finder"
echo "  open /Applications/RodON.app"
echo "  # натисни Connect → німецький IP"
