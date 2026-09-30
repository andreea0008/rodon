#!/bin/bash
set -euo pipefail

SOURCE_APP="$HOME/Develop/RodonVpn/build/Qt_6_11_2_for_macOS_Release/Release/RodON.app"
STAGING="$HOME/Develop/RodonVpn/build/dmg-staging"
APP="$STAGING/RodON.app"
QT="$HOME/Qt/6.11.2/macos"
DMG="$HOME/Develop/RodonVpn/RodON.dmg"
SIGN="Developer ID Application: Andrii Leochko (H8GLL2MY9E)"

[ -d "$SOURCE_APP" ] || { echo "ERROR: збери Release в Qt Creator"; exit 1; }

echo "==> Copy Xcode bundle to staging"
rm -rf "$STAGING" && mkdir -p "$STAGING"
cp -R "$SOURCE_APP" "$APP"

echo "==> Copy Qt frameworks"
mkdir -p "$APP/Contents/Frameworks"
for fw in QtCore QtGui QtQuick QtQml QtNetwork QtOpenGL QtWidgets QtDBus \
          QtQmlModels QtQmlWorkerScript QtQmlMeta QtQuickControls2 \
          QtQuickControls2Impl QtQuickTemplates2 QtQuickLayouts QtSvg \
          QtConcurrent QtPrintSupport QtQmlCore QtQuickDialogs2 \
          QtQuickDialogs2QuickImpl QtQuickDialogs2Utils; do
    [ -d "$QT/lib/$fw.framework" ] && cp -R "$QT/lib/$fw.framework" "$APP/Contents/Frameworks/"
done

echo "==> Copy Qt plugins"
mkdir -p "$APP/Contents/PlugIns"
for plugin_dir in platforms styles iconengines imageformats tls; do
    [ -d "$QT/plugins/$plugin_dir" ] && cp -R "$QT/plugins/$plugin_dir" "$APP/Contents/PlugIns/"
done
mkdir -p "$APP/Contents/PlugIns/sqldrivers"
cp "$QT/plugins/sqldrivers/libqsqlite.dylib" "$APP/Contents/PlugIns/sqldrivers/" 2>/dev/null || true

echo "==> Copy ALL QML modules"
mkdir -p "$APP/Contents/Resources/qml"
cp -R "$QT/qml/"* "$APP/Contents/Resources/qml/"

echo "==> Add qt.conf"
cat > "$APP/Contents/Resources/qt.conf" << 'EOF'
[Paths]
Plugins = PlugIns
Qml2Imports = Resources/qml
EOF

echo "==> Create DMG"
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
echo "✅ DONE: $DMG"
ls -lh "$DMG"
echo ""
echo "Тест:"
echo "  sudo rm -rf /Applications/RodON.app"
echo "  open '$DMG'    # перетягни в Applications"
echo "  open /Applications/RodON.app"
