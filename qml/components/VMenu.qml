import QtQuick
import Qt5Compat.GraphicalEffects
import QtQuick.Effects
import QtQuick.Controls
import QtQuick.Layouts
import "../"

GlassBox {
    id: menu
    radius: height/2
    width: 320
    height: 60
    
    Item {
        id: slideBox
        anchors.verticalCenter: parent.verticalCenter
        width: parent.width/3
        height: parent.height
        
        Behavior on x {
            ParallelAnimation {
                NumberAnimation {
                    duration: 300
                    easing.type: Easing.OutQuad
                }
                ScriptAction {
                    script: bounceAnim.start()
                }
            }
        }
        
        SequentialAnimation {
            id: bounceAnim
            NumberAnimation {
                target: slideBox
                property: "scale"
                to: 0.8
                duration: 180
                easing.type: Easing.OutQuad
            }
            NumberAnimation {
                target: slideBox
                property: "scale"
                to: 1.0
                duration: 120
                easing.type: Easing.OutBack
            }
        }
        
        Rectangle {
            anchors.fill: parent
            anchors.margins: 2
            color: "#2E1529"
            radius: height/2
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0.0; color: "#4A2240" }
                GradientStop { position: 1.0; color: "#241016" }
            }
        }
    }
    
    MouseArea {
        width: parent.width /3
        height: parent.height
        opacity: pressed ? 0.7 : 1.0
        
        onClicked: {
            if(isMobile)
                vUtils.vibrate();
            root.selected = PageTypes.Home
            slideBox.x = x
        }
        
        ColumnLayout {
            anchors.centerIn: parent
            spacing: 4
            Image {
                id: homeIcon
                Layout.alignment: Qt.AlignHCenter
                Layout.preferredHeight: 24
                Layout.preferredWidth: 24
                antialiasing: true
                smooth: true
                sourceSize.width: 48
                sourceSize.height: 48
                fillMode: Image.PreserveAspectFit
                mipmap: true
                source: Utils.pngIcon(root.selected === PageTypes.Home ? "home_active"
                                                             : "home_inactive")
                
                SequentialAnimation {
                    id: bounceHomeAnim
                    NumberAnimation {
                        target: homeIcon
                        property: "scale"
                        to: 0.8
                        duration: 180
                        easing.type: Easing.OutQuad
                    }
                    NumberAnimation {
                        target: homeIcon
                        property: "scale"
                        to: 1.0
                        duration: 120
                        easing.type: Easing.OutBack
                    }
                }
                
                Connections {
                    target: root
                    function onSelectedChanged() {
                        if(root.selected === PageTypes.Home)
                            bounceHomeAnim.restart()
                    }
                }
            }
            
            VText {
                Layout.alignment: Qt.AlignHCenter
                text: qsTr("Home")
                color: root.selected === 1 ? Colors.white : Colors.dim
                font.pixelSize: 14
                useShadow: root.selected === PageTypes.Home
            }
        }
    }
    
    MouseArea {
        x: width
        width: parent.width /3
        height: parent.height
        opacity: pressed ? 0.7 : 1.0
        
        onClicked: {
            if(isMobile)
                vUtils.vibrate();
            slideBox.x = x
            root.selected = PageTypes.Locations
        }
        
        ColumnLayout {
            anchors.centerIn: parent
            spacing: 4
            Image {
                id: locationIcon
                Layout.alignment: Qt.AlignHCenter
                Layout.preferredHeight: 24
                Layout.preferredWidth: 24
                antialiasing: true
                smooth: true
                sourceSize.width: 48
                sourceSize.height: 48
                fillMode: Image.PreserveAspectFit
                mipmap: true
                source: Utils.pngIcon(root.selected === PageTypes.Locations ? "location_active"
                                                             : "location_inactive")
                SequentialAnimation {
                    id: bounceLocationAnim
                    NumberAnimation {
                        target: locationIcon
                        property: "scale"
                        to: 0.8
                        duration: 180
                        easing.type: Easing.OutQuad
                    }
                    NumberAnimation {
                        target: locationIcon
                        property: "scale"
                        to: 1.0
                        duration: 120
                        easing.type: Easing.OutBack
                    }
                }
                
                Connections {
                    target: root
                    function onSelectedChanged() {
                        if(root.selected === PageTypes.Locations)
                            bounceLocationAnim.restart()
                    }
                }
            }
            
            VText {
                Layout.alignment: Qt.AlignHCenter
                text: qsTr("Locations")
                color: root.selected === PageTypes.Locations ? Colors.white : Colors.dim
                font.pixelSize: 14
                useShadow: root.selected === PageTypes.Locations
            }
        }
    }
    
    MouseArea {
        x: width *2
        width: parent.width /3
        height: parent.height
        opacity: pressed ? 0.7 : 1.0
        onClicked: {
            if(isMobile)
                vUtils.vibrate();
            slideBox.x = x
            root.selected = PageTypes.Settings
        }
        
        ColumnLayout {
            anchors.centerIn: parent
            spacing: 4
            Image {
                id: settingsIcon
                Layout.alignment: Qt.AlignHCenter
                Layout.preferredHeight: 24
                Layout.preferredWidth: 24
                antialiasing: true
                smooth: true
                sourceSize.width: 48
                sourceSize.height: 48
                fillMode: Image.PreserveAspectFit
                mipmap: true
                source: Utils.pngIcon(root.selected === PageTypes.Settings ? "settings_active"
                                                             : "settings_inactive")
                
                SequentialAnimation {
                    id: bounceSettingsAnim
                    NumberAnimation {
                        target: settingsIcon
                        property: "scale"
                        to: 0.8
                        duration: 180
                        easing.type: Easing.OutQuad
                    }
                    NumberAnimation {
                        target: settingsIcon
                        property: "scale"
                        to: 1.0
                        duration: 120
                        easing.type: Easing.OutBack
                    }
                }
                
                Connections {
                    target: root
                    function onSelectedChanged() {
                        if(root.selected === 3)
                            bounceSettingsAnim.restart()
                    }
                }
            }
            
            VText {
                Layout.alignment: Qt.AlignHCenter
                text: qsTr("Settings")
                color: root.selected === PageTypes.Settings ? Colors.white : Colors.dim
                font.pixelSize: 14
                useShadow: root.selected === PageTypes.Settings
            }
        }
    }
}
