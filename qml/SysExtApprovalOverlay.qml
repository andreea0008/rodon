import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import RodON 1.0
import "./components"

Rectangle {
    id: root
    anchors.fill: parent
    color: "#CC000000"
    z: 1000

    readonly property int st: SysExt.state
    visible: st === SysExt.NeedsApproval
             || st === SysExt.RebootRequired
             || st === SysExt.NotInApplications
             || st === SysExt.Failed

    MouseArea { anchors.fill: parent; hoverEnabled: true }

    GlassBox {
        anchors.centerIn: parent
        width: Math.min(parent.width - 48, 420)
        height: content.implicitHeight + 48

        ColumnLayout {
            id: content
            anchors.fill: parent
            anchors.margins: 24
            spacing: 14

            VText {
                Layout.fillWidth: true
                wrapMode: Text.WordWrap
                font.pixelSize: 20
                font.bold: true
                color: Colors.white
                text: root.st === SysExt.Failed
                      ? qsTr("Could not enable RodON VPN")
                      : root.st === SysExt.RebootRequired
                        ? qsTr("Restart required")
                        : root.st === SysExt.NotInApplications
                          ? qsTr("Move RodON to Applications")
                          : qsTr("Allow RodON VPN")
            }

            VText {
                Layout.fillWidth: true
                wrapMode: Text.WordWrap
                color: Colors.white
                visible: root.st === SysExt.NeedsApproval
                textFormat: Text.StyledText
                text: qsTr("macOS asks you to allow the VPN component once.<br><br>"
                           + "1. Click <b>Open Settings</b><br>"
                           + "2. Next to <b>RodON</b> click <b>ⓘ</b><br>"
                           + "3. Turn the switch on and confirm with your password")
            }

            VText {
                Layout.fillWidth: true
                wrapMode: Text.WordWrap
                color: Colors.white
                visible: root.st === SysExt.RebootRequired
                text: qsTr("macOS will finish installing the VPN component after a restart.")
            }

            VText {
                Layout.fillWidth: true
                wrapMode: Text.WordWrap
                color: Colors.white
                visible: root.st === SysExt.NotInApplications
                text: qsTr("macOS can only enable the VPN component when RodON "
                         + "runs from the Applications folder.")
            }

            VText {
                Layout.fillWidth: true
                wrapMode: Text.WordWrap
                color: Colors.red
                visible: root.st === SysExt.Failed
                text: SysExt.errorString
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 10
                visible: root.st === SysExt.NeedsApproval
                Item {
                    Layout.preferredWidth: 20;
                    Layout.preferredHeight: 20
                    Canvas {
                        id: spinner
                        anchors.fill: parent
                        onPaint: {
                            const ctx = getContext("2d");
                            ctx.reset();
                            ctx.lineWidth = 2.5;
                            ctx.lineCap = "round";
                            ctx.strokeStyle = Colors.white;
                            ctx.beginPath();
                            ctx.arc(width / 2, height / 2, width / 2 - 2, 0, Math.PI * 1.5);
                            ctx.stroke();
                        }
                    }
                    RotationAnimator on rotation {
                        from: 0; to: 360; duration: 900
                        loops: Animation.Infinite
                        running: root.visible
                    }
                }
                VText { color: Colors.white; text: qsTr("Waiting for approval…") }
            }

            GreenButton {
                Layout.fillWidth: true
                Layout.preferredHeight: 32
                visible: root.st === SysExt.NeedsApproval
                text: qsTr("Open Settings")
                onClicked: SysExt.openSettings()
            }

            GreenButton {
                Layout.fillWidth: true
                Layout.preferredHeight: 32
                color: Colors.dim
                visible: root.st === SysExt.Failed
                text: qsTr("Try again")
                onClicked: SysExt.activate()
            }
        }
    }
}
