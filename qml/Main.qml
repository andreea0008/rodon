import QtQuick
import Qt5Compat.GraphicalEffects
import QtQuick.Effects
import QtQuick.Controls
import QtQuick.Layouts
import QtCore

import "components"
import "pages"

import "Utils.js" as Utils

Window {
    id: root
    width: 400
    height: 800
    visible: true
    title: qsTr("Rodon Vpn Application")
    color: "#0d0d0d"
    flags: ios ? Qt.Window | Qt.MaximizeUsingFullscreenGeometryHint | Qt.ExpandedClientAreaHint : Qt.Window

    property bool ios: Qt.platform.os === "ios"
    property bool android: Qt.platform.os === "android"
    property bool isMobile: ios || android
    property bool idDesktop: !android && !ios
    property int selected: PageTypes.Home
    readonly property real safeTop: ios || android ?  SafeArea.margins.top : 18
    property bool registrationState: appSettings.code.length === 0
    property var deviceController: rodon?.deviceController || null
    property var locationController: rodon?.locationController || null
    property var connectionController: rodon?.connectionController || null
    property bool startConnect: false

    onRegistrationStateChanged: {
        if(registrationState)
            registrationDrawer.open()
    }
    //UMCX-0KV8-6LKA-9WLZ
    Component.onCompleted: {
        console.log("appSettings.code.length: ", appSettings.code.length)
        if(appSettings.code.length !== 0) {
            authController.auth(appSettings.code)
        } else {
            connectionController.checkInternet()
            tOpenRegistrationDrawer.start()
        }
    }

    Timer {
        id: tOpenRegistrationDrawer
        interval: 400
        repeat: false
        running: false
        onTriggered: {
            registrationDrawer.open()
        }
    }

    VUtils {
        id: vUtils
    }

    VPage { id: vpg }

    StackLayout {
        id: pages
        anchors.fill: parent
        visible: !registrationState
        currentIndex: selected -1

        HomePage { }
        LocationsPage { }
        SettingsPage { }
    }

    VMenu {
        id: menu
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 50
        anchors.horizontalCenter: parent.horizontalCenter
        visible: !registrationState
    }

    FastBlur {
        anchors.fill: parent
        source: vpg
        radius: 24
        visible: registrationDrawer.visible
    }

    RegistrationDrawer {
        id: registrationDrawer
    }

    Settings {
        id: appSettings
        property string code: ""
        property bool auto_select_location: false
        property bool auto_connection: false
        property string last_selected_code_country

        Component.onCompleted: {
            console.log("loaded code", code)
        }
    }

    Connections {
        target: translationManager

        function onLanguageChanged() {
            console.log("Language changed to:", translationManager.currentLanguage)
        }
    }

    Connections {
        target: authController

        function onAuthorized() {
            console.log("authorized")
            console.log("OS:", DeviceInfo.os, DeviceInfo.osVersion)
            console.log("iOS:", DeviceInfo.isIos)
            console.log("Device ID:", DeviceInfo.deviceId)
            console.log("App version:", DeviceInfo.appVersion)
            var iosModel = ""
            if(DeviceInfo.isIos) {
                iosModel = vUtils.model()
                console.log("iosModel:::", iosModel)
            } else {
                console.log("Model:", DeviceInfo.model)
            }

            const device = {
                device_id: DeviceInfo.deviceId,
                platform: qsTr("%1 %2").arg(DeviceInfo.os).arg(DeviceInfo.osVersion),
                name: iosModel.length > 0 ? iosModel : DeviceInfo.model
            };

            const jsonString = JSON.stringify(device);
            console.log(jsonString);

            registrationDrawer.hasCode = true
            authController.registerDevice(jsonString)
        }

        function onErrorAuthorization() {
            registrationDrawer.hasCode = false
            registrationDrawer.open()
        }
    }

    Connections {
        target: connectionController || null

        function onIsOnlineChanged() {
            if(registrationDrawer.visible && connectionController?.isOnline) {
                authController.auth(appSettings.code)
            }
        }
    }
}
