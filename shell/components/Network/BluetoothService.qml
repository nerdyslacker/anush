pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Bluetooth as QsBluetooth

// BlueZ state is reactive through Quickshell. Device actions preserve the
// previous bluetoothctl workflow; power and discovery use the native adapter.
Singleton {
    id: root

    readonly property var adapter: QsBluetooth.Bluetooth.defaultAdapter
    readonly property bool available: adapter !== null
    readonly property bool enabled: adapter?.enabled ?? false
    readonly property bool discovering: adapter?.discovering ?? false
    readonly property string adapterName: adapter?.name ?? ""
    readonly property string adapterState: adapter
        ? QsBluetooth.BluetoothAdapterState.toString(adapter.state) : "Unavailable"
    readonly property bool blocked: adapter?.state
        === QsBluetooth.BluetoothAdapterState.Blocked
    readonly property var devices: QsBluetooth.Bluetooth.devices.values.filter(
        device => !adapter || device.adapter === adapter)
    readonly property var connectedDevices: devices.filter(device =>
        device.connected)
    readonly property var knownDevices: devices.filter(device =>
        device.paired || device.bonded)
    readonly property var availableDevices: devices.filter(device =>
        !device.paired && !device.bonded && device.name !== "")
    readonly property bool connected: connectedDevices.length > 0
    property string error: ""
    property string status: ""
    property bool busy: false
    property bool ownsDiscovery: false
    property var _steps: []
    property var _actionErrors: []

    // BlueZ exposes a freedesktop icon name for most devices. Some devices
    // omit it or only publish a generic value, so recognizable product names
    // provide a conservative fallback before returning the Bluetooth glyph.
    function deviceGlyph(device, fallback) {
        if (!device)
            return fallback || "󰂯"
        const icon = String(device.icon ?? "").toLowerCase()
        const name = String(device.name || device.deviceName || "").toLowerCase()
        const identity = icon + " " + name

        if (identity.indexOf("headphone") >= 0
                || identity.indexOf("headset") >= 0
                || identity.indexOf("earbud") >= 0
                || identity.indexOf("airpod") >= 0
                || identity.indexOf("audio-head") >= 0)
            return "󰋋"
        if (identity.indexOf("input-mouse") >= 0
                || identity.indexOf(" mouse") >= 0)
            return "󰍽"
        if (identity.indexOf("keyboard") >= 0)
            return "󰌌"
        if (identity.indexOf("gamepad") >= 0
                || identity.indexOf("gaming") >= 0
                || identity.indexOf("controller") >= 0
                || identity.indexOf("joystick") >= 0)
            return "󰊴"
        if (identity.indexOf("phone") >= 0
                || identity.indexOf("smartphone") >= 0)
            return "󰏲"
        if (identity.indexOf("tablet") >= 0)
            return "󰓶"
        if (identity.indexOf("laptop") >= 0
                || identity.indexOf("notebook") >= 0)
            return "󰌢"
        if (identity.indexOf("computer") >= 0
                || identity.indexOf("desktop") >= 0)
            return "󰍹"
        if (identity.indexOf("television") >= 0
                || identity.indexOf("display") >= 0
                || identity.indexOf(" tv") >= 0)
            return "󰔂"
        if (identity.indexOf("printer") >= 0)
            return "󰐪"
        if (identity.indexOf("camera") >= 0)
            return "󰄀"
        if (identity.indexOf("watch") >= 0
                || identity.indexOf("wearable") >= 0
                || identity.indexOf("fitness") >= 0)
            return "󰖉"
        if (identity.indexOf("speaker") >= 0
                || identity.indexOf("audio-card") >= 0
                || identity.indexOf("audio-speaker") >= 0)
            return "󰓃"
        return fallback || "󰂯"
    }

    function togglePower() {
        if (!adapter) {
            error = "No Bluetooth adapter available"
            return
        }
        error = ""
        adapter.enabled = !adapter.enabled
    }

    function toggleScan() {
        if (!adapter || !adapter.enabled)
            return
        error = ""
        if (adapter.discovering) {
            adapter.discovering = false
            ownsDiscovery = false
        } else {
            adapter.discovering = true
            ownsDiscovery = true
        }
    }

    function stopOwnedScan() {
        if (adapter && ownsDiscovery && adapter.discovering)
            adapter.discovering = false
        ownsDiscovery = false
    }

    function toggleDevice(device) {
        if (!device || device.pairing || busy)
            return
        runSteps([["bluetoothctl", device.connected ? "disconnect" : "connect",
            device.address]], (device.connected ? "Disconnecting " : "Connecting ")
            + (device.name || device.deviceName) + "…")
    }

    function forgetDevice(device) {
        if (!device || device.pairing || busy)
            return
        runSteps([["bluetoothctl", "remove", device.address]],
            "Forgetting " + (device.name || device.deviceName) + "…")
    }

    function pairDevice(device) {
        if (!device || device.pairing || busy)
            return
        // Preserve the old PIN-less pair -> trust -> connect workflow. More
        // involved agent/PIN exchanges remain outside this quick popup.
        runSteps([
            ["bluetoothctl", "pair", device.address],
            ["bluetoothctl", "trust", device.address],
            ["bluetoothctl", "connect", device.address]
        ], "Pairing " + (device.name || device.deviceName) + "…")
    }

    function runSteps(steps, message) {
        if (busy || !steps.length)
            return
        error = ""
        status = message
        busy = true
        _actionErrors = []
        _steps = steps.slice()
        runNextStep()
    }

    function runNextStep() {
        if (!_steps.length)
            return
        const remaining = _steps.slice()
        const next = remaining.shift()
        _steps = remaining
        action.command = next
        action.running = true
    }

    function openSettings() {
        Quickshell.execDetached(["blueman-manager"])
    }

    Connections {
        target: root.adapter
        function onDiscoveringChanged() {
            if (!root.adapter.discovering) root.ownsDiscovery = false
        }
    }

    Process {
        id: action
        stderr: SplitParser {
            onRead: line => {
                const value = line.trim()
                if (value !== "") root._actionErrors.push(value)
            }
        }
        onExited: code => {
            if (code === 0 && root._steps.length) {
                nextStep.restart()
                return
            }
            root.busy = false
            root._steps = []
            root.error = code === 0 ? "" : (root._actionErrors.length
                ? root._actionErrors[root._actionErrors.length - 1]
                : "Bluetooth action failed")
            root.status = code === 0 ? "Bluetooth updated" : ""
            clearStatus.restart()
        }
    }

    Timer { id: nextStep; interval: 0; onTriggered: root.runNextStep() }
    Timer { id: clearStatus; interval: 3500; onTriggered: root.status = "" }
}
