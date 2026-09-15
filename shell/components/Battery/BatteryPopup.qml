import QtQuick
import "../.."
import Quickshell
import Quickshell.Io
import Quickshell.Services.UPower as UPowerService

// Battery-oriented power profile and display blanking controls.
Popout {
    id: root

    property string profile: "balanced"
    readonly property var batteryDevice:
        UPowerService.UPower.devices.values.find(device =>
            device.isLaptopBattery && device.isPresent)
        ?? UPowerService.UPower.displayDevice
    readonly property bool batteryReady: batteryDevice?.ready === true
        && batteryDevice?.isPresent === true
    readonly property real batteryPercentage: Math.max(0, Math.min(100,
        batteryReady ? batteryDevice.percentage * 100 : Sys.battery))
    readonly property bool charging: batteryReady
        ? batteryDevice.state === UPowerService.UPowerDeviceState.Charging
            || batteryDevice.state === UPowerService.UPowerDeviceState.PendingCharge
        : Sys.batteryCharging
    readonly property bool fullyCharged:
        batteryReady
            && batteryDevice.state === UPowerService.UPowerDeviceState.FullyCharged
        || batteryPercentage >= 99.5
            && (!batteryReady || batteryDevice.state
                !== UPowerService.UPowerDeviceState.Discharging)
    readonly property int chargeTarget: Math.max(1, Math.min(100,
        Math.round(Sys.batteryChargeLimit)))
    readonly property string batteryState: batteryReady
        ? UPowerService.UPowerDeviceState.toString(batteryDevice.state) : "Unknown"
    readonly property var profileOrder: ["performance", "balanced", "power-saver"]
    readonly property var profileIcons: ({
        performance: "󰃅",
        balanced: "󰾅",
        "power-saver": "󰾆"
    })

    cardWidth: 300
    cardHeight: content.implicitHeight + 2 * cardPadding
    onVisibleChanged: if (visible) stateQuery.running = true

    function formatDuration(seconds) {
        // Ignore missing and clearly invalid UPower estimates. Some firmware
        // reports a huge time-to-empty sentinel while the battery is full.
        if (!isFinite(seconds) || seconds <= 0 || seconds > 7 * 24 * 60 * 60)
            return ""
        const minutes = Math.round(seconds / 60)
        const hours = Math.floor(minutes / 60)
        const remainder = minutes % 60
        return (hours > 0 ? hours + "h " : "") + remainder + "m"
    }

    function formatEnergy(value) {
        return isFinite(value) && value > 0 ? value.toFixed(1) + " Wh" : "—"
    }

    readonly property string estimate: {
        if (!batteryReady)
            return ""
        const isCharging = batteryDevice.state
            === UPowerService.UPowerDeviceState.Charging
        const isDischarging = batteryDevice.state
            === UPowerService.UPowerDeviceState.Discharging
        if (!isCharging && !isDischarging)
            return ""
        const seconds = isCharging
            ? batteryDevice.timeToFull : batteryDevice.timeToEmpty
        const duration = formatDuration(seconds)
        if (duration === "")
            return ""
        return duration + (isCharging ? " until full" : " remaining")
    }

    readonly property var batteryDetails: batteryReady ? [
        { label: "Energy", value: formatEnergy(batteryDevice.energy)
            + " / " + formatEnergy(batteryDevice.energyCapacity) },
        { label: batteryDevice.state === UPowerService.UPowerDeviceState.Charging
            || batteryDevice.state === UPowerService.UPowerDeviceState.PendingCharge
            ? "Charge rate" : "Power draw",
          value: batteryDevice.changeRate > 0
            ? batteryDevice.changeRate.toFixed(1) + " W" : "—" },
        { label: "Health", value: batteryDevice.healthSupported
            ? Math.round(batteryDevice.healthPercentage * 100) + "%" : "—" },
        { label: "State", value: batteryState },
        { label: "Model", value: batteryDevice.model || batteryDevice.nativePath }
    ] : []

    function cycleProfile() {
        const at = profileOrder.indexOf(profile)
        const next = profileOrder[(Math.max(0, at) + 1) % profileOrder.length]
        profile = next
        Quickshell.execDetached(["powerprofilesctl", "set", next])
    }

    function setCaffeine(enabled) {
        Sys.setKeepAwake(enabled)
    }

    function setShowPercentage(enabled) {
        ShellState.updateSection("desktop", { showBatteryPercentage: enabled })
    }

    Process {
        id: stateQuery
        command: ["powerprofilesctl", "get"]
        stdout: StdioCollector {
            onStreamFinished: {
                const value = text.trim()
                if (root.profileOrder.indexOf(value) >= 0)
                    root.profile = value
            }
        }
    }

    component SettingButton: Rectangle {
        id: button
        required property string buttonIcon
        radius: Theme.radiusSmall
        required property string title
        required property string detail
        required property bool active
        signal activated()

        width: parent.width
        height: 48
        color: active ? Theme.selbg
            : pointer.containsMouse ? Qt.alpha(Theme.fg, 0.12)
            : Qt.alpha(Theme.fg, 0.05)
        border.width: 1
        border.color: active ? Theme.accent : Theme.gray5
        Behavior on color { ColorAnimation { duration: 120 } }

        Text {
            anchors.left: parent.left
            anchors.leftMargin: 11
            anchors.verticalCenter: parent.verticalCenter
            text: button.buttonIcon
            color: button.active ? Theme.selfg : Theme.cyan
            font.family: Theme.fontFamily
            font.pixelSize: 17
        }
        Column {
            anchors.left: parent.left
            anchors.leftMargin: 42
            anchors.right: parent.right
            anchors.rightMargin: 9
            anchors.verticalCenter: parent.verticalCenter
            spacing: 1
            Text {
                text: button.title
                color: button.active ? Theme.selfg : Theme.fg
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSize
                font.bold: true
            }
            Text {
                text: button.detail
                color: button.active ? Qt.alpha(Theme.selfg, 0.75) : Theme.brightBlack
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSize - 2
            }
        }
        MouseArea {
            id: pointer
            anchors.fill: parent
            hoverEnabled: true
            onClicked: button.activated()
        }
    }

    component SettingSwitch: Rectangle {
        id: setting
        required property string title
        required property string detail
        required property bool checked
        signal toggled()

        width: parent.width
        height: 48
        radius: Theme.radiusSmall
        color: switchMouse.containsMouse ? Qt.alpha(Theme.fg, 0.12)
            : Qt.alpha(Theme.fg, 0.05)
        border.width: 1
        border.color: Theme.gray5
        Behavior on color { ColorAnimation { duration: 120 } }

        Column {
            anchors.left: parent.left
            anchors.leftMargin: 11
            anchors.right: toggle.left
            anchors.rightMargin: 9
            anchors.verticalCenter: parent.verticalCenter
            spacing: 1
            Text {
                text: setting.title
                color: Theme.fg
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSize
                font.bold: true
            }
            Text {
                text: setting.detail
                color: Theme.brightBlack
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSize - 2
            }
        }

        Rectangle {
            id: toggle
            anchors.right: parent.right
            anchors.rightMargin: 11
            anchors.verticalCenter: parent.verticalCenter
            width: 34
            height: 18
            radius: Math.min(height / 2, Theme.radiusSmall)
            color: setting.checked ? Theme.accent : Qt.alpha(Theme.fg, 0.15)
            Behavior on color { ColorAnimation { duration: 150 } }

            Rectangle {
                x: setting.checked ? parent.width - width - 2 : 2
                anchors.verticalCenter: parent.verticalCenter
                width: 14
                height: 14
                radius: Math.min(width / 2, Theme.radiusSmall)
                color: setting.checked ? Theme.bg : Qt.alpha(Theme.fg, 0.7)
                Behavior on x {
                    NumberAnimation { duration: 150; easing.type: Easing.OutCubic }
                }
            }
        }

        MouseArea {
            id: switchMouse
            anchors.fill: parent
            hoverEnabled: true
            onClicked: setting.toggled()
        }
    }

    Column {
        id: content
        anchors.left: parent.left
        anchors.right: parent.right
        spacing: 7

        Text {
            text: root.batteryReady ? "Battery · "
                + root.batteryState.toLowerCase()
                : Sys.batteryCharging ? "Battery · charging" : "Battery"
            color: Theme.fg
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSize + 1
            font.bold: true
        }
        Text {
            readonly property int percent: Math.round(root.batteryPercentage)
            readonly property int targetRemaining:
                Math.max(0, root.chargeTarget - percent)
            text: root.fullyCharged
                ? percent + "% charged"
                : root.charging
                ? percent + "% charged · " + targetRemaining + "% to "
                    + (root.chargeTarget < 100
                        ? root.chargeTarget + "% limit" : "full")
                : percent + "% remaining"
            color: Theme.brightBlack
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSize
        }
        Text {
            visible: root.estimate !== ""
            text: root.estimate
            color: Theme.accent
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSize - 1
        }

        Rectangle {
            visible: root.batteryDetails.length > 0
            width: parent.width
            height: details.implicitHeight + 16
            radius: Theme.radiusSmall
            color: Qt.alpha(Theme.fg, 0.05)
            border.width: 1
            border.color: Theme.gray5

            Column {
                id: details
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.margins: 8
                spacing: 5

                Repeater {
                    model: root.batteryDetails
                    Row {
                        id: detailRow
                        required property var modelData
                        width: details.width
                        Text {
                            width: parent.width * 0.38
                            text: detailRow.modelData.label
                            color: Theme.brightBlack
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSize - 1
                        }
                        Text {
                            width: parent.width * 0.62
                            horizontalAlignment: Text.AlignRight
                            text: detailRow.modelData.value
                            color: Theme.fg
                            elide: Text.ElideRight
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSize - 1
                            font.bold: true
                        }
                    }
                }
            }
        }
        Rectangle { width: parent.width; height: 1; color: Theme.gray5 }

        SettingButton {
            buttonIcon: root.profileIcons[root.profile] ?? "󰾅"
            title: "Power profile"
            detail: root.profile
            active: root.profile !== "balanced"
            onActivated: root.cycleProfile()
        }
        SettingButton {
            buttonIcon: "󰅶"
            title: "Keep awake"
            detail: Sys.keepAwake ? "Screen blanking disabled" : "Screen blanking enabled"
            active: Sys.keepAwake
            onActivated: root.setCaffeine(!Sys.keepAwake)
        }
        SettingSwitch {
            title: "Battery percentage"
            detail: checked ? "Shown on bar" : "Hidden from bar"
            checked: ShellState.state.desktop.showBatteryPercentage !== false
            onToggled: root.setShowPercentage(!checked)
        }
    }
}
