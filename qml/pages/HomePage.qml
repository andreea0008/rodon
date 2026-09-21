import QtQuick
import QtQuick.Effects
import Qt5Compat.GraphicalEffects
import QtQuick.Layouts
import Qt.labs.lottieqt 1.0

import "../Utils.js" as Utils

import "../"
import "../components"

Item {
        id: homePage

        readonly property int durationAnimation: homePage.status === ConnectionStatus.NotConnected ? 0 : 1500
        property double shadowOpacity: homePage.status === ConnectionStatus.Connected ? 1 : 0
        property bool startAnimationTimer: false
        property point center: Qt.point(width/2, height/2)
        property int wh: 6
        property bool _stopAnim: false

        property color color: {
                switch (status) {
                case ConnectionStatus.NotConnected: return Colors.red
                case ConnectionStatus.Connecting:   return Colors.yellow
                case ConnectionStatus.Connected:    return Colors.green
                default:                            return Colors.red
                }
        }

        property bool connected: status === ConnectionStatus.Connected
        property int status: ConnectionStatus.NotConnected
        property int baseAnimationType: Easing.InOutQuad
        property string timeLeft: timerLeft.secToHMS()
        property bool isFreeVersion: true

        Timer {
                id: timerLeft
                running: status === ConnectionStatus.Connected
                interval: 1000
                repeat: true
                property int leftSec: 0
                onTriggered: leftSec++

                function secToHMS() {
                        var h = Math.floor(leftSec / 3600)
                        var m = Math.floor((leftSec % 3600) / 60)
                        var s = Math.floor(leftSec % 60)

                        return String(h).padStart(2, '0') + ":"
                                        + String(m).padStart(2, '0') + ":"
                                        + String(s).padStart(2, '0')
                }
        }

        Timer {
                id: autoConnectionTimer
                running: appSettings.auto_connection
                repeat: false
                interval: 500
                onTriggered: {
                        var p = locationController.possibleConnectToLocationByCode(appSettings.last_selected_code_country)
                        if(appSettings.last_selected_code_country !== ""
                                        && locationController.possibleConnectToLocationByCode(appSettings.last_selected_code_country)) {
                                var index = locationController.indexLocationByCode(appSettings.last_selected_code_country)
                                if(index !== -1 && status === ConnectionStatus.NotConnected) {
                                        locationController.setCurrentLocationByIndex(index)
                                        connectionController.connectToLocation(
                                                                locationController.currentLocationId,
                                                                DeviceInfo.deviceId)

                                }
                        }
                        autoConnectionTimer.running = false
                }
        }

        Connections {
                target: connectionController || null
                function onStatusChanged() {
                        homePage.status = connectionController.status
                }
        }

        MouseArea {
                id: mainMouse
                anchors.centerIn: parent
                anchors.verticalCenterOffset: -(parent.height * 0.1)
                width: parent.width * 0.7
                height: width
                enabled: (connectionController?.isOnline
                          && homePage.status !== ConnectionStatus.Connecting
                          && homePage.status !== ConnectionStatus.Disconnecting) || false
                opacity: connectionController?.isOnline ? 1.0 : 0.7
                onClicked: {
                        if(locationController.currentLocationCode === "" && !appSettings.auto_select_location) {
                                selected = PageTypes.Locations
                                startConnect = true
                                return;
                        }

                        if(locationController.currentLocationCode === "" && appSettings.auto_select_location) {
                                locationController.randomLocation();
                        }

                        if(isMobile)
                                vUtils.vibrate();

                        box1Anim.start()
                        box1ScaleAnim.start()
                        box2Anim.start()
                        box2ScaleAnim.start()
                        box3Anim.start()
                        box3ScaleAnim.start()

                        if(status === ConnectionStatus.NotConnected) {
                                timerLeft.leftSec = 0
                                connectionController.connectToLocation(
                                                        locationController.currentLocationId,
                                                        DeviceInfo.deviceId)
                        }

                        if(status === ConnectionStatus.Connected) {
                                connectionController.disconnect(DeviceInfo.deviceId)
                        }
                }

                Rectangle {
                        id: box1
                        width: parent.width
                        height: width
                        radius: width/2
                        opacity: 0.15
                        rotation: -40
                        gradient: Gradient {
                                GradientStop { position: 0.0; color: homePage.color }
                                GradientStop { position: 0.45; color: "transparent" }
                                GradientStop { position: 0.55; color: "transparent" }
                                GradientStop { position: 1.0; color: homePage.color }
                        }

                        SequentialAnimation {
                                id: box1Anim
                                NumberAnimation {
                                        target: box1
                                        property: "opacity"
                                        to: 0
                                        duration: 250
                                        easing.type: baseAnimationType
                                }

                                NumberAnimation {
                                        target: box1
                                        property: "opacity"
                                        to: 0.5
                                        duration: 400
                                        easing.type: Easing.OutQuad
                                }
                        }

                        SequentialAnimation {
                                id: box1ScaleAnim
                                NumberAnimation {
                                        target: box1
                                        property: "scale"
                                        to: 0.9
                                        duration: 250
                                        easing.type: baseAnimationType
                                }

                                NumberAnimation {
                                        target: box1
                                        property: "scale"
                                        to: 1.0
                                        duration: 400
                                        easing.type: baseAnimationType
                                }
                        }

                        Rectangle {
                                width: parent.width
                                height: width
                                radius: parent.radius
                                color: "transparent"
                                border.width: 1
                                border.color: parent.color
                                opacity: 0.3
                                visible: !box1Anim.running
                        }
                }

                Rectangle {
                        id: box2
                        anchors.centerIn: parent
                        width: parent.width * 0.85
                        height: width
                        radius: width/2
                        opacity: 0.2
                        rotation: -40
                        gradient: Gradient {
                                GradientStop { position: 0.0; color: homePage.color }
                                GradientStop { position: 0.45; color: "transparent" }
                                GradientStop { position: 0.55; color: "transparent" }
                                GradientStop { position: 1.0; color: homePage.color }
                        }
                        SequentialAnimation {
                                id: box2Anim
                                NumberAnimation {
                                        target: box2
                                        property: "opacity"
                                        to: 0.0
                                        duration: 250
                                        easing.type: baseAnimationType
                                }

                                NumberAnimation {
                                        target: box2
                                        property: "opacity"
                                        to: 0.2
                                        duration: 400
                                        easing.type: Easing.OutQuad
                                }
                        }

                        SequentialAnimation {
                                id: box2ScaleAnim
                                NumberAnimation {
                                        target: box2
                                        property: "scale"
                                        to: 0.9
                                        duration: 250
                                        easing.type: baseAnimationType
                                }

                                NumberAnimation {
                                        target: box2
                                        property: "scale"
                                        to: 1.0
                                        duration: 400
                                        easing.type: baseAnimationType
                                }
                        }

                        Rectangle {
                                anchors.fill: parent
                                radius: parent.radius
                                color: "transparent"
                                border.width: 1
                                border.color: parent.color
                                opacity: 0.4
                                visible: !box1Anim.running
                        }
                }

                Rectangle {
                        id: box3
                        anchors.centerIn: parent
                        width: parent.width * 0.7
                        height: width
                        radius: width/2
                        opacity: 0.5
                        color: homePage.color

                        Rectangle {
                                anchors.fill: parent
                                radius: parent.radius
                                color: "transparent"
                                border.width: 1
                                border.color: parent.color
                                opacity: 0.5
                                visible: !box1Anim.running
                        }

                        SequentialAnimation {
                                id: box3Anim
                                NumberAnimation {
                                        target: box3
                                        property: "opacity"
                                        to: 0.3
                                        duration: 200
                                        easing.type: baseAnimationType
                                }

                                NumberAnimation {
                                        target: box3
                                        property: "opacity"
                                        to: 0.5
                                        duration: 450
                                        easing.type: Easing.OutQuad
                                }
                        }

                        SequentialAnimation {
                                id: box3ScaleAnim
                                NumberAnimation {
                                        target: box3
                                        property: "scale"
                                        to: 1.0
                                        duration: 150
                                        easing.type: baseAnimationType
                                }

                                NumberAnimation {
                                        target: box3
                                        property: "scale"
                                        to: 1.0
                                        duration: 500
                                        easing.type: baseAnimationType
                                }
                        }
                }

                DropShadow {
                        anchors.fill: box3
                        horizontalOffset: 1
                        verticalOffset: 1
                        radius: 8.0
                        color: "#80ffffff"
                        source: box3
                        visible: connected
                }
        }

        Rectangle {
                anchors.centerIn: parent
                width: box3.width
                height: width
                color: box3.color
                radius: height/2
                anchors.margins: 5
                anchors.verticalCenterOffset: -(parent.height * 0.1)
                enabled: connectionController?.isOnline || false
                opacity: enabled? 1.0 : 0.7
                scale: mainMouse.pressed ? 0.9 : 1.0

                Behavior on scale {
                    NumberAnimation {
                        duration: 260
                        easing.type: Easing.OutBack
                        easing.overshoot: 3.0
                    }
                }

                ColumnLayout {
                        width: implicitWidth
                        height: implicitHeight
                        anchors.centerIn: parent

                        Item {
                                Layout.preferredHeight: homePage.status === ConnectionStatus.Connecting || homePage.status === ConnectionStatus.Disconnecting ? 110 : 80
                                Layout.preferredWidth: homePage.status === ConnectionStatus.Connecting || homePage.status === ConnectionStatus.Disconnecting ? 110 : 80

                                LottieAnimation {
                                        id: lottie
                                        anchors.centerIn: parent
                                        width: homePage.status === ConnectionStatus.Connecting || homePage.status === ConnectionStatus.Disconnecting ? 110 : 80
                                        height: homePage.status === ConnectionStatus.Connecting || homePage.status === ConnectionStatus.Disconnecting ? 110 : 80
                                        loops: homePage.status === ConnectionStatus.Connecting
                                               || homePage.status === ConnectionStatus.Disconnecting
                                               ? LottieAnimation.Infinite : 1
                                        quality: LottieAnimation.HighQuality
                                        source: sourceByState()
                                        autoPlay: false
                                        visible: false


                                        function sourceByState() {
                                                switch(homePage.status){
                                                case ConnectionStatus.Offline: return "qrc:/qt/qml/SVPN/lottie/Loader_In.json";
                                                case ConnectionStatus.Error: return "qrc:/qt/qml/SVPN/lottie/Loader_In.json";
                                                case ConnectionStatus.NotConnected: return "qrc:/qt/qml/SVPN/lottie/Loader_In.json";
                                                case ConnectionStatus.Connecting: return "qrc:/qt/qml/SVPN/lottie/Loader_Loop.json";
                                                case ConnectionStatus.Disconnecting: return "qrc:/qt/qml/SVPN/lottie/Loader_Loop.json";
                                                case ConnectionStatus.Connected: return "qrc:/qt/qml/SVPN/lottie/Loader_Out.json";
                                                }
                                        }

                                        Connections {
                                                target: homePage

                                                function onStatusChanged() {
                                                        if(homePage.status === ConnectionStatus.Connecting
                                                                        || homePage.status === ConnectionStatus.Connected
                                                                        || homePage.status === ConnectionStatus.Disconnecting) {
                                                                lottie.visible = true
                                                                lottie.loops = (status === ConnectionStatus.Connecting || status === ConnectionStatus.Disconnecting)
                                                                                ? LottieAnimation.Infinite : 1
                                                                lottie.source = lottie.sourceByState()
                                                                if(homePage.status === ConnectionStatus.Connected) {
                                                                        imgPower.source = ""
                                                                }
                                                        } else {
                                                                lottie.source = lottie.sourceByState()
                                                                lottie.loops = 1
                                                                imgPower.nextStageIsDisconnect = false
                                                        }
                                                }
                                        }

                                        onStatusChanged: {
                                                if (status === LottieAnimation.Ready) {
                                                        gotoAndPlay(startFrame);
                                                }
                                        }

                                        onFinished: {
                                                if(homePage.status === ConnectionStatus.NotConnected) {
                                                        imgPower.source = "qrc:/qt/qml/SVPN/lottie/power_off.svg"
                                                        lottie.visible = false
                                                }

                                                if(homePage.status === ConnectionStatus.Connecting) {
                                                        lottie.visible = true
                                                        lottie.loops = state === ConnectionStatus.Connecting ? LottieAnimation.Infinite : 1
                                                        lottie.source = lottie.sourceByState()
                                                }

                                                if(homePage.status === ConnectionStatus.Connected) {
                                                        if(!imgPower.nextStageIsDisconnect) {
                                                                imgPower.source = "qrc:/qt/qml/SVPN/lottie/power_on.svg"
                                                        }
                                                        else {
                                                                imgPower.source = "qrc:/qt/qml/SVPN/lottie/power_off.svg"
                                                        }

                                                        lottie.visible = false
                                                }
                                        }
                                }

                                Image {
                                        id: imgPower
                                        width: homePage.status === ConnectionStatus.Connecting ? 110 : 90
                                        height: width
                                        anchors.centerIn: parent
                                        visible: !lottie.visible
                                        property bool nextStageIsDisconnect
                                }
                        }

                        Item {
                                Layout.fillWidth: true
                                Layout.preferredHeight: 22
                                visible: homePage.status !== ConnectionStatus.Connecting
                                VText {
                                        id: buttonStatusText
                                        anchors.fill: parent
                                        horizontalAlignment: Text.AlignHCenter
                                        verticalAlignment: Text.AlignVCenter
                                        color: Colors.white
                                        weight: 800
                                        font.pixelSize: 18
                                        property int dots: 1
                                        text: {
                                                switch(homePage.status) {
                                                case ConnectionStatus.NotConnected: return qsTr("Not connected")
                                                case ConnectionStatus.Connecting: {
                                                        switch(buttonStatusText.dots) {
                                                        case 1:  return qsTr("Connecting.  ")
                                                        case 2:  return qsTr("Connecting.. ")
                                                        case 3:  return qsTr("Connecting...")
                                                        default: return qsTr("Connecting.  ")
                                                        }
                                                }

                                                case ConnectionStatus.Offline: return qsTr("You are offline")
                                                case ConnectionStatus.Connected: return qsTr("Connected")
                                                case ConnectionStatus.Disconnecting: {
                                                        switch(buttonStatusText.dots) {
                                                        case 1:  return qsTr("Disconnecting.  ")
                                                        case 2:  return qsTr("Disconnecting.. ")
                                                        case 3:  return qsTr("Disconnecting...")
                                                        default: return qsTr("Disconnecting.  ")
                                                        }
                                                }
                                                }
                                        }

                                        Timer {
                                                interval: 1200
                                                repeat: true
                                                running: homePage.status === ConnectionStatus.Connecting ||
                                                         homePage.status === ConnectionStatus.Disconnecting
                                                onTriggered: {
                                                        buttonStatusText.dots++
                                                        if(buttonStatusText.dots === 4) {
                                                                buttonStatusText.dots = 1
                                                        }
                                                }
                                        }
                                }
                        }

                        Item {
                                id: timeLeftItem
                                Layout.alignment: Qt.AlignHCenter
                                Layout.preferredHeight: 13
                                Layout.preferredWidth: 60
                                visible: homePage.status !== ConnectionStatus.Connecting

                                property var hms: timeLeft.split(':')
                                RowLayout {
                                        Layout.alignment: Qt.AlignHCenter
                                        visible: homePage.status === ConnectionStatus.Connected
                                        spacing: 2
                                        VText {
                                                text: timeLeftItem.hms[0]
                                                color: Colors.white
                                                font.pixelSize: 13
                                                weight: 500
                                                horizontalAlignment: Text.AlignRight
                                        }

                                        VText {
                                                color: Colors.white
                                                font.pixelSize: 13
                                                weight: 500
                                                horizontalAlignment: Text.AlignRight
                                                text: ":"
                                        }

                                        VText {
                                                text: timeLeftItem.hms[1]
                                                color: Colors.white
                                                font.pixelSize: 13
                                                weight: 500
                                                horizontalAlignment: Text.AlignRight
                                        }

                                        VText {
                                                color: Colors.white
                                                font.pixelSize: 13
                                                weight: 500
                                                horizontalAlignment: Text.AlignRight
                                                text: ":"
                                        }

                                        VText {
                                                text: timeLeftItem.hms[2]
                                                color: Colors.white
                                                font.pixelSize: 13
                                                weight: 500
                                                horizontalAlignment: Text.AlignRight
                                        }
                                }
                        }
                }
        }

        Item {
                id: sphere
                width: parent.width * 0.7
                height: width
                anchors.centerIn: parent
                anchors.verticalCenterOffset: -(parent.height * 0.1)
                rotation: 180
                visible: homePage.status === ConnectionStatus.Connecting

                readonly property bool connecting: homePage.status === ConnectionStatus.Connecting
                || connected

                Item {
                        id: sphere1Container
                        x: sphere.width / 2 - radius - wh / 2
                        y: sphere.height / 2 - radius - wh / 2
                        width: (radius * 2) + wh
                        height: (radius * 2) + wh
                        property int radius: parent.height / 2

                        ArcTrail {
                                anchors.fill: parent
                                radius: sphere.height/2
                                trailColor: "157, 20, 255" // #9D14FF
                                rotationDuration: 3000
                                active: sphere.connecting
                                arcLengthDeg: sphere.connecting ? 100 : 0
                        }
                }

                Item {
                        id: sphere2Container
                        x: (sphere.width / 2) - sphere2Container.radius - wh / 2
                        y: (sphere.height / 2) - sphere2Container.radius - wh / 2
                        rotation: 180
                        width: (radius * 2) + wh
                        height: (radius * 2) + wh
                        property int radius: parent.height / 2

                        ArcTrail {
                                anchors.fill: parent
                                radius: sphere.height/2
                                trailColor: "200, 88, 198" // #C858C6
                                rotationDuration: 3000
                                active: sphere.connecting
                                arcLengthDeg: sphere.connecting ? 100 : 0
                        }
                }
        }

        GlassBox {
                id: infoConnectionBox
                width: parent.width - 28
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.top: sphere.bottom
                anchors.topMargin: 20
                clip: true

                height: connected && connectionController?.currentCode !== "" ? 60 : 0
                opacity: connected && connectionController?.currentCode !== "" ? 1.0 : 0.0


                Behavior on height {
                        NumberAnimation { duration: 500; easing.type: Easing.InOutQuad }
                }

                Behavior on opacity {
                        NumberAnimation { duration: 500; easing.type: Easing.InOutQuad }
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
                                source: Utils.flagCountryByCode(connectionController?.currentCode) || ""
                                sourceSize.width: 80
                                sourceSize.height: 80
                                smooth: true
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
                                        text: (`${connectionController?.currentCountry} [${connectionController?.currentCity}]`) || ""
                                        color: Colors.white
                                        weight: 800
                                        font.pixelSize: 16
                                }

                                RowLayout {
                                        Layout.fillWidth: true
                                        Layout.preferredHeight: 20

                                        ListView {
                                                id: signalIndicator
                                                Layout.preferredWidth: contentWidth
                                                Layout.preferredHeight: 20
                                                model: 3
                                                interactive: false
                                                orientation: ListView.Horizontal
                                                spacing: 2
                                                delegate: Item {
                                                        width: 4
                                                        height: 20
                                                        Rectangle {
                                                                anchors.bottom: parent.bottom
                                                                width: 4
                                                                radius: 2
                                                                height: {
                                                                        switch (index) {
                                                                        case 0: return 8
                                                                        case 1: return 12
                                                                        case 2: return 16
                                                                        }
                                                                }
                                                                color: signalIndicator.model === 3 ? "#24CC67" :
                                                                                                     signalIndicator.model === 2 ? Colors.yellow : Colors.red
                                                        }
                                                }
                                        }

                                        VText {
                                                Layout.alignment: Qt.AlignBottom
                                                Layout.preferredHeight: 20
                                                text: `Ping ${connectionController?.currentPing}` || "" //ping
                                                color: Colors.white
                                                font.pixelSize: 14
                                                verticalAlignment: Text.AlignBottom
                                        }

                                        VText {
                                                Layout.alignment: Qt.AlignVCenter
                                                Layout.preferredHeight: 20
                                                verticalAlignment: Text.AlignBottom
                                                text: `IP: ${connectionController?.currentIp}` || "" // ip
                                                color: Colors.white
                                                font.pixelSize: 14
                                                elide: Text.ElideRight
                                        }
                                }
                        }

                        Item {
                                Layout.preferredHeight: 40
                                Layout.preferredWidth: 40
                                Layout.alignment: Qt.AlignVCenter

                                Repeater {
                                        model: [30, 24, 18]
                                        Rectangle {
                                                anchors.centerIn: parent
                                                width: modelData; height: width
                                                color: Colors.yellow
                                                radius: height / 2
                                                opacity: 0.2
                                        }
                                }
                        }
                }
        }

        GlassBox {
                width: parent.width - 28
                height: cl.implicitHeight + 20
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.top: sphere.bottom
                anchors.topMargin: 100
                visible: isFreeVersion
                opacity: upgradeMa.pressed ? 0.7 : 1.0

                ColumnLayout {
                        id: cl
                        anchors.fill: parent
                        anchors.leftMargin: 14
                        anchors.topMargin: 10
                        anchors.bottomMargin: 10
                        anchors.rightMargin: 14

                        RowLayout {
                                Layout.fillWidth: true
                                Layout.preferredHeight: 20

                                Image {
                                        Layout.preferredHeight: 20
                                        Layout.preferredWidth: 20
                                        smooth: true
                                        antialiasing: true
                                        source: "qrc:/qt/qml/SVPN/icons/crown.png"
                                }

                                VText {
                                        Layout.fillWidth: true
                                        Layout.preferredHeight: paintedHeight
                                        Layout.alignment: Qt.AlignVCenter
                                        text: rodon?.isFreeVersion ? qsTr("Free version") : qsTr("Pro version")
                                        color: Colors.white
                                        font.pixelSize: 14
                                        weight: 500
                                        verticalAlignment: Text.AlignVCenter
                                }
                        }

                        Rectangle {
                                Layout.fillWidth: true
                                Layout.preferredHeight: 12
                                color: Colors.dim
                                radius: height/2

                                Rectangle {
                                        height: parent.height
                                        width: (parent.width /100) * rodon?.progress
                                        color: Colors.purple
                                        radius: height/2
                                }
                        }

                        VText {
                                Layout.fillWidth: true
                                Layout.preferredHeight: paintedHeight
                                Layout.alignment: Qt.AlignVCenter
                                text: rodon?.isFreeVersion ? qsTr("Press here if you want to upgrade to full version")
                                                           : qsTr("Full version active until %1").arg(expiryDate)

                                color: Colors.white
                                font.pixelSize: 12
                                weight: 400
                                verticalAlignment: Text.AlignVCenter
                                visible: !ios
                        }
                }

                MouseArea {
                        id: upgradeMa
                        anchors.fill: parent
                        visible: !ios
                        onClicked: {
                                console.log("Clicked to `upgrade` version")
                                selected = PageTypes.Settings
                        }
                }
        }

        component ArcTrail:  Item{
                id: arcTrailComponent

                property real radius: 141
                property real arcLengthDeg: 0
                property string trailColor: "157, 20, 255"
                property int rotationDuration: 3000
                property bool active: false

                Behavior on arcLengthDeg {
                        NumberAnimation { duration: 1500 }
                }

                onArcLengthDegChanged: canvas.requestPaint()

                Canvas {
                        id: canvas
                        anchors.fill: parent
                        onPaint: {
                                const ctx = getContext("2d")
                                ctx.clearRect(0, 0, width, height)

                                const centerX = width / 2
                                const centerY = height / 2

                                const arcAngle = arcTrailComponent.arcLengthDeg * Math.PI / 180
                                const endAngle = -Math.PI / 2 + (360 * Math.PI / 180)
                                const startAngle = endAngle - arcAngle

                                const steps = 50
                                const angleStep = (endAngle - startAngle) / steps

                                for (let i = 0; i < steps; ++i) {
                                        let alpha
                                        if (i < steps * 0.8) {
                                                alpha = 0.04 + (i / (steps * 0.8)) * (0.6 - 0.04)
                                        } else {
                                                const fastIndex = i - steps * 0.8
                                                const fastSteps = steps * 0.2
                                                alpha = 0.6 + (fastIndex / fastSteps) * (1.0 - 0.6)
                                        }
                                        alpha = Math.min(Math.max(alpha, 0.04), 1.0)

                                        ctx.strokeStyle = `rgba(${arcTrailComponent.trailColor}, ${alpha})`
                                        ctx.lineWidth = 6
                                        ctx.lineCap = "round"
                                        ctx.beginPath()
                                        ctx.arc(centerX, centerY, arcTrailComponent.radius,
                                                startAngle + i * angleStep,
                                                startAngle + (i + 1) * angleStep)
                                        ctx.stroke()
                                }
                        }
                }

                RotationAnimation on rotation {
                        id: rotationAnim
                        running: arcTrailComponent.active
                        from: 0
                        to: 360
                        duration: arcTrailComponent.rotationDuration
                        easing.type: Easing.OutCubic
                        onStopped: if (arcTrailComponent.active) start()
                }
        }
}
