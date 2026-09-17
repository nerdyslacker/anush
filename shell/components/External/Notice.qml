pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import "../.."

// Temporary status and persistent reminder notices from external integrations.
Scope {
    id: root

    property string outputName: ""
    property string message: ""
    property bool persistent: false

    function matchesScreen(screen) {
        if (!screen) return false
        if (outputName !== "") return screen.name === outputName
        return Quickshell.screens.length > 0 && screen === Quickshell.screens[0]
    }

    function close() {
        message = ""
        persistent = false
        closeTimer.stop()
    }

    Connections {
        target: Wm
        function onUiEvent(event) {
            if (String(event.change ?? "") !== "ui-notice") return
            const incoming = String(event.text ?? "")
            const incomingPersistent = event.persistent === true
            if (root.persistent && !incomingPersistent) return
            root.outputName = String(event.output ?? "")
            root.message = root.persistent && incomingPersistent && root.message !== ""
                ? root.message + "; " + incoming : incoming
            root.persistent = incomingPersistent
            if (incomingPersistent) closeTimer.stop()
            else closeTimer.restart()
        }
    }

    Timer { id: closeTimer; interval: 2500; onTriggered: root.close() }

    Variants {
        model: Quickshell.screens
        PanelWindow {
            id: window
            required property var modelData
            screen: modelData
            anchors.top: true
            anchors.left: true
            margins.top: Theme.surfaceGap + 6
            margins.left: Math.max(8, Math.round((modelData.width - implicitWidth) / 2))
            implicitWidth: Math.min(modelData.width - 16, Math.max(260, label.implicitWidth + 68))
            implicitHeight: 48
            exclusiveZone: 0
            exclusionMode: ExclusionMode.Ignore
            aboveWindows: true
            color: "transparent"
            visible: root.message !== "" && root.matchesScreen(modelData)

            Rectangle {
                anchors.fill: parent
                radius: Theme.radiusLarge
                color: Theme.bg
                border.width: 1
                border.color: root.persistent ? Theme.brightOrange : Qt.alpha(Theme.accent, 0.65)
                Row {
                    anchors.fill: parent
                    anchors.leftMargin: 14; anchors.rightMargin: 12
                    spacing: 10
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: root.persistent ? "󰀦" : "󰋼"
                        color: root.persistent ? Theme.brightOrange : Theme.accent
                        font.family: Theme.iconFontFamily; font.pixelSize: Theme.iconSize
                    }
                    Text {
                        id: label
                        anchors.verticalCenter: parent.verticalCenter
                        text: root.message
                        color: Theme.fg
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSize
                    }
                }
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.close()
                }
            }
        }
    }
}
