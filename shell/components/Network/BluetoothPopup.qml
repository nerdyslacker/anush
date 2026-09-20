pragma ComponentBehavior: Bound

import QtQuick
import "../.."
import Quickshell.Io
import Quickshell.Bluetooth as QsBluetooth

Popout {
    id: root

    cardWidth: 390
    cardHeight: 520
    property string expandedBluetooth: ""

    onVisibleChanged: {
        if (visible) {
            PopupCoordinator.requestOpen("bluetooth", root)
            BluetoothService.error = ""
        } else {
            BluetoothService.stopOwnedScan()
            expandedBluetooth = ""
        }
    }

    Connections {
        target: PopupCoordinator
        function onOpening(name, owner) {
            if (owner !== root) root.visible = false
        }
    }

    IpcHandler {
        target: "bluetooth"
        function toggle(): void { root.visible = !root.visible }
        function open(): void { root.visible = true }
        function close(): void { root.visible = false }
    }

    component SmallButton: Rectangle {
        id: button
        required property string buttonText
        property color accentColor: Theme.accent
        property bool filled: false
        signal activated()
        implicitWidth: label.implicitWidth + 22
        height: 28
        radius: Theme.radiusSmall
        color: filled ? (mouse.containsMouse
            ? Qt.lighter(accentColor, 1.12) : accentColor)
            : mouse.containsMouse ? Qt.alpha(accentColor, 0.24)
            : Qt.alpha(accentColor, 0.12)
        border.width: 1
        border.color: accentColor
        Text {
            id: label
            anchors.centerIn: parent
            text: button.buttonText
            color: button.filled ? Theme.selfg : button.accentColor
            font.family: Theme.fontFamily
            font.pixelSize: 11
            font.bold: true
        }
        MouseArea {
            id: mouse
            anchors.fill: parent
            hoverEnabled: true
            onClicked: button.activated()
        }
    }

    component SwitchPill: Rectangle {
        id: pill
        required property bool checked
        signal toggled()
        width: 38
        height: 20
        radius: Math.min(height / 2, Theme.radiusSmall)
        color: checked ? Theme.accent : Qt.alpha(Theme.fg, 0.16)
        Rectangle {
            x: pill.checked ? parent.width - width - 3 : 3
            anchors.verticalCenter: parent.verticalCenter
            width: 14
            height: 14
            radius: Math.min(width / 2, Theme.radiusSmall)
            color: pill.checked ? Theme.bg : Qt.alpha(Theme.fg, 0.7)
            Behavior on x { NumberAnimation { duration: 140 } }
        }
        MouseArea { anchors.fill: parent; onClicked: pill.toggled() }
    }

    component DeviceRow: Rectangle {
        id: row
        required property var device
        readonly property bool expanded:
            root.expandedBluetooth === device.address
        width: deviceList.width
        height: 34 + (expanded ? 40 : 0)
        radius: Theme.radiusSmall
        clip: true
        color: Theme.gray2
        Behavior on height {
            NumberAnimation { duration: 140; easing.type: Easing.OutCubic }
        }

        Column {
            anchors.fill: parent
            spacing: 0

            Rectangle {
                width: parent.width
                height: 34
                radius: Theme.radiusSmall
                color: row.device.connected ? Qt.alpha(Theme.accent, 0.22)
                    : deviceMouse.containsMouse ? Theme.gray3 : Theme.gray2
                Row {
                    anchors.left: parent.left
                    anchors.leftMargin: 10
                    anchors.right: deviceState.left
                    anchors.rightMargin: 8
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 7
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: BluetoothService.deviceGlyph(row.device, "󰂯")
                        color: row.device.connected ? Theme.accent : Theme.fg
                        font.family: Theme.iconFontFamily
                        font.pixelSize: Theme.iconSize
                    }
                    Text {
                        width: parent.width - x
                        anchors.verticalCenter: parent.verticalCenter
                        text: row.device.name || row.device.deviceName
                            || row.device.address
                        color: row.device.connected ? Theme.accent : Theme.fg
                        elide: Text.ElideRight
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSize
                        font.bold: row.device.connected
                    }
                }
                Row {
                    id: deviceState
                    anchors.right: parent.right
                    anchors.rightMargin: 10
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 5
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: (row.device.connected ? "connected" : "paired")
                            + (row.device.batteryAvailable
                                ? " · " + Math.round(row.device.battery * 100) + "%" : "")
                        color: row.device.connected ? Theme.green : Theme.disabled
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSize - 2
                    }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: row.expanded ? "󰅀" : "󰅂"
                        color: row.device.connected ? Theme.green : Theme.disabled
                        font.family: Theme.iconFontFamily
                        font.pixelSize: Theme.iconSizeSmall
                    }
                }
                MouseArea {
                    id: deviceMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    onClicked: root.expandedBluetooth = row.expanded
                        ? "" : row.device.address
                }
            }

            Item {
                width: parent.width
                height: 40
                Row {
                    anchors.right: parent.right
                    anchors.rightMargin: 5
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 7
                    SmallButton {
                        buttonText: "Forget"
                        accentColor: Theme.red
                        enabled: !BluetoothService.busy
                        opacity: enabled ? 1 : 0.45
                        onActivated: {
                            root.expandedBluetooth = ""
                            BluetoothService.forgetDevice(row.device)
                        }
                    }
                    SmallButton {
                        buttonText: row.device.state
                            === QsBluetooth.BluetoothDeviceState.Connecting
                            ? "Connecting…"
                            : row.device.state
                            === QsBluetooth.BluetoothDeviceState.Disconnecting
                            ? "Disconnecting…"
                            : row.device.connected ? "Disconnect" : "Connect"
                        accentColor: row.device.connected
                            ? Theme.brightOrange : Theme.green
                        filled: true
                        enabled: !BluetoothService.busy && (row.device.state
                            === QsBluetooth.BluetoothDeviceState.Connected
                            || row.device.state
                            === QsBluetooth.BluetoothDeviceState.Disconnected)
                        opacity: enabled ? 1 : 0.45
                        onActivated: BluetoothService.toggleDevice(row.device)
                    }
                }
            }
        }

        Rectangle {
            anchors.fill: parent
            radius: Theme.radiusSmall
            z: 2
            color: "transparent"
            border.width: 1
            border.color: row.expanded || row.device.connected
                ? Theme.accent : Theme.gray5
        }
    }

    Column {
        anchors.fill: parent
        spacing: 9
        focus: true
        Keys.onEscapePressed: root.visible = false

        Row {
            width: parent.width
            height: 30
            spacing: 8
            Text {
                width: parent.width - power.width - parent.spacing
                anchors.verticalCenter: parent.verticalCenter
                text: "Bluetooth"
                color: Theme.fg
                font.family: Theme.fontFamily
                font.pixelSize: 16
                font.bold: true
            }
            SwitchPill {
                id: power
                anchors.verticalCenter: parent.verticalCenter
                checked: BluetoothService.enabled
                enabled: !BluetoothService.blocked
                opacity: enabled ? 1 : 0.45
                onToggled: BluetoothService.togglePower()
            }
        }

        Text {
            width: parent.width
            visible: BluetoothService.available
            text: BluetoothService.adapterName + " · "
                + BluetoothService.adapterState.toLowerCase()
            color: Theme.disabled
            font.family: Theme.fontFamily
            font.pixelSize: 10
            elide: Text.ElideRight
        }

        Rectangle {
            visible: !BluetoothService.available
            width: parent.width
            height: 62
            radius: Theme.radiusMedium
            color: Theme.gray2
            Text {
                anchors.centerIn: parent
                text: "No Bluetooth adapter available"
                color: Theme.disabled
                font.family: Theme.fontFamily
                font.pixelSize: 12
            }
        }

        Rectangle {
            visible: BluetoothService.available && !BluetoothService.enabled
            width: parent.width
            height: 62
            radius: Theme.radiusMedium
            color: Theme.gray2
            Text {
                anchors.centerIn: parent
                text: "Turn on Bluetooth to view devices"
                color: Theme.disabled
                font.family: Theme.fontFamily
                font.pixelSize: 12
            }
        }

        Row {
            visible: BluetoothService.available && BluetoothService.enabled
            width: parent.width
            height: 30
            Text {
                width: parent.width - scan.width
                anchors.verticalCenter: parent.verticalCenter
                text: BluetoothService.connectedDevices.length + " connected · "
                    + BluetoothService.knownDevices.length + " paired"
                color: Theme.disabled
                font.family: Theme.fontFamily
                font.pixelSize: 11
            }
            SmallButton {
                id: scan
                buttonText: BluetoothService.discovering ? "Stop scan" : "Scan"
                accentColor: BluetoothService.discovering ? Theme.brightOrange : Theme.accent
                onActivated: BluetoothService.toggleScan()
            }
        }

        Flickable {
            visible: BluetoothService.available && BluetoothService.enabled
            width: parent.width
            height: Math.max(0, parent.height - y
                - (errorText.visible ? errorText.implicitHeight + 9 : 0))
            contentWidth: width
            contentHeight: deviceList.implicitHeight
            clip: true
            boundsBehavior: Flickable.StopAtBounds

            Column {
                id: deviceList
                width: parent.width
                spacing: 5

                Text {
                    visible: BluetoothService.knownDevices.length > 0
                    text: "PAIRED DEVICES"
                    color: Theme.accent
                    font.family: Theme.fontFamily
                    font.pixelSize: 10
                    font.bold: true
                }
                Repeater {
                    model: BluetoothService.knownDevices
                    DeviceRow { required property var modelData; device: modelData }
                }
                Text {
                    visible: BluetoothService.availableDevices.length > 0
                    topPadding: 6
                    text: "AVAILABLE DEVICES"
                    color: Theme.accent
                    font.family: Theme.fontFamily
                    font.pixelSize: 10
                    font.bold: true
                }
                Repeater {
                    model: BluetoothService.availableDevices
                    Rectangle {
                        id: foundRow
                        required property var modelData
                        readonly property bool expanded:
                            root.expandedBluetooth === modelData.address
                        width: deviceList.width
                        height: 34 + (expanded ? 40 : 0)
                        radius: Theme.radiusSmall
                        clip: true
                        color: Theme.gray2
                        Behavior on height {
                            NumberAnimation { duration: 140; easing.type: Easing.OutCubic }
                        }
                        Column {
                            anchors.fill: parent
                            spacing: 0
                            Rectangle {
                                width: parent.width
                                height: 34
                                radius: Theme.radiusSmall
                                color: foundMouse.containsMouse
                                    ? Theme.gray3 : Theme.gray2
                                Row {
                                    anchors.left: parent.left
                                    anchors.leftMargin: 10
                                    anchors.right: foundTag.left
                                    anchors.rightMargin: 8
                                    anchors.verticalCenter: parent.verticalCenter
                                    spacing: 7
                                    Text {
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: BluetoothService.deviceGlyph(
                                            foundRow.modelData, "󰂱")
                                        color: Qt.alpha(Theme.fg, 0.75)
                                        font.family: Theme.iconFontFamily
                                        font.pixelSize: Theme.iconSize
                                    }
                                    Text {
                                        width: parent.width - x
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: foundRow.modelData.name
                                            || foundRow.modelData.deviceName
                                        color: Qt.alpha(Theme.fg, 0.75)
                                        elide: Text.ElideRight
                                        font.family: Theme.fontFamily
                                        font.pixelSize: Theme.fontSize
                                    }
                                }
                                Row {
                                    id: foundTag
                                    anchors.right: parent.right
                                    anchors.rightMargin: 10
                                    anchors.verticalCenter: parent.verticalCenter
                                    spacing: 5
                                    Text {
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: "new"
                                        color: Theme.disabled
                                        font.family: Theme.fontFamily
                                        font.pixelSize: Theme.fontSize - 1
                                    }
                                    Text {
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: foundRow.expanded ? "󰅀" : "󰅂"
                                        color: Theme.disabled
                                        font.family: Theme.iconFontFamily
                                        font.pixelSize: Theme.iconSizeSmall
                                    }
                                }
                                MouseArea {
                                    id: foundMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    onClicked: root.expandedBluetooth = foundRow.expanded
                                        ? "" : foundRow.modelData.address
                                }
                            }
                            Item {
                                width: parent.width
                                height: 40
                                SmallButton {
                                    anchors.right: parent.right
                                    anchors.rightMargin: 5
                                    anchors.verticalCenter: parent.verticalCenter
                                    buttonText: foundRow.modelData.pairing
                                        ? "Pairing…" : "Pair and connect"
                                    accentColor: Theme.green
                                    filled: true
                                    enabled: !foundRow.modelData.pairing
                                        && !BluetoothService.busy
                                    opacity: enabled ? 1 : 0.45
                                    onActivated: BluetoothService.pairDevice(
                                        foundRow.modelData)
                                }
                            }
                        }
                        Rectangle {
                            anchors.fill: parent
                            radius: Theme.radiusSmall
                            z: 2
                            color: "transparent"
                            border.width: 1
                            border.color: foundRow.expanded
                                ? Theme.accent : Theme.gray5
                        }
                    }
                }
                Text {
                    visible: BluetoothService.knownDevices.length === 0
                        && BluetoothService.availableDevices.length === 0
                    width: parent.width
                    topPadding: 24
                    horizontalAlignment: Text.AlignHCenter
                    text: BluetoothService.discovering ? "Looking for devices…"
                        : "No devices found"
                    color: Theme.disabled
                    font.family: Theme.fontFamily
                    font.pixelSize: 11
                }
            }
        }

        Text {
            id: errorText
            visible: BluetoothService.error !== ""
                || BluetoothService.status !== ""
            width: parent.width
            text: BluetoothService.error !== ""
                ? BluetoothService.error : BluetoothService.status
            color: BluetoothService.error !== "" ? Theme.red : Theme.disabled
            elide: Text.ElideRight
            font.family: Theme.fontFamily
            font.pixelSize: 10
        }

    }
}
