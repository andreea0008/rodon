import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import "../components"


Switch {
    id: switchControl
    width: 36
    height: 20
    Layout.preferredHeight: height
    Layout.preferredWidth: width
    property int space: 3
    indicator: Rectangle {
        width: switchControl.width
        height: switchControl.height
        radius: height / 2
        color: switchControl.checked ? Colors.green : Colors.dim
        border.width: 0
        
        Behavior on color {
            ColorAnimation { duration: 200 }
        }
        
        Rectangle {
            x: switchControl.checked ? parent.width - width - space : space
            y: (parent.height - height) / 2
            width: switchControl.height -(space * 2)
            height: width
            radius: height / 2
            color: switchControl.checked ? Colors.white : Colors.white
            
            Behavior on x {
                NumberAnimation {
                    duration: 200
                    easing.type: Easing.OutCubic
                }
            }
        }
    }
    leftPadding: 0
    rightPadding: 0
}
