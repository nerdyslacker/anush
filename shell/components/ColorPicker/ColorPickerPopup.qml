pragma ComponentBehavior: Bound

import QtQuick
import "../.."

Popout {
    id: root

    cardWidth: 340
    cardHeight: 430

    function toggleAtAnchor() {
        if (visible)
            visible = false
        else
            showAtAnchor()
    }

    onVisibleChanged: {
        if (visible)
            PopupCoordinator.requestOpen("colorPicker", root)
    }

    Connections {
        target: PopupCoordinator
        function onOpening(name, owner) {
            if (owner !== root)
                root.visible = false
        }
    }

    component ActionButton: Rectangle {
        id: button
        required property string buttonText
        property bool primary: false
        signal activated()

        implicitWidth: label.implicitWidth + 28
        height: 34
        radius: Theme.radiusSmall
        color: primary ? Theme.accent
            : pointer.containsMouse ? Theme.hover : Theme.surfaceVariant
        border.width: primary ? 0 : 1
        border.color: Theme.outline

        Behavior on color { ColorAnimation { duration: 120 } }

        Text {
            id: label
            anchors.centerIn: parent
            text: button.buttonText
            color: button.primary ? Theme.accentForeground : Theme.foreground
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSize
            font.bold: true
        }

        MouseArea {
            id: pointer
            anchors.fill: parent
            enabled: button.enabled
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: button.activated()
        }
    }

    Column {
        anchors.fill: parent
        spacing: 12

        Row {
            width: parent.width
            height: 24

            Text {
                width: parent.width - status.implicitWidth
                anchors.verticalCenter: parent.verticalCenter
                text: "Color picker"
                color: Theme.foreground
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSize + 2
                font.bold: true
            }

            Text {
                id: status
                anchors.verticalCenter: parent.verticalCenter
                text: ColorPickerState.picking ? "picking…" : "xcolor"
                color: ColorPickerState.picking ? Theme.warning
                    : ColorPickerState.available ? Theme.foregroundMuted : Theme.error
                font.family: Theme.fontFamily
                font.pixelSize: Math.max(9, Theme.fontSize - 2)
            }
        }

        Rectangle {
            width: parent.width
            height: 104
            radius: Theme.radiusMedium
            color: ColorPickerState.currentColor !== ""
                ? ColorPickerState.currentColor : Theme.surfaceVariant
            border.width: 1
            border.color: Theme.outline

            Text {
                anchors.centerIn: parent
                visible: ColorPickerState.currentColor === ""
                text: "No color picked yet"
                color: Theme.foregroundMuted
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSize
            }
        }

        Row {
            width: parent.width
            height: 34
            spacing: 8

            Rectangle {
                width: parent.width - copyButton.width - parent.spacing
                height: parent.height
                radius: Theme.radiusSmall
                color: Theme.surface
                border.width: 1
                border.color: Theme.outline

                Text {
                    anchors.centerIn: parent
                    text: ColorPickerState.currentColor !== ""
                        ? ColorPickerState.currentColor : "#------"
                    color: Theme.foreground
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSize + 1
                    font.bold: true
                }
            }

            ActionButton {
                id: copyButton
                buttonText: "Copy"
                enabled: ColorPickerState.currentColor !== ""
                opacity: enabled ? 1 : 0.45
                onActivated: ColorPickerState.copy(ColorPickerState.currentColor)
            }
        }

        ActionButton {
            width: parent.width
            buttonText: ColorPickerState.picking
                ? "Click a pixel on screen…" : "  Pick from screen"
            primary: true
            enabled: ColorPickerState.available && !ColorPickerState.picking
            opacity: enabled ? 1 : 0.55
            onActivated: ColorPickerState.pick()
        }

        Text {
            width: parent.width
            height: 18
            text: ColorPickerState.errorMessage !== ""
                ? ColorPickerState.errorMessage
                : ColorPickerState.statusMessage
            color: ColorPickerState.errorMessage !== ""
                ? Theme.error : Theme.foregroundMuted
            font.family: Theme.fontFamily
            font.pixelSize: Math.max(9, Theme.fontSize - 2)
            elide: Text.ElideRight
        }

        Row {
            width: parent.width
            height: 18

            Text {
                width: parent.width - clearHistory.implicitWidth
                anchors.verticalCenter: parent.verticalCenter
                text: "Recent colors"
                color: Theme.foregroundMuted
                font.family: Theme.fontFamily
                font.pixelSize: Math.max(9, Theme.fontSize - 1)
                font.bold: true
            }

            Text {
                id: clearHistory
                anchors.verticalCenter: parent.verticalCenter
                text: "Clear"
                color: clearMouse.containsMouse ? Theme.error
                    : Theme.foregroundMuted
                opacity: ColorPickerState.history.length > 0 ? 1 : 0.4
                font.family: Theme.fontFamily
                font.pixelSize: Math.max(9, Theme.fontSize - 1)

                MouseArea {
                    id: clearMouse
                    anchors.fill: parent
                    anchors.margins: -5
                    enabled: ColorPickerState.history.length > 0
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: ColorPickerState.clearHistory()
                }
            }
        }

        Flow {
            width: parent.width
            spacing: 8

            Repeater {
                model: ColorPickerState.history

                Rectangle {
                    id: swatch
                    required property string modelData
                    width: 44
                    height: 32
                    radius: Theme.radiusSmall
                    color: modelData
                    border.width: 2
                    border.color: swatchMouse.containsMouse
                        ? Theme.foreground : Theme.outline

                    MouseArea {
                        id: swatchMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: ColorPickerState.copy(swatch.modelData)
                    }
                }
            }
        }

        Text {
            visible: ColorPickerState.history.length === 0
            width: parent.width
            text: "Picked colors will appear here"
            color: Theme.disabled
            font.family: Theme.fontFamily
            font.pixelSize: Math.max(9, Theme.fontSize - 1)
        }
    }
}
