pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import "../.."

// Labels every enabled physical display for a few seconds after the user
// chooses Identify in Display settings.
Scope {
    id: root

    function outputForScreen(screen) {
        const name = Wm.outputNameForScreen(screen)
        return DisplayConfigurationService.currentOutputs.find(output =>
            output.enabled && String(output.name) === name) ?? null
    }

    function numberForScreen(screen) {
        const output = outputForScreen(screen)
        if (!output) return 0
        const enabled = DisplayConfigurationService.currentOutputs.filter(item => item.enabled)
        return enabled.findIndex(item => String(item.name) === String(output.name)) + 1
    }

    Variants {
        model: DisplayConfigurationService.identifying ? Quickshell.screens : []

        PanelWindow {
            id: identifierWindow
            required property var modelData
            readonly property var output: root.outputForScreen(modelData)
            readonly property int displayNumber: root.numberForScreen(modelData)

            screen: modelData
            anchors.top: true
            anchors.left: true
            margins.top: Math.max(16, Math.round((modelData.height - implicitHeight) / 2))
            margins.left: Math.max(16, Math.round((modelData.width - implicitWidth) / 2))
            implicitWidth: Math.min(modelData.width - 32, 260)
            implicitHeight: 126
            exclusiveZone: 0
            exclusionMode: ExclusionMode.Ignore
            aboveWindows: true
            color: "transparent"
            visible: output !== null

            Rectangle {
                anchors.fill: parent
                radius: Theme.radiusLarge
                color: Qt.alpha(Theme.bg, 0.96)
                border.width: 2
                border.color: Theme.accent

                Column {
                    anchors.centerIn: parent
                    width: parent.width - 24
                    spacing: 3

                    Text {
                        width: parent.width
                        horizontalAlignment: Text.AlignHCenter
                        text: identifierWindow.displayNumber
                        color: Theme.accent
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSize + 34
                        font.bold: true
                    }
                    Text {
                        width: parent.width
                        horizontalAlignment: Text.AlignHCenter
                        text: identifierWindow.output ? identifierWindow.output.name : ""
                        color: Theme.fg
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSize + 2
                        font.bold: true
                    }
                    Text {
                        width: parent.width
                        horizontalAlignment: Text.AlignHCenter
                        text: identifierWindow.output
                            ? identifierWindow.output.width + " × " + identifierWindow.output.height
                            : ""
                        color: Theme.brightBlack
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSize - 1
                    }
                }
            }
        }
    }
}
