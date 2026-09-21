import QtQuick
import QtQuick.Controls.Material
import QtQuick.Layouts
import "../"
import "../components"

ListView {
    clip: true
    maximumFlickVelocity: 3000
    flickDeceleration: 1500
    boundsBehavior: Flickable.DragAndOvershootBounds
    snapMode: ListView.NoSnap
    onMovementStarted: {
        tf.focus = false
        Qt.inputMethod.hide()
    }
    
    add: Transition {
        NumberAnimation {
            property: "opacity"
            from: 0; to: 1
            duration: 200
            easing.type: Easing.OutQuad
        }
        NumberAnimation {
            property: "y"
            from: 20
            duration: 200
            easing.type: Easing.OutQuad
        }
    }
    
    remove: Transition {
        NumberAnimation {
            property: "opacity"
            to: 0
            duration: 150
            easing.type: Easing.InQuad
        }
    }
    
    populate: Transition {
        SequentialAnimation {
            PauseAnimation { duration: index * 30 }
            ParallelAnimation {
                NumberAnimation {
                    property: "opacity"
                    from: 0; to: 1
                    duration: 300
                    easing.type: Easing.OutQuad
                }
                NumberAnimation {
                    property: "y"
                    from: 30
                    duration: 300
                    easing.type: Easing.OutCubic
                }
            }
        }
    }
    
}
