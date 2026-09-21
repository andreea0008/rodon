import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts

StackView {
    id: sv
    anchors.fill: parent
    property real k: 1.3
    pushEnter: Transition {
        ParallelAnimation {
            NumberAnimation {
                property: "x"
                from: sv.width
                to: 0
                duration: 350 * sv.k
                easing.type: Easing.OutCubic
            }
            NumberAnimation {
                property: "opacity"
                from: 0
                to: 1
                duration: 250 * sv.k
                easing.type: Easing.OutQuad
            }
        }
    }
    pushExit: Transition {
        ParallelAnimation {
            NumberAnimation {
                property: "x"
                from: 0
                to: -sv.width * 0.3
                duration: 350 * sv.k
                easing.type: Easing.OutCubic
            }
            NumberAnimation {
                property: "opacity"
                from: 1
                to: 0
                duration: 250 * sv.k
                easing.type: Easing.OutQuad
            }
        }
    }
    popEnter: Transition {
        ParallelAnimation {
            NumberAnimation {
                property: "x"
                from: -sv.width * 0.3
                to: 0
                duration: 350 * sv.k
                easing.type: Easing.OutCubic
            }
            NumberAnimation {
                property: "opacity"
                from: 0
                to: 1
                duration: 250 * sv.k
                easing.type: Easing.OutQuad
            }
        }
    }
    popExit: Transition {
        ParallelAnimation {
            NumberAnimation {
                property: "x"
                from: 0
                to: sv.width
                duration: 350 * sv.k
                easing.type: Easing.OutCubic
            }
            NumberAnimation {
                property: "opacity"
                from: 1
                to: 0
                duration: 250 * sv.k
                easing.type: Easing.OutQuad
            }
        }
    }
    replaceEnter: Transition {
        NumberAnimation {
            property: "opacity"
            from: 0
            to: 1
            duration: 200 * sv.k
            easing.type: Easing.OutQuad
        }
    }
    replaceExit: Transition {
        NumberAnimation {
            property: "opacity"
            from: 1
            to: 0
            duration: 200 * sv.k
            easing.type: Easing.OutQuad
        }
    }
}
