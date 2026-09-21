import QtQuick
import Qt5Compat.GraphicalEffects
import QtQuick.Effects
import QtQuick.Controls
import QtQuick.Layouts

import "../Utils.js" as Utils

import "../components"
import "../../"
// "account_code":"0BB1-8FFV-P4BC-R1IC"
VDrawer {
    id: registrationDrawer
    width: parent.width
    height: 500
    visible: appSettings.code.length === 0
    closePolicy: Popup.NoAutoClose
    interactive: false
    onClosed: {
        registrationState = false
        hasCode = false
        sighInState = false
    }
    
    property bool sighInState: false
    property bool hasCode: false
    property bool langSelect: false

    Connections {
        target: authController

        function onAccountCode(code) {
            codeText.text = code
            registrationDrawer.hasCode = true
            errorText.text = ""
        }

        function onAuthorized() {
            registrationDrawer.hasCode = true
            if(appSettings.code.length === 0)
                appSettings.code = codeTF.text
            registrationDrawer.close()
            codeTF.clear()
            errorText.text = ""
        }

        function onErrorAuthorization() {
            console.log("onErrorAuthorization()")
            errorText.text = qsTr("Code is not valid. ")
        }
    }

    Connections {
        target: Qt.inputMethod
        function onKeyboardRectangleChanged() {
            const kbHeight = Qt.inputMethod.keyboardRectangle.height / Screen.devicePixelRatio
            console.log("Keyboard opened", kbHeight)
        }

        function onVisibleChanged() {
            if (Qt.inputMethod.visible) {
                console.log("keyboard opened, height:", Qt.inputMethod.keyboardRectangle.height)
            } else {
                console.log("keyboard closed")
            }
        }
    }
    
    contentItem: Item {


        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 18
            visible: !registrationDrawer.sighInState && !registrationDrawer.langSelect
                     && (connectionController?.isOnline || false)
            
            RowLayout {
                Layout.fillWidth: true
                Layout.preferredHeight: 34
                VText {
                    Layout.fillWidth: true
                    Layout.preferredHeight: paintedHeight
                    Layout.alignment: Qt.AlignVCenter
                    text: qsTr("Registration")
                    font.pixelSize: 22
                    weight: 800
                    color: Colors.white
                }

                MouseArea {
                    Layout.preferredHeight: 34
                    Layout.preferredWidth: Layout.preferredHeight
                    onClicked: {
                        console.log("open select language")
                        langSelect = true
                    }

                    Image {
                        anchors.centerIn: parent
                        width: 24
                        height: 24
                        source: parent.pressed ? Utils.pngIcon("lang_inactive")
                                               : Utils.pngIcon("lang_active")
                    }
                }
            }
            
            Item { Layout.preferredHeight: 15 }
            
            VText {
                Layout.fillWidth: true
                Layout.preferredHeight: paintedHeight
                text: qsTr("We don't ask for your name, email,
or any personal information.

Your account is identified only by
a unique code — generated for you,
known only to you.")
                font.pixelSize: 14
                weight: 400
                color: Colors.white
            }
            
            Item { Layout.preferredHeight: 15 }
            
            VText {
                Layout.fillWidth: true
                Layout.preferredHeight: paintedHeight
                text: qsTr("Recovery email")
                font.pixelSize: 18
                weight: 600
                color: Colors.white
                visible: !registrationDrawer.hasCode
            }
            
            VText {
                Layout.fillWidth: true
                Layout.preferredHeight: paintedHeight
                text: qsTr("Add recovery email (optional)")
                font.pixelSize: 12
                weight: 600
                color: Colors.white
                visible: !registrationDrawer.hasCode
            }
            
            VTextField {
                id: tfRecoveryEmail
                Layout.fillWidth: true
                Layout.preferredHeight: 40
                validator: RegularExpressionValidator { regularExpression: /^[^\s@]+@[^\s@]+\.[^\s@]{2,}$/ }
                placeholderText: focus || text.length > 0 ? "" : qsTr("Enter email")
                visible: !registrationDrawer.hasCode
            }
            
            Item { Layout.preferredHeight: 20 }
            
            VText {
                Layout.fillWidth: true
                Layout.preferredHeight: paintedHeight
                text: qsTr("Keep this code safe. If you lose it, your account cannot be recovered.")
                color: Colors.red
                font.pixelSize: 14
                font.capitalization: Font.AllUppercase
                visible: registrationDrawer.hasCode
                wrapMode: Text.Wrap
                weight: 800
            }
            
            MouseArea {
                Layout.fillWidth: true
                Layout.preferredHeight: 20
                opacity: pressed ? 0.7 : 1.0
                visible: registrationDrawer.hasCode
                onClicked: {
                    console.log("pressed copy")
                    vUtils.copyText(codeText.text)
                }

                RowLayout {
                    height: 20
                    width: implicitWidth
                    anchors.centerIn: parent
                    
                    VText {
                        id: codeText
                        Layout.preferredWidth: paintedWidth
                        Layout.preferredHeight: 20
                        text: ""
                        color: Colors.green
                        font.pixelSize: 20
                        weight: 800
                        font.capitalization: Font.AllUppercase
                    }
                    
                    Image {
                        Layout.preferredHeight: 20
                        Layout.preferredWidth: 20
                        source: Utils.pngIcon("copy")
                        visible: false
                    }
                }
            }
            
            Item { Layout.preferredHeight: 20 }
            
            GreenButton {
                Layout.preferredHeight: 40
                Layout.fillWidth: true
                text: registrationDrawer.hasCode ? qsTr("Copy code") : qsTr("Create account")
                property bool copied: false
                onClicked: {
                    if(registrationDrawer.hasCode) {
                        console.log("Pressed copy code")
                        if(copied) {
                            appSettings.code = codeText.text
                            registrationDrawer.close()
                        }
                        vUtils.copyText(codeText.text)
                        copied = true
                    } else {
                        console.log("Pressed create account")
                        var validEmail = isValidEmail(tfRecoveryEmail.text)
                        authController.registration(validEmail ? tfRecoveryEmail.text.trim() : "");
                        tfRecoveryEmail.text = ""
                    }
                }
            }
            
            Item { Layout.preferredHeight: 10 }
            
            RowLayout {
                Layout.fillWidth: true
                Layout.preferredHeight: 20
                Layout.alignment: Qt.AlignHCenter
                visible: !registrationDrawer.hasCode
                VText {
                    Layout.preferredWidth: paintedWidth
                    Layout.preferredHeight: paintedHeight
                    Layout.alignment: Qt.AlignHCenter
                    text: qsTr("Already have an account?")
                    color: Colors.white
                }
                
                VText {
                    Layout.preferredWidth: paintedWidth
                    Layout.preferredHeight: paintedHeight
                    text: qsTr("Login")
                    color: Colors.green
                    font.bold: true
                    weight: 800
                    opacity: children[0].pressed ? 0.7 : 1.0
                    
                    MouseArea {
                        anchors.fill: parent
                        anchors.margins: -20
                        onClicked: {
                            registrationDrawer.sighInState = !registrationDrawer.sighInState
                        }
                    }
                }
            }
            
            Item {
                Layout.fillHeight: true
            }
        }
        
        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 18
            visible: registrationDrawer.sighInState && !registrationDrawer.langSelect
                     && connectionController?.isOnline
            
            RowLayout {
                Layout.fillWidth: true
                Layout.preferredHeight: 34
                VText {
                    Layout.fillWidth: true
                    Layout.preferredHeight: paintedHeight
                    Layout.alignment: Qt.AlignVCenter
                    text: qsTr("Sigh In")
                    font.pixelSize: 22
                    weight: 800
                    color: Colors.white
                }

                MouseArea {
                    Layout.preferredHeight: 34
                    Layout.preferredWidth: Layout.preferredHeight
                    onClicked: {
                        console.log("open select language")
                        langSelect = true
                    }

                    Image {
                        anchors.centerIn: parent
                        width: 24
                        height: 24
                        source: parent.pressed ? Utils.pngIcon("lang_inactive")
                                               : Utils.pngIcon("lang_active")
                    }
                }
            }
            
            Item { Layout.preferredHeight: 15 }
            
            VTextField {
                id: codeTF
                Layout.fillWidth: true
                Layout.preferredHeight: 40
                placeholderText: activeFocus || text.length > 0 ? "" : qsTr("Enter code")
                maximumLength: 19
                property bool formatting: false

                onTextChanged: {
                    if (formatting) return
                    formatting = true

                    let cursor = cursorPosition
                    let clean = text.replace(/[^A-Za-z0-9]/g, "").toUpperCase().slice(0, 16)
                    let formatted = clean.match(/.{1,4}/g)?.join("-") ?? clean

                    let cleanBeforeCursor = text.slice(0, cursor).replace(/[^A-Za-z0-9]/g, "").length

                    text = formatted

                    let pos = 0, cleanCount = 0
                    while (pos < formatted.length && cleanCount < cleanBeforeCursor) {
                        if (/[A-Za-z0-9]/.test(formatted[pos])) cleanCount++
                        pos++
                    }
                    cursorPosition = pos

                    formatting = false
                }
            }
            
            Item { Layout.preferredHeight: 30 }

            VText {
                Layout.fillWidth: true
                Layout.preferredHeight: paintedHeight
                text: qsTr("Enter the email address associated with your account.
We'll send you your account code right away.
")
                font.pixelSize: 14
                weight: 400
                color: Colors.white
                wrapMode: Text.Wrap
            }

            VTextField {
                id: emailTF
                Layout.fillWidth: true
                Layout.preferredHeight: 40
                placeholderText: activeFocus || text.length > 0 ? "" : qsTr("Enter recovery email")
                validator: RegularExpressionValidator { regularExpression: /^[^\s@]+@[^\s@]+\.[^\s@]{2,}$/ }
            }

            MouseArea {
                Layout.preferredHeight: 30
                Layout.fillWidth: true

                VText {
                    anchors.centerIn: parent
                    color: Colors.green
                    font.pixelSize: 14
                    font.weight: 800
                    text: qsTr("Send")
                    enabled: isValidEmail(emailTF.text)
                    opacity: parent.pressed || !enabled ? 0.7 : 1.0
                }

                onClicked: {
                    console.log("Pressed send recovery letter for email", emailTF.text)
                    emailTF.text = ""
                }
            }

            Item { Layout.preferredHeight: 30

                VText {
                    id: errorText
                    anchors.fill: parent
                    color: Colors.red
                    weight: 500
                }
            }
            
            GreenButton {
                Layout.preferredHeight: 40
                Layout.fillWidth: true
                text: qsTr("Login")
                enabled: codeTF.length === 19
                onClicked: {
                    authController.auth(codeTF.text)
                    // registrationDrawer.close()
                }
            }
            
            Item { Layout.preferredHeight: 10 }
            
            RowLayout {
                Layout.fillWidth: true
                Layout.preferredHeight: 20
                Layout.alignment: Qt.AlignHCenter
                VText {
                    Layout.preferredWidth: paintedWidth
                    Layout.preferredHeight: paintedHeight
                    Layout.alignment: Qt.AlignHCenter
                    text: qsTr("Don't have an account?")
                    color: Colors.white
                }
                
                VText {
                    Layout.preferredWidth: paintedWidth
                    Layout.preferredHeight: paintedHeight
                    text: qsTr("Sign Up")
                    color: Colors.green
                    font.bold: true
                    weight: 800
                    opacity: children[0].pressed ? 0.7 : 1.0
                    
                    MouseArea {
                        anchors.fill: parent
                        anchors.margins: -20
                        onClicked: {
                            registrationDrawer.sighInState = !registrationDrawer.sighInState
                        }
                    }
                }
            }
            
            Item {
                Layout.fillHeight: true
            }
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 18
            visible: registrationDrawer.langSelect && connectionController?.isOnline

            RowLayout {
                Layout.fillWidth: true
                Layout.preferredHeight: 34

                MouseArea {
                    Layout.preferredHeight: 34
                    Layout.preferredWidth: Layout.preferredHeight
                    onClicked: {
                        console.log("close select language")
                        langSelect = false
                    }

                    Image {
                        anchors.centerIn: parent
                        width: 24
                        height: 24
                        source: parent.pressed ? Utils.pngIcon("back_active")
                                               : Utils.pngIcon("back_inactive")
                    }
                }

                VText {
                    Layout.fillWidth: true
                    Layout.preferredHeight: paintedHeight
                    Layout.alignment: Qt.AlignVCenter
                    text: qsTr("Select language")
                    font.pixelSize: 22
                    weight: 800
                    color: Colors.white
                }
            }

            Item { Layout.preferredHeight: 15 }

            ListModel {
                id: mL

                ListElement { lang: "en"; text: qsTr("English") }
                ListElement { lang: "de"; text: qsTr("Deutsch") }
                ListElement { lang: "uk"; text: qsTr("Українська") }
                ListElement { lang: "pl"; text: qsTr("Polski") }
                ListElement { lang: "fr"; text: qsTr("Français") }
                ListElement { lang: "es"; text: qsTr("Español") }
                ListElement { lang: "it"; text: qsTr("Italiano") }
            }

            ListView {
                id: langLV
                Layout.fillWidth: true
                Layout.preferredHeight: contentHeight
                interactive: false
                clip: true
                model: mL
                spacing: 4
                currentIndex: -1
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

                            opacity: langLV.currentIndex === index ? 1 : 0
                            scale: langLV.currentIndex === index ? 1 : 0.8

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
                            langLV.currentIndex = index
                            translationManager.setLanguage(model.lang)
                        }
                    }
                }
            }

            Item { Layout.fillHeight: true }
        }

        ColumnLayout {
            anchors.fill: parent
            visible: !connectionController?.isOnline || false

            Item {
                Layout.fillHeight: true
            }

            AnimatedImage {
                Layout.alignment: Qt.AlignHCenter
                Layout.preferredHeight: 120
                Layout.preferredWidth: 120
                antialiasing: true
                smooth: true
                source: Utils.pngIcon("offline")
            }

            VText {
                Layout.alignment: Qt.AlignHCenter
                Layout.preferredHeight: 20
                Layout.preferredWidth: paintedWidth
                text: qsTr("You are offline")
                color: Colors.white
                font.pixelSize: 14
                weight: 700
            }

            Item {
                Layout.fillHeight: true
            }
        }
    }

    function isValidEmail(email) {
        const regex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/
        return regex.test(email.trim())
    }
}
