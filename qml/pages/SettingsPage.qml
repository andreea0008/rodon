import QtQuick
import QtQuick.Layouts
import QtQuick.Controls.Material
import "../"
import "../components"
import "../Utils.js" as Utils


Item {

    Component.onCompleted: {
        // console.log("OS:", DeviceInfo.os, DeviceInfo.osVersion)
        // console.log("iOS:", DeviceInfo.isIos)
        // console.log("Device ID:", DeviceInfo.deviceId)
        // console.log("App version:", DeviceInfo.appVersion)
        // if(DeviceInfo.isIos) {
        //     var iosModel = vUtils.model()
        //     console.log("iosModel:::", iosModel)
        // } else {
        //     console.log("Model:", DeviceInfo.model)
        // }
    }

    // onVisibleChanged: {
    //     if(!visible) {
    //         codeBox.hide = false
    //     }
    // }

    ScrollView {
        anchors.fill: parent
        anchors.leftMargin: 18
        anchors.rightMargin: 18
        anchors.topMargin: safeTop
        anchors.bottomMargin: 115
        contentWidth: availableWidth
        clip: true

        ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
        ScrollBar.vertical.policy: ScrollBar.AlwaysOff

        ColumnLayout {
            width: parent.width
            spacing: 4

            VText {
                Layout.fillWidth: true
                Layout.preferredHeight: paintedHeight
                text: qsTr("General")
                font.pixelSize: 20
                weight: 800
                color: Colors.white
            }

            GlassBox {
                Layout.fillWidth: true
                Layout.preferredHeight: clPlan.implicitHeight + 20

                ColumnLayout {
                    id: clPlan
                    anchors.fill: parent
                    anchors.margins: 10

                    VText {
                        Layout.fillWidth: true
                        Layout.preferredHeight: paintedHeight
                        text: qsTr("Plan")
                        font.pixelSize: 16
                        weight: 600
                        color: Colors.white
                    }

                    Item { Layout.preferredHeight: 20 }

                    GreenButton {
                        Layout.preferredHeight: 40
                        Layout.fillWidth: true
                        text: qsTr("Purchase")
                        visible: !ios
                    }

                    Item { Layout.preferredHeight: 20; visible: !ios }

                    VText {
                        Layout.fillWidth: true
                        Layout.preferredHeight: paintedHeight
                        text: qsTr("Code")
                        font.pixelSize: 16
                        weight: 600
                        color: Colors.white
                    }

                    GlassBox {
                        id: codeBox
                        Layout.fillWidth: true
                        height: 40
                        radius: 8
                        boxOpacity: 0.3

                        property bool hide: true

                        Timer {
                            id: hideTimer
                            interval: 5000
                            running: !codeBox.hide
                            repeat: false
                            onTriggered: {
                                if (copyAnim.running) {
                                    hideTimer.restart()
                                    return
                                }
                                returnToHideAnim.start()
                            }
                        }

                        VText {
                            id: codeText
                            anchors.centerIn: parent
                            text: "Press here to see code "
                            color: codeBox.hide ? Colors.white : Colors.green
                            font.bold: true
                            weight: 601
                            font.pixelSize: codeBox.hide ? 14 : 20

                            Behavior on font.pixelSize { NumberAnimation { duration: 400; easing.type: Easing.OutCubic } }
                            Behavior on color { ColorAnimation { duration: 400 } }

                            SequentialAnimation {
                                id: revealAnim
                                NumberAnimation {
                                    target: codeText; property: "opacity"
                                    to: 0; duration: 200; easing.type: Easing.InCubic
                                }
                                ScriptAction {
                                    script: {
                                        codeBox.hide = false
                                        codeText.text = appSettings.code
                                    }
                                }
                                NumberAnimation {
                                    target: codeText; property: "opacity"
                                    to: 1; duration: 300; easing.type: Easing.OutCubic
                                }
                                ScriptAction { script: hideTimer.restart() }
                            }

                            SequentialAnimation {
                                id: copyAnim
                                NumberAnimation {
                                    target: codeText; property: "opacity"
                                    to: 0; duration: 150; easing.type: Easing.InCubic
                                }
                                ScriptAction { script: codeText.text = qsTr("Copied") }
                                NumberAnimation {
                                    target: codeText; property: "opacity"
                                    to: 1; duration: 150; easing.type: Easing.OutCubic
                                }
                                PauseAnimation { duration: 900 }
                                NumberAnimation {
                                    target: codeText; property: "opacity"
                                    to: 0; duration: 150; easing.type: Easing.InCubic
                                }
                                ScriptAction { script: codeText.text = appSettings.code }
                                NumberAnimation {
                                    target: codeText; property: "opacity"
                                    to: 1; duration: 150; easing.type: Easing.OutCubic
                                }
                                ScriptAction { script: hideTimer.restart() }
                            }

                            SequentialAnimation {
                                id: returnToHideAnim
                                NumberAnimation {
                                    target: codeText; property: "opacity"
                                    to: 0; duration: 200; easing.type: Easing.InCubic
                                }
                                ScriptAction {
                                    script: {
                                        codeBox.hide = true
                                        codeText.text = "Press here to see code "
                                    }
                                }
                                NumberAnimation {
                                    target: codeText; property: "opacity"
                                    to: 1; duration: 300; easing.type: Easing.OutCubic
                                }
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            onClicked: {
                                if (codeBox.hide) {
                                    revealAnim.start()
                                } else {
                                    if (copyAnim.running)
                                        return
                                    vUtils.copyText(appSettings.code)
                                    vUtils.vibrate()
                                    copyAnim.start()
                                    hideTimer.restart()
                                }
                            }
                        }
                    }

                    Item { Layout.preferredHeight: 20}

                    VText {
                        Layout.fillWidth: true
                        Layout.preferredHeight: paintedHeight
                        text: qsTr("Devices")
                        font.pixelSize: 16
                        weight: 600
                        color: Colors.white
                    }

                    ListView {
                        Layout.fillWidth: true
                        Layout.preferredHeight: contentHeight
                        interactive: false
                        clip: true
                        model: deviceController || []
                        spacing: 4
                        delegate: GlassBox {
                            width: ListView.view.width
                            height: clDeviceInfo.implicitHeight + 20
                            radius: 8
                            boxOpacity: 0.3
                            opacity: maDeviceDelegate.pressed ? 0.7 : 1.0

                            RowLayout {
                                anchors.fill: parent
                                anchors.margins: 10

                                ColumnLayout {
                                    id: clDeviceInfo
                                    Layout.fillWidth: true
                                    Layout.alignment: Qt.AlignVCenter
                                    VText {
                                        Layout.fillWidth: true
                                        Layout.preferredHeight: paintedHeight
                                        Layout.alignment: Qt.AlignVCenter
                                        text: name
                                        color: Colors.white
                                        font.pixelSize: 14
                                        weight: 500
                                    }

                                    VText {
                                        Layout.fillWidth: true
                                        Layout.preferredHeight: paintedHeight
                                        Layout.alignment: Qt.AlignVCenter
                                        text: qsTr("OS:%1").arg(platform)
                                        color: Colors.white
                                        font.pixelSize: 14
                                        weight: 500
                                    }

                                    VText {
                                        Layout.fillWidth: true
                                        Layout.preferredHeight: paintedHeight
                                        Layout.alignment: Qt.AlignVCenter
                                        text: qsTr("\nDevice ID:\n%1").arg(deviceId)
                                        color: Colors.white
                                        font.pixelSize: 14
                                        weight: 500
                                        elide: Text.ElideRight
                                    }

                                }

                                MouseArea {
                                    id: maDeviceDelegate
                                    Layout.preferredHeight: 20
                                    Layout.preferredWidth: 20
                                    Layout.alignment: Qt.AlignVCenter
                                    onClicked: {
                                        console.log("remove device", (DeviceInfo.deviceId === deviceId), DeviceInfo.deviceId, deviceId)
                                        if(DeviceInfo.deviceId === deviceId) {
                                            console.log("Current device. Make question about it and if user agree sigh out")
                                            deviceController.removeDevice(deviceId);
                                        }
                                    }

                                    Image{
                                        anchors.fill: parent
                                        antialiasing: true
                                        smooth: true
                                        source: Utils.pngIcon("trash")
                                    }
                                }
                            }
                        }
                    }

                    Item { Layout.preferredHeight: 20}

                    VText {
                        Layout.fillWidth: true
                        Layout.preferredHeight: paintedHeight
                        text: qsTr("Language")
                        font.pixelSize: 16
                        weight: 600
                        color: Colors.white
                    }

                    ListModel {
                        id: mL

                        ListElement { lang: "en"; text: qsTr("English") }
                        ListElement { lang: "de"; text: qsTr("Deutsch") }
                        ListElement { lang: "ua"; text: qsTr("Українська") }
                        ListElement { lang: "pl"; text: qsTr("Polski") }
                        ListElement { lang: "fr"; text: qsTr("Français") }
                        ListElement { lang: "es"; text: qsTr("Español") }
                        ListElement { lang: "it"; text: qsTr("Italiano") }
                    }

                    ListView {
                        id: languageLV
                        Layout.fillWidth: true
                        Layout.preferredHeight: contentHeight
                        interactive: false
                        clip: true
                        model: mL
                        spacing: 4
                        Component.onCompleted: {
                            currentIndex = findIndexByLang(translationManager.currentLanguage)
                        }

                        function findIndexByLang(langCode) {
                            for (var i = 0; i < mL.count; i++) {
                                if (mL.get(i).lang === langCode) {
                                    return i
                                }
                            }
                            return -1
                        }

                        delegate: GlassBox {
                            width: ListView.view.width
                            height: 40
                            radius: 8
                            boxOpacity: 0.3
                            opacity: maLanguageDelegate.pressed ? 0.7 : 1.0

                            RowLayout {
                                anchors.fill: parent
                                anchors.margins: 10

                                Image{
                                    Layout.preferredWidth: 20
                                    Layout.preferredHeight: 20
                                    Layout.alignment: Qt.AlignVCenter
                                    antialiasing: true
                                    smooth: true
                                    source: Utils.flagCountryByCode(model.lang)
                                    sourceSize.width: 40
                                    sourceSize.height: 40
                                    fillMode: Image.PreserveAspectFit
                                    mipmap: true
                                }

                                VText {
                                    Layout.fillWidth: true
                                    Layout.alignment: Qt.AlignVCenter
                                    text: model.text
                                    color: Colors.white
                                    font.pixelSize: 14
                                    weight: 500
                                }

                                Image{
                                    id: checkIcon
                                    Layout.preferredWidth: 20
                                    Layout.preferredHeight: 20
                                    sourceSize.height: 40
                                    sourceSize.width: 40
                                    Layout.alignment: Qt.AlignVCenter
                                    antialiasing: true
                                    smooth: true
                                    source: Utils.pngIcon("check")

                                    scale: languageLV.currentIndex === index ? 1 : 0.8
                                    opacity: languageLV.currentIndex === index ? 1 : 0

                                    Behavior on opacity {
                                        NumberAnimation { duration: 250; easing.type: Easing.OutCubic }
                                    }
                                    Behavior on scale {
                                        NumberAnimation { duration: 250; easing.type: Easing.OutBack }
                                    }
                                }
                            }

                            MouseArea {
                                id: maLanguageDelegate
                                anchors.fill: parent
                                onClicked: {
                                    console.log("selected language - " + model.text)
                                    translationManager.setLanguage(model.lang)
                                    languageLV.currentIndex = index
                                }
                            }
                        }
                    }

                    Item { Layout.preferredHeight: 20}

                    VText {
                        Layout.fillWidth: true
                        Layout.preferredHeight: paintedHeight
                        text: qsTr("Sign Out")
                        font.pixelSize: 16
                        weight: 600
                        color: Colors.white
                    }

                    GreenButton {
                        Layout.preferredHeight: 40
                        Layout.fillWidth: true
                        color: Colors.red
                        text: qsTr("Sign Out")
                        onClicked: {
                            deviceController.removeDevice(DeviceInfo.deviceId);
                        }
                    }
                }
            }

            Item {Layout.preferredHeight: 20}

            VText {
                Layout.fillWidth: true
                Layout.preferredHeight: paintedHeight
                text: qsTr("VPN")
                font.pixelSize: 20
                weight: 800
                color: Colors.white
            }

            GlassBox {
                Layout.fillWidth: true
                Layout.preferredHeight: vpnCl.implicitHeight + 20

                ColumnLayout {
                    id: vpnCl
                    anchors.fill: parent
                    ToogleSwitch{
                        Layout.fillWidth: true
                        text: qsTr("Auto-select location")
                        description: qsTr("Automatically connect to the fastest available server when no location is selected")
                        onToogleChanged: {
                            console.log("Auto-select location changed ", toogle);
                            appSettings.auto_select_location = toogle
                            vUtils.vibrate()
                        }
                    }

                    ToogleSwitch{
                        Layout.fillWidth: true
                        visible: false
                        text: qsTr("Kill Switch")
                        description: qsTr("Block all internet traffic if the VPN connection drops unexpectedly")
                        onToogleChanged: { console.log("Kill Switch changed ", toogle); vUtils.vibrate() }
                    }

                    ToogleSwitch{
                        Layout.fillWidth: true
                        text: qsTr("Auto-connect")
                        description: qsTr("Automatically establish a VPN connection when the app launches")
                        toogle: appSettings.auto_connection
                        onToogleChanged: {
                            console.log("Auto-connect changed ", toogle);
                            vUtils.vibrate()
                            appSettings.auto_connection = toogle
                        }
                    }
                }
            }

            Item {Layout.preferredHeight: 20}

            VText {
                Layout.fillWidth: true
                Layout.preferredHeight: paintedHeight
                text: qsTr("About")
                font.pixelSize: 20
                weight: 800
                color: Colors.white
            }

            GlassBox {
                Layout.fillWidth: true
                Layout.preferredHeight: aboutCl.implicitHeight + 20

                ColumnLayout {
                    id: aboutCl
                    anchors.fill: parent
                    anchors.margins: 10


                    RowLayout {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 20
                        VText {
                            Layout.fillWidth: true
                            Layout.preferredHeight: paintedHeight
                            Layout.alignment: Qt.AlignVCenter
                            text: qsTr("Version")
                            font.pixelSize: 14
                            weight: 400
                            color: Colors.white
                        }

                        VText {
                            Layout.preferredWidth: paintedWidth
                            Layout.preferredHeight: paintedHeight
                            Layout.alignment: Qt.AlignVCenter
                            text: DeviceInfo.appVersion
                            font.pixelSize: 14
                            weight: 400
                            color: Colors.white
                        }
                    }
                }
            }
        }
    }

    component ToogleSwitch: Item{
        id: tSwitch
        height: clTSwitch.implicitHeight + 20
        Layout.preferredHeight: height
        required property string text
        property string description
        property bool check
        property alias toogle: tSwitchToogle.checked

        RowLayout {
            anchors.fill: parent
            anchors.margins: 10

            ColumnLayout {
                id: clTSwitch
                Layout.fillWidth: true
                Layout.preferredHeight: 20

                VText {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 20
                    Layout.alignment: Qt.AlignVCenter
                    color: Colors.white
                    weight: 600
                    text: tSwitch.text
                    font.pixelSize: 14
                    verticalAlignment: Text.AlignVCenter
                }

                VText {
                    Layout.fillWidth: true
                    Layout.preferredHeight: paintedHeight
                    Layout.alignment: Qt.AlignVCenter
                    color: Colors.white
                    weight: 400
                    text: tSwitch.description
                    font.pixelSize: 12
                    verticalAlignment: Text.AlignVCenter
                    visible: tSwitch.description.length > 0
                    wrapMode: Text.Wrap
                }
            }

            VSwitch {
                id: tSwitchToogle
                Layout.preferredWidth: 38
                Layout.preferredHeight: 20
                Layout.alignment: Qt.AlignVCenter
                checked: tSwitch.check
            }
        }
    }

    Connections {
        target: deviceController

        function onDeviceRemoved(deviceId) {
            if(DeviceInfo.deviceId === deviceId)
                sighOut()
        }
    }

    function sighOut() {
        root.selected = PageTypes.Home
        appSettings.code = ""
        registrationState = true
        registrationDrawer.hasCode = false
        registrationDrawer.sighInState = false
    }
}
