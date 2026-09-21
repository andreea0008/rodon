import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts

import "../components"

Drawer {
    id: drawer
    width: parent.width
    height: 440
    edge: Qt.BottomEdge
    modal: false
    property color backgroundColor: Colors.dim
    
    enter: Transition {
        NumberAnimation {
            property: "position"
            duration: 400
            easing.type: Easing.OutCubic
        }
    }
    exit: Transition {
        NumberAnimation {
            property: "position"
            duration: 300
            easing.type: Easing.InCubic
        }
    }
    
    background: GlassBox {
        width: drawer.width
        height: drawer.height
        radius: 16
        boxOpacity: 0.1
        // color: backgroundColor
        // border.color: "#54737373"
        // border.width: 1
    }
    
}
