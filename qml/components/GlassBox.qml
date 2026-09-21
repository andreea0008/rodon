import QtQuick
import Qt5Compat.GraphicalEffects
import QtQuick.Effects
import QtQuick.Controls

Item {
    id: glassContainer
    width: 300
    height: 200
    property int radius: 16
    property real boxOpacity: 0.1
    property real borderOpacity: 0.25
    property int r: 1
    property int g: 1
    property int b: 1

    Rectangle {
        id: glassRect
        anchors.fill: parent
        radius: glassContainer.radius
        color: Qt.rgba(r, g, b, boxOpacity)
        border.width: 1
        border.color: Qt.rgba(r, g, b, borderOpacity)
        
        layer.enabled: true
        layer.effect: MultiEffect {
            blurEnabled: true
            blur: 1.0
            blurMax: 10
        }
    }

    Rectangle {
        anchors.fill: parent
        color: "transparent"
        border.width: 1
        border.color: Qt.rgba(r, g, b, borderOpacity)
        radius: glassContainer.radius
    }

    Behavior on opacity {
        NumberAnimation { duration: 500; easing.type: Easing.InOutQuad }
    }
}
