import QtQuick
import QtQuick.Controls.Material
import QtQuick.Layouts
import "../"
import "../components"

TextField {
    id: tf
    color: Colors.white
    placeholderText: activeFocus || text.length > 0 ? "" : "Search..."
    placeholderTextColor: "#40ffffff"
    font.pixelSize: 14
    font.weight: 600
    font.family: Fonts.hankenBold
    verticalAlignment: Text.AlignVCenter
    leftPadding: 12
    rightPadding: 12

    background: Rectangle {
        radius: 10
        color: "#1Affffff"
        border.color: parent.activeFocus ? "#4Dc858c6" : "#1Affffff"
        border.width: 1

        Behavior on border.color {
            ColorAnimation { duration: 150 }
        }
    }

    Material.accent: Colors.purple

    cursorDelegate: Rectangle {
        width: tf.activeFocus ? 2 : 0
        color: Colors.white
        radius: 1

        SequentialAnimation on opacity {
            running: tf.activeFocus
            loops: Animation.Infinite
            NumberAnimation { to: 0; duration: 500; easing.type: Easing.InOutQuad }
            NumberAnimation { to: 1; duration: 500; easing.type: Easing.InOutQuad }
        }
    }
}
