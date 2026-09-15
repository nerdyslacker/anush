pragma ComponentBehavior: Bound

import QtQuick
import "../.."
import Quickshell
import Quickshell.Io

Popout {
    id: root

    property var outputs: []
    property var keyboardBacklights: []
    property bool nightLight: false
    property bool redshiftGtkInstalled: false

    cardWidth: 330
    cardHeight: Math.max(100, content.implicitHeight + 2 * cardPadding)
    onVisibleChanged: if (visible) {
        nightLight = ShellState.state.desktop.nightLight === true
        refresh()
    }

    function refresh() {
        outputQuery.running = false
        outputQuery.running = true
        redshiftGtkQuery.running = false
        redshiftGtkQuery.running = true
    }

    function applyBrightness(output, percent) {
        if (output.backend === "backlight") {
            Quickshell.execDetached([
                "brightnessctl", "-d", output.name, "set",
                Math.round(percent) + "%"
            ])
        } else {
            const value = Math.max(0.1, Math.min(1, percent / 100))
            Quickshell.execDetached([
                "xrandr", "--output", output.name,
                "--brightness", String(value)
            ])
        }
    }

    function updateOutput(index, percent) {
        const next = outputs.slice()
        next[index] = {
            name: next[index].name,
            backend: next[index].backend,
            brightness: Math.round(percent)
        }
        outputs = next
    }

    function applyKeyboardBrightness(device, percent) {
        Quickshell.execDetached([
            "brightnessctl", "-d", device.name, "set",
            Math.round(percent) + "%"
        ])
    }

    function updateKeyboardBacklight(index, percent) {
        const next = keyboardBacklights.slice()
        next[index] = {
            name: next[index].name,
            brightness: Math.round(percent)
        }
        keyboardBacklights = next
    }

    function setNightLight(enabled) {
        nightLight = enabled
        ShellState.updateSection("desktop", { nightLight: enabled })
        Quickshell.execDetached(enabled
            ? ["redshift", "-P", "-O", "4500"] : ["redshift", "-x"])
    }

    function openNightSettings() {
        Quickshell.execDetached(["redshift-gtk"])
    }

    Process {
        id: outputQuery
        // Hardware backlights provide real brightness control. XRandR remains
        // a fallback for external outputs that do not expose a sysfs device.
        command: ["sh", "-c",
            "brightnessctl -l -c backlight 2>/dev/null | " +
            "sed -n \"s/^Device '\\([^']*\\)'.*/\\1/p\" | " +
            "while IFS= read -r device; do " +
            "brightnessctl -m -d \"$device\" 2>/dev/null | sed 's/^/BACKLIGHT,/' ; " +
            "done; " +
            "brightnessctl -l -c leds 2>/dev/null | " +
            "sed -n \"s/^Device '\\([^']*\\)'.*/\\1/p\" | " +
            "while IFS= read -r device; do case \"$device\" in " +
            "*kbd*backlight*|*keyboard*backlight*) " +
            "brightnessctl -m -d \"$device\" 2>/dev/null | sed 's/^/KEYBOARD,/' ;; " +
            "esac; done; printf '%s\\n' '--XRANDR--'; " +
            "xrandr --current --verbose 2>/dev/null"]
        stdout: StdioCollector {
            onStreamFinished: {
                const hardware = []
                const keyboards = []
                const randr = []
                let current = null
                let readingRandr = false
                for (const line of text.split("\n")) {
                    if (line === "--XRANDR--") {
                        readingRandr = true
                        continue
                    }
                    if (!readingRandr && line.startsWith("BACKLIGHT,")) {
                        const fields = line.split(",")
                        const percentField = fields.find(field => /%$/.test(field))
                        const percent = parseInt(percentField)
                        if (fields.length >= 5 && !isNaN(percent)) {
                            hardware.push({
                                name: fields[1],
                                backend: "backlight",
                                brightness: percent
                            })
                        }
                        continue
                    }
                    if (!readingRandr && line.startsWith("KEYBOARD,")) {
                        const fields = line.split(",")
                        const percentField = fields.find(field => /%$/.test(field))
                        const percent = parseInt(percentField)
                        if (fields.length >= 5 && !isNaN(percent)) {
                            keyboards.push({
                                name: fields[1],
                                brightness: percent
                            })
                        }
                        continue
                    }
                    if (!readingRandr)
                        continue
                    const connected = line.match(/^(\S+) connected(?:\s|$)/)
                    if (connected) {
                        if (current !== null)
                            randr.push(current)
                        current = {
                            name: connected[1],
                            backend: "xrandr",
                            brightness: 100
                        }
                        continue
                    }
                    if (current !== null) {
                        const level = line.match(/^\s*Brightness:\s*([0-9.]+)/)
                        if (level)
                            current.brightness = Math.round(Number(level[1]) * 100)
                    }
                }
                if (current !== null)
                    randr.push(current)

                // A sysfs backlight normally represents the eDP/LVDS panel.
                // Do not show that same panel twice, but retain other outputs.
                const external = hardware.length === 0 ? randr : randr.filter(
                    output => !/^(eDP|LVDS|DSI)/i.test(output.name))
                root.outputs = hardware.concat(external)
                root.keyboardBacklights = keyboards
            }
        }
    }

    Process {
        id: redshiftGtkQuery
        command: ["sh", "-c", "command -v redshift-gtk >/dev/null 2>&1"]
        onExited: code => root.redshiftGtkInstalled = code === 0
    }

    Connections {
        target: ShellState
        function onStateChanged() {
            root.nightLight = ShellState.state.desktop.nightLight === true
        }
    }

    Component.onCompleted: root.nightLight =
        ShellState.state.desktop.nightLight === true

    component SwitchPill: Rectangle {
        id: pill
        required property bool checked
        signal toggled()
        width: 38
        height: 20
        radius: Math.min(height / 2, Theme.radiusSmall)
        color: checked ? Theme.brightOrange : Qt.alpha(Theme.fg, 0.15)
        border.width: 1
        border.color: checked ? Qt.alpha(Theme.fg, 0.7) : Theme.gray5
        Behavior on color { ColorAnimation { duration: 150 } }
        Rectangle {
            x: pill.checked ? parent.width - width - 3 : 3
            anchors.verticalCenter: parent.verticalCenter
            width: 14
            height: 14
            radius: Math.min(width / 2, Theme.radiusSmall)
            color: pill.checked ? Theme.bg : Qt.alpha(Theme.fg, 0.7)
            Behavior on x { NumberAnimation { duration: 150 } }
        }
        MouseArea { anchors.fill: parent; onClicked: pill.toggled() }
    }

    component SmallButton: Rectangle {
        id: button
        required property string buttonText
        signal activated()
        implicitWidth: label.implicitWidth + 22
        height: 28
        radius: Theme.radiusSmall
        color: pointer.containsMouse ? Qt.alpha(Theme.accent, 0.22)
            : Qt.alpha(Theme.accent, 0.1)
        border.width: 1
        border.color: Theme.accent
        Text {
            id: label
            anchors.centerIn: parent
            text: button.buttonText
            color: Theme.accent
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSize - 1
            font.bold: true
        }
        MouseArea {
            id: pointer
            anchors.fill: parent
            hoverEnabled: true
            onClicked: button.activated()
        }
    }

    Column {
        id: content
        anchors.left: parent.left
        anchors.right: parent.right
        spacing: 9

        Row {
            spacing: 8
            Text {
                text: "󰃠"
                color: Theme.yellow
                font.family: Theme.fontFamily
                font.pixelSize: 18
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: "Display brightness"
                color: Theme.fg
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSize + 1
                font.bold: true
            }
        }

        Text {
            visible: root.outputs.length === 0
            text: "No connected displays found."
            color: Theme.brightBlack
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSize
        }

        Repeater {
            model: root.outputs

            Column {
                id: outputControl
                required property var modelData
                required property int index
                width: content.width
                spacing: 2

                Text {
                    text: outputControl.modelData.backend === "backlight"
                        ? outputControl.modelData.name.replace(/_/g, " ")
                        : outputControl.modelData.name
                    color: Theme.brightBlack
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSize - 1
                }
                TweakSlider {
                    width: parent.width
                    label: "brightness"
                    from: 10
                    to: 100
                    value: outputControl.modelData.brightness
                    suffix: "%"
                    applyFn: value => root.applyBrightness(
                        outputControl.modelData, value)
                    persistFn: value => {}
                    onCommitted: value => root.updateOutput(outputControl.index, value)
                }
            }
        }

        Rectangle {
            visible: root.keyboardBacklights.length > 0
            width: parent.width
            height: 1
            color: Theme.gray5
        }

        Text {
            visible: root.keyboardBacklights.length > 0
            text: "Keyboard backlight"
            color: Theme.fg
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSize
            font.bold: true
        }

        Repeater {
            model: root.keyboardBacklights

            Column {
                id: keyboardControl
                required property var modelData
                required property int index
                width: content.width
                spacing: 2

                Text {
                    text: keyboardControl.modelData.name.replace(/_/g, " ")
                    color: Theme.brightBlack
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSize - 1
                }
                TweakSlider {
                    width: parent.width
                    label: "brightness"
                    from: 0
                    to: 100
                    value: keyboardControl.modelData.brightness
                    suffix: "%"
                    applyFn: value => root.applyKeyboardBrightness(
                        keyboardControl.modelData, value)
                    persistFn: value => {}
                    onCommitted: value => root.updateKeyboardBacklight(
                        keyboardControl.index, value)
                }
            }
        }

        Rectangle { width: parent.width; height: 1; color: Theme.gray5 }

        Rectangle {
            width: parent.width
            height: 48
            radius: Theme.radiusSmall
            color: root.nightLight ? Qt.alpha(Theme.brightOrange, 0.16)
                : Qt.alpha(Theme.fg, 0.05)
            border.width: 1
            border.color: root.nightLight ? Theme.brightOrange : Theme.gray5
            Behavior on color { ColorAnimation { duration: 120 } }

            Text {
                id: nightIcon
                anchors.left: parent.left
                anchors.leftMargin: 11
                anchors.verticalCenter: parent.verticalCenter
                text: "󱩌"
                color: root.nightLight ? Theme.brightOrange : Theme.cyan
                font.family: Theme.fontFamily
                font.pixelSize: 17
            }
            Column {
                anchors.left: nightIcon.right
                anchors.leftMargin: 10
                anchors.right: nightActions.left
                anchors.rightMargin: 10
                anchors.verticalCenter: parent.verticalCenter
                spacing: 1
                Text {
                    text: "Night mode"
                    color: Theme.fg
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSize
                    font.bold: true
                }
                Text {
                    text: root.nightLight ? "4500 K" : "Off"
                    color: root.nightLight
                        ? Theme.brightOrange : Theme.brightBlack
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSize - 2
                }
            }
            Row {
                id: nightActions
                anchors.right: parent.right
                anchors.rightMargin: 9
                anchors.verticalCenter: parent.verticalCenter
                spacing: 8
                SwitchPill {
                    checked: root.nightLight
                    anchors.verticalCenter: parent.verticalCenter
                    onToggled: root.setNightLight(!root.nightLight)
                }
                SmallButton {
                    visible: root.redshiftGtkInstalled
                    anchors.verticalCenter: parent.verticalCenter
                    buttonText: "Settings"
                    onActivated: root.openNightSettings()
                }
            }
        }
    }
}
