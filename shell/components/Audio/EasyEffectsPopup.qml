pragma ComponentBehavior: Bound

import QtQuick
import "../.."

Popout {
    id: root

    cardWidth: 390
    cardHeight: 470

    onVisibleChanged: {
        EasyEffectsService.popupVisible = visible
        if (visible) {
            PopupCoordinator.requestOpen("easyEffects", root)
            EasyEffectsService.refresh()
        }
    }

    Connections {
        target: PopupCoordinator
        function onOpening(name, owner) {
            if (owner !== root) root.visible = false
        }
    }

    component ActionButton: Rectangle {
        id: button
        required property string label
        property bool primary: false
        signal activated()

        implicitWidth: labelText.implicitWidth + 20
        height: 30
        radius: Theme.radiusSmall
        color: primary ? Theme.activeBackground
            : buttonMouse.containsMouse ? Theme.gray3 : Theme.gray2
        border.width: 1
        border.color: primary ? Theme.activeBorder : Theme.gray5
        opacity: enabled ? 1 : 0.45

        Text {
            id: labelText
            anchors.centerIn: parent
            text: button.label
            color: button.primary ? Theme.selfg : Theme.fg
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSize - 1
            font.bold: button.primary
        }
        MouseArea {
            id: buttonMouse
            anchors.fill: parent
            enabled: button.enabled
            hoverEnabled: true
            onClicked: button.activated()
        }
    }

    component ToggleSwitch: Rectangle {
        id: control
        required property bool checked
        signal toggled()

        width: 38
        height: 20
        radius: Math.min(height / 2, Theme.radiusSmall)
        color: checked ? Theme.activeBackground : Qt.alpha(Theme.fg, 0.16)
        opacity: enabled ? 1 : 0.45

        Rectangle {
            x: control.checked ? parent.width - width - 3 : 3
            anchors.verticalCenter: parent.verticalCenter
            width: 14
            height: 14
            radius: Math.min(width / 2, Theme.radiusSmall)
            color: control.checked ? Theme.selfg : Qt.alpha(Theme.fg, 0.7)
            Behavior on x { NumberAnimation { duration: 140 } }
        }
        MouseArea {
            anchors.fill: parent
            enabled: control.enabled
            onClicked: control.toggled()
        }
    }

    component PresetButton: Rectangle {
        id: preset
        required property string presetName
        required property bool selected
        signal activated()

        height: 34
        radius: Theme.radiusSmall
        color: selected ? Theme.activeBackground
            : presetMouse.containsMouse ? Theme.gray3 : Theme.gray2
        border.width: selected ? 2 : 1
        border.color: selected ? Theme.activeBorder : Theme.gray5
        enabled: EasyEffectsService.serviceReady && !EasyEffectsService.busy
        opacity: enabled ? 1 : 0.55

        Row {
            anchors.centerIn: parent
            width: parent.width - 14
            spacing: 6
            Text {
                visible: preset.selected
                anchors.verticalCenter: parent.verticalCenter
                text: "󰓎"
                color: Theme.selfg
                font.family: Theme.iconFontFamily
                font.pixelSize: Theme.iconSizeSmall
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width - (preset.selected ? 20 : 0)
                text: preset.presetName
                color: preset.selected ? Theme.selfg : Theme.fg
                elide: Text.ElideRight
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSize - 1
                font.bold: preset.selected
            }
        }
        MouseArea {
            id: presetMouse
            anchors.fill: parent
            enabled: preset.enabled
            hoverEnabled: true
            onClicked: preset.activated()
        }
    }

    Flickable {
        anchors.fill: parent
        contentWidth: width
        contentHeight: content.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        Column {
            id: content
            width: parent.width
            spacing: 10

            Row {
                width: parent.width
                height: 32
                spacing: 7

                Text {
                    width: parent.width - openButton.width - refreshButton.width
                        - parent.spacing * 2
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Easy Effects"
                    color: Theme.fg
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSize + 2
                    font.bold: true
                }
                ActionButton {
                    id: refreshButton
                    label: "Refresh"
                    enabled: EasyEffectsService.available
                        && !EasyEffectsService.busy
                    onActivated: EasyEffectsService.refresh()
                }
                ActionButton {
                    id: openButton
                    label: "Open app"
                    primary: true
                    enabled: EasyEffectsService.available
                    onActivated: EasyEffectsService.openApp()
                }
            }

            Rectangle {
                visible: EasyEffectsService.available
                width: parent.width
                height: 48
                radius: Theme.radiusMedium
                color: Theme.gray2
                border.width: 1
                border.color: Theme.gray5

                Column {
                    anchors.left: parent.left
                    anchors.leftMargin: 10
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 1
                    Text {
                        text: "Audio effects"
                        color: Theme.fg
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSize
                        font.bold: true
                    }
                    Text {
                        text: !EasyEffectsService.serviceReady
                            ? "Service is not running"
                            : EasyEffectsService.bypassed
                            ? "Bypassed" : "Processing enabled"
                        color: !EasyEffectsService.serviceReady
                            ? Theme.foregroundMuted
                            : EasyEffectsService.bypassed ? Theme.warning
                            : Theme.success
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSize - 2
                    }
                }
                ToggleSwitch {
                    anchors.right: parent.right
                    anchors.rightMargin: 10
                    anchors.verticalCenter: parent.verticalCenter
                    checked: EasyEffectsService.serviceReady
                        && !EasyEffectsService.bypassed
                    enabled: EasyEffectsService.serviceReady
                        && !EasyEffectsService.busy
                    onToggled: EasyEffectsService.toggleBypass()
                }
            }

            Text {
                visible: EasyEffectsService.checking
                    || (!EasyEffectsService.available
                        && EasyEffectsService.error === "")
                width: parent.width
                topPadding: 32
                horizontalAlignment: Text.AlignHCenter
                text: EasyEffectsService.checking
                    ? "Checking for Easy Effects…"
                    : "Easy Effects is not installed."
                color: Theme.foregroundMuted
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSize
            }

            Text {
                visible: EasyEffectsService.available
                    && EasyEffectsService.outputPresets.length > 0
                text: "OUTPUT PRESETS"
                color: Theme.accent
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSize - 2
                font.bold: true
            }

            Grid {
                id: outputGrid
                visible: EasyEffectsService.available
                    && EasyEffectsService.outputPresets.length > 0
                width: parent.width
                columns: 2
                spacing: 6
                Repeater {
                    model: EasyEffectsService.outputPresets
                    PresetButton {
                        required property string modelData
                        width: (outputGrid.width - outputGrid.spacing) / 2
                        presetName: modelData
                        selected: EasyEffectsService.activeOutputPreset === modelData
                        onActivated: EasyEffectsService.loadOutputPreset(modelData)
                    }
                }
            }

            Text {
                visible: EasyEffectsService.available
                    && EasyEffectsService.inputPresets.length > 0
                text: "INPUT PRESETS"
                color: Theme.accent
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSize - 2
                font.bold: true
            }

            Grid {
                id: inputGrid
                visible: EasyEffectsService.available
                    && EasyEffectsService.inputPresets.length > 0
                width: parent.width
                columns: 2
                spacing: 6
                Repeater {
                    model: EasyEffectsService.inputPresets
                    PresetButton {
                        required property string modelData
                        width: (inputGrid.width - inputGrid.spacing) / 2
                        presetName: modelData
                        selected: EasyEffectsService.activeInputPreset === modelData
                        onActivated: EasyEffectsService.loadInputPreset(modelData)
                    }
                }
            }

            Text {
                visible: EasyEffectsService.available
                    && EasyEffectsService.outputPresets.length === 0
                    && EasyEffectsService.inputPresets.length === 0
                width: parent.width
                topPadding: 18
                horizontalAlignment: Text.AlignHCenter
                text: "No Easy Effects presets found."
                color: Theme.foregroundMuted
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSize
            }

            Text {
                visible: EasyEffectsService.error !== ""
                width: parent.width
                text: EasyEffectsService.error
                color: Theme.error
                wrapMode: Text.Wrap
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSize - 1
            }
        }
    }
}
