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
