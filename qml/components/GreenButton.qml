import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import "../"

Rectangle {
    id: control
    width: implicitWidth + 12
    color: "#2AA352"
    radius: 8
    opacity: mouseButton.pressed || !enabled ? 0.7 : 1.0
    required property string text
    property color textColor: Colors.white
    readonly property bool useIcon: icon.length > 10
    property string icon: ""
    signal clicked()
    
    
    RowLayout {
        anchors.centerIn: parent
        width: Math.min(parent.width - 6, implicitWidth)
        height: parent.height
        spacing: 4

        Image {
            Layout.preferredHeight: 16
            Layout.preferredWidth: Layout.preferredHeight
            Layout.alignment: Qt.AlignVCenter
            source: icon
            antialiasing: true
            smooth: true
            visible: useIcon
        }

        VText {
            Layout.preferredHeight: paintedHeight
            Layout.alignment: Qt.AlignVCenter
            text: control.text
            color: textColor
            font.pixelSize: 12
            weight: 600
            verticalAlignment: Text.AlignVCenter
            fontSizeMode: Text.HorizontalFit
            minimumPixelSize: 12
        }
    }
    
    MouseArea {
        id: mouseButton
        anchors.fill: parent
        onClicked: {
            control.clicked()
        }
    }
}
