import QtQuick
import QtQuick.Controls.Material
import QtQuick.Layouts
import "../"
import "../components"
import "../Utils.js" as Utils

Item {
    ColumnLayout {
        anchors.fill: parent
        anchors.leftMargin: 18
        anchors.rightMargin: 18
        anchors.topMargin: safeTop
        anchors.bottomMargin: 115

        VTextField {
            id: tf
            Layout.fillWidth: true
            Layout.preferredHeight: 40
            validator: RegularExpressionValidator {
                regularExpression: /^[A-Za-z]+$/
            }
            inputMethodHints: Qt.ImhNoPredictiveText
        }

        VListView {
            id: locationLV
            Layout.fillHeight: true
            Layout.fillWidth: true
            model: locationController
            spacing: 10
            currentIndex: -1

            Connections {
                target: locationController || null
                function onLocationIndexChanged(i) {
                    locationLV.currentIndex = i
                    locationController.setCurrentLocationByIndex(i)
                }
            }

            delegate: GlassBox{
                id: locationDelegate
                width: ListView.view.width
                height: hasMatch() ? 60 : 0
                boxOpacity: 0.2
                opacity: maDelegate.pressed ? 0.7 : 1.0
                visible: hasMatch()
                clip: true

                Behavior on height {
                    NumberAnimation { duration: 500; easing.type: Easing.InOutQuad }
                }

                Behavior on opacity {
                    NumberAnimation { duration: 500; easing.type: Easing.InOutQuad }
                }

                function hasMatch() {
                    if (tf.text.length === 0)
                        return true
                    var country = countryName.toLowerCase()
                    var txtLower = tf.text.toLowerCase()
                    return country.includes(txtLower)
                }

                MouseArea {
                    id: maDelegate
                    anchors.fill: parent
                    onClicked: {
                        tf.focus = false
                        Qt.inputMethod.hide()
                        locationLV.currentIndex = index
                        locationController.setCurrentLocationByIndex(index)
                        appSettings.last_selected_code_country = countryCode
                        if(startConnect) {
                            startConnect = false
                            connectionController.connectToLocation(
                                                    locationController.currentLocationId,
                                                    DeviceInfo.deviceId)
                            selected = PageTypes.Home
                        }
                    }
                }

                RowLayout {
                    id: rl
                    anchors.fill: parent
                    anchors.leftMargin: 14
                    anchors.topMargin: 10
                    anchors.bottomMargin: 10
                    anchors.rightMargin: 14

                    Image {
                        Layout.preferredHeight: 40
                        Layout.preferredWidth: 40
                        source: Utils.flagCountryByCode(countryCode)
                        antialiasing: true
                        smooth: true
                        sourceSize.width: 80
                        sourceSize.height: 80
                        fillMode: Image.PreserveAspectFit
                        mipmap: true
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        Layout.alignment: Qt.AlignVCenter
                        spacing: 0

                        VText {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 20
                            verticalAlignment: Text.AlignVCenter
                            text: countryName
                            color: Colors.white
                            weight: 800
                            font.pixelSize: 16
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 20
                            spacing: 20

                            ListView {
                                id: signalIndicator
                                Layout.preferredWidth: contentWidth
                                Layout.preferredHeight: 20
                                model: 3
                                interactive: false
                                orientation: ListView.Horizontal
                                spacing: 2

                                readonly property int litBars: loadFactor < 0.4 ? 3
                                                                                : loadFactor < 0.75 ? 2
                                                                                                    : 1

                                delegate: Item {
                                    width: 4
                                    height: 20

                                    readonly property int barHeight: {
                                        switch (index) {
                                        case 0: return 8
                                        case 1: return 12
                                        case 2: return 16
                                        }
                                    }

                                    Rectangle {
                                        anchors.bottom: parent.bottom
                                        width: 4
                                        radius: 2
                                        height: parent.barHeight
                                        color: "#bbc4c4"
                                    }

                                    Rectangle {
                                        anchors.bottom: parent.bottom
                                        width: 4
                                        radius: 2
                                        height: parent.barHeight
                                        visible: index < signalIndicator.litBars
                                        color: loadFactor < 0.4  ? "#24CC67"
                                                                 : loadFactor < 0.75 ? Colors.yellow
                                                                                     : Colors.red
                                    }
                                }
                            }

                            VText {
                                Layout.alignment: Qt.AlignVCenter
                                text: "120ms"
                                color: Colors.white
                                font.pixelSize: 14
                            }
                        }
                    }

                    Image{
                        Layout.preferredWidth: 20
                        Layout.preferredHeight: 20
                        sourceSize.height: 40
                        sourceSize.width: 40
                        Layout.alignment: Qt.AlignVCenter
                        antialiasing: true
                        smooth: true
                        source: Utils.pngIcon("check")

                        opacity: locationLV.currentIndex === index ? 1 : 0
                        scale: locationLV.currentIndex === index ? 1 : 0.8

                        Behavior on opacity {
                            NumberAnimation { duration: 250; easing.type: Easing.OutCubic }
                        }
                        Behavior on scale {
                            NumberAnimation { duration: 250; easing.type: Easing.OutBack }
                        }
                    }
                }
            }
        }
    }

    Rectangle {
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 110
        height: 40
        width: parent.width
        gradient: Gradient {
            GradientStop { position: 0.0; color: "#00000000" }
            GradientStop { position: 1.0; color: "#4d000000" }
        }
    }
}
