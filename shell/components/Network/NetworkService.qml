pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Networking as QsNetwork

// Reactive NetworkManager state comes from Quickshell's native networking
// backend. Actions preserve the shell's established nmcli behaviour, while
// `nmcli monitor` invalidates saved-profile/VPN snapshots without polling.
Singleton {
    id: root

    readonly property bool available:
        QsNetwork.Networking.backend !== QsNetwork.NetworkBackendType.None
    readonly property bool wifiEnabled: QsNetwork.Networking.wifiEnabled
    readonly property bool wifiHardwareEnabled:
        QsNetwork.Networking.wifiHardwareEnabled
    readonly property var devices: QsNetwork.Networking.devices.values
    readonly property var wifiDevices: devices.filter(device =>
        device.type === QsNetwork.DeviceType.Wifi)
    readonly property var wiredDevices: devices.filter(device =>
        device.type === QsNetwork.DeviceType.Wired)
    readonly property var wifiDevice: wifiDevices.length ? wifiDevices[0] : null
    readonly property var wifiNetworks: wifiDevice
        ? wifiDevice.networks.values : []
    readonly property var activeWifi: wifiNetworks.find(network =>
        network.connected) ?? null
    readonly property var activeWired: wiredDevices.find(device =>
        device.connected) ?? null
    readonly property string primaryName: activeWifi?.name
        ?? activeWired?.network?.name ?? ""
    readonly property string primaryType: activeWifi ? "802-11-wireless"
        : activeWired ? "802-3-ethernet" : ""
    readonly property bool online: primaryName !== ""

    property var vpns: [] // {name, active, external, device}
    property var savedWifi: []
    readonly property bool vpnOn: vpns.some(vpn => vpn.active)
    readonly property string vpnName: {
        const active = vpns.find(vpn => vpn.active)
        return active ? active.name : ""
    }
    property bool loadingVpns: false
    property string vpnError: ""
    property bool busy: false
    property string status: ""
    property string error: ""
    property bool popupActive: false
    property var _vpnBuffer: []
    property var _wifiBuffer: []
    property var _actionErrors: []
    property var _vpnErrors: []

    function unescapeNm(value) {
        let result = ""
        for (let i = 0; i < value.length; ++i) {
            if (value[i] === "\\" && i + 1 < value.length)
                ++i
            result += value[i]
        }
        return result
    }

    function setPopupActive(active) {
        popupActive = active
        updateScanning()
        if (active)
            refreshVpns()
    }

    function updateScanning() {
        for (const device of wifiDevices)
            device.scannerEnabled = popupActive && wifiEnabled
    }

    function toggleWifi() {
        error = ""
        QsNetwork.Networking.wifiEnabled = !wifiEnabled
    }

    function rescanWifi() {
        if (!wifiEnabled)
            return
        // Toggling scannerEnabled asks the NetworkManager backend for a fresh
        // scan while keeping subsequent access-point changes reactive.
        for (const device of wifiDevices) {
            device.scannerEnabled = false
            device.scannerEnabled = true
        }
    }

    function activateNetwork(network, password) {
        if (!network || network.stateChanging || busy || !wifiDevice)
            return
        error = ""
        if (network.connected) {
            runAction(["nmcli", "device", "disconnect", wifiDevice.name],
                "Disconnecting " + network.name + "…")
        } else if (network.known || savedWifi.indexOf(network.name) !== -1) {
            runAction(["nmcli", "connection", "up", "id", network.name],
                "Connecting to " + network.name + "…")
        } else if (network.security === QsNetwork.WifiSecurityType.Open) {
            runAction(["nmcli", "device", "wifi", "connect", network.name],
                "Connecting to " + network.name + "…")
        } else {
            runAction(["nmcli", "device", "wifi", "connect", network.name,
                "password", password], "Connecting to " + network.name + "…")
        }
    }

    function reportConnectionFailure(reason) {
        error = "Connection failed: "
            + QsNetwork.ConnectionFailReason.toString(reason)
    }

    function refreshVpns() {
        if (vpnList.running)
            return
        loadingVpns = true
        vpnList.running = true
    }

    function toggleVpn(vpn) {
        if (!vpn || vpn.external || busy)
            return
        runAction(["nmcli", "connection", vpn.active ? "down" : "up",
            "id", vpn.name], (vpn.active ? "Disconnecting " : "Connecting ")
            + vpn.name + "…")
    }

    function runAction(command, message) {
        if (busy)
            return
        error = ""
        status = message
        busy = true
        _actionErrors = []
        vpnAction.command = command
        vpnAction.running = true
    }

    function openSettings() {
        Quickshell.execDetached(["nm-connection-editor"])
    }

    Process {
        id: vpnList
        // Put the human-controlled name last. Older nmcli releases do not
        // support --separator, so only split the first three safe fields.
        command: ["nmcli", "-t", "-f", "TYPE,ACTIVE,DEVICE,NAME",
            "connection", "show"]
        stdout: SplitParser {
            onRead: line => {
                const first = line.indexOf(":")
                const second = line.indexOf(":", first + 1)
                const third = line.indexOf(":", second + 1)
                if (first < 0 || second < 0 || third < 0)
                    return
                const type = line.slice(0, first)
                const name = root.unescapeNm(line.slice(third + 1))
                if (type.indexOf("wireless") !== -1)
                    root._wifiBuffer.push(name)
                else if (type === "vpn" || type === "wireguard" || type === "tun")
                    root._vpnBuffer.push({
                        name: name, type: type,
                        active: line.slice(first + 1, second) === "yes",
                        external: type === "tun",
                        device: line.slice(second + 1, third)
                    })
            }
        }
        stderr: SplitParser {
            onRead: line => {
                const value = line.trim()
                if (value !== "") root._vpnErrors.push(value)
            }
        }
        onRunningChanged: {
            if (running) {
                root._vpnBuffer = []
                root._wifiBuffer = []
                root._vpnErrors = []
            }
        }
        onExited: code => {
            root.vpns = root._vpnBuffer
            root.savedWifi = root._wifiBuffer
            root.loadingVpns = false
            root.vpnError = code === 0 ? "" : (root._vpnErrors.length
                ? root._vpnErrors[root._vpnErrors.length - 1]
                : "VPN profiles are unavailable")
        }
    }

    Process {
        id: vpnAction
        stderr: SplitParser {
            onRead: line => {
                const value = line.trim()
                if (value !== "") root._actionErrors.push(value)
            }
        }
        onExited: code => {
            root.busy = false
            root.status = code === 0 ? "Network updated" : ""
            root.error = code === 0 ? "" : (root._actionErrors.length
                ? root._actionErrors[root._actionErrors.length - 1]
                : "Network action failed")
            root.refreshVpns()
            clearStatus.restart()
        }
    }

    Timer {
        id: clearStatus
        interval: 3500
        onTriggered: root.status = ""
    }

    // Event-driven invalidation rather than a refresh timer. This also catches
    // NetworkManager restarts; if the monitor exits, retry at a low cadence.
    Process {
        id: nmMonitor
        running: true
        command: ["nmcli", "monitor"]
        stdout: SplitParser {
            onRead: line => vpnRefreshDebounce.restart()
        }
        onExited: monitorRestart.restart()
    }

    Timer {
        id: vpnRefreshDebounce
        interval: 250
        onTriggered: root.refreshVpns()
    }

    Timer {
        id: monitorRestart
        interval: 3000
        onTriggered: nmMonitor.running = true
    }

    Connections {
        target: QsNetwork.Networking
        function onWifiEnabledChanged() {
            root.updateScanning()
        }
    }

    Connections {
        target: QsNetwork.Networking.devices
        function onValuesChanged() { root.updateScanning() }
    }

    Component.onCompleted: refreshVpns()
}
