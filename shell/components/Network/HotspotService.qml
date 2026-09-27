pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import "../.."

// qmllint disable signal-handler-parameters
// Quickshell's qmltypes references QProcess::ExitStatus without exporting it.

// Central hotspot state and process ownership. NetworkManager remains the
// source of truth; the helper only translates libnm/iw state into JSON and
// performs profile transactions. Passwords are sent over stdin and retained
// here only while the popup is open.
Singleton {
    id: root

    readonly property string helperPath: ShellState.scriptsDir + "/hotspot-control"
    property bool available: false
    property bool supported: false
    property string supportReason: "Checking hotspot support…"
    property bool active: false
    property bool profileExists: false
    property string ssid: ""
    property string password: ""
    property string band: "auto"
    property int channel: 0
    property string wifiDevice: ""
    property string apInterface: ""
    property var wifiDevices: []
    property var upstreams: []
    property string upstreamUuid: ""
    property string upstreamType: ""
    property bool upstreamLost: false
    property string upstreamMessage: ""
    property bool vpnProtected: false
    property var bands: [{ value: "auto", label: "Auto" }]
    property var channels: []
    property var clients: []
    property int clientCount: 0
    property int maxClients: 0
    property bool clientLimitSupported: false
    property string clientLimitHelper: ""
    property string clientLimitRootRunner: ""
    property string clientLimitReason: ""
    property var dependencies: ({})
    property bool busy: false
    property string action: ""
    property string error: ""
    property string message: ""
    property bool popupActive: false
    property string _actionPayload: ""
    property var _statusErrors: []
    property var _actionErrors: []
    property bool _actionTimedOut: false
    property var _limitErrors: []
    property bool _limitStopping: false

    signal popupRequested(string action)

    readonly property var usableUpstreams: upstreams.filter(item => item.usable)
    readonly property var selectedWifiDevice: wifiDevices.find(item =>
        item.name === wifiDevice) ?? null

    function parseResult(raw, fallback) {
        try {
            const parsed = JSON.parse(String(raw || "{}"))
            if (parsed && typeof parsed === "object")
                return parsed
        } catch (exception) {
            console.warn("hotspot-control JSON:", exception)
        }
        return { error: fallback }
    }

    function applyStatus(value) {
        if (!value || typeof value !== "object")
            return
        if (value.available !== undefined) available = value.available === true
        if (value.supported !== undefined) supported = value.supported === true
        if (value.supportReason !== undefined) supportReason = String(value.supportReason)
        if (value.active !== undefined) active = value.active === true
        if (value.profileExists !== undefined) profileExists = value.profileExists === true
        if (value.ssid !== undefined) ssid = String(value.ssid)
        if (value.band !== undefined) band = String(value.band)
        if (value.channel !== undefined) channel = Number(value.channel) || 0
        if (value.wifiDevice !== undefined) wifiDevice = String(value.wifiDevice)
        if (value.apInterface !== undefined) apInterface = String(value.apInterface)
        if (Array.isArray(value.wifiDevices)) wifiDevices = value.wifiDevices
        if (Array.isArray(value.upstreams)) upstreams = value.upstreams
        if (value.upstreamUuid !== undefined) upstreamUuid = String(value.upstreamUuid)
        if (value.upstreamType !== undefined) upstreamType = String(value.upstreamType)
        if (value.upstreamLost !== undefined) upstreamLost = value.upstreamLost === true
        if (value.upstreamMessage !== undefined)
            upstreamMessage = String(value.upstreamMessage)
        if (value.vpnProtected !== undefined) vpnProtected = value.vpnProtected === true
        if (Array.isArray(value.bands)) bands = value.bands
        if (Array.isArray(value.channels)) channels = value.channels
        if (Array.isArray(value.clients)) clients = value.clients
        if (value.clientCount !== undefined) clientCount = Number(value.clientCount) || 0
        if (value.maxClients !== undefined) maxClients = Number(value.maxClients) || 0
        if (value.clientLimitSupported !== undefined)
            clientLimitSupported = value.clientLimitSupported === true
        if (value.clientLimitHelper !== undefined)
            clientLimitHelper = String(value.clientLimitHelper)
        if (value.clientLimitRootRunner !== undefined)
            clientLimitRootRunner = String(value.clientLimitRootRunner)
        if (value.clientLimitReason !== undefined)
            clientLimitReason = String(value.clientLimitReason)
        if (value.dependencies && typeof value.dependencies === "object")
            dependencies = value.dependencies
        if (value.generatedPassword)
            password = String(value.generatedPassword)
        if (value.error)
            error = String(value.error)
    }

    function refresh() {
        if (statusProcess.running || busy)
            return
        _statusErrors = []
        statusProcess.running = true
    }

    function setPopupActive(value) {
        popupActive = value
        if (value) {
            error = ""
            refresh()
            refreshCredentials()
        } else {
            password = ""
        }
    }

    function refreshCredentials() {
        if (!popupActive || credentialsProcess.running || busy)
            return
        credentialsProcess.running = true
    }

    function runAction(name, payload) {
        if (busy)
            return
        busy = true
        action = name
        error = ""
        message = name === "off" ? "Stopping hotspot…"
            : name === "on" ? "Starting hotspot…" : "Saving hotspot settings…"
        _actionErrors = []
        _actionTimedOut = false
        _actionPayload = payload === undefined ? "" : JSON.stringify(payload) + "\n"
        actionProcess.command = ["python3", helperPath, name]
        actionProcess.running = true
        actionTimeout.restart()
    }

    function applyConfiguration(configuration, activate) {
        runAction(activate ? "on" : "apply", configuration)
    }

    function turnOn() { runAction("on", {}) }
    function turnOff() { runAction("off") }
    function toggle() { active ? turnOff() : turnOn() }

    function limitShouldRun() {
        return active && maxClients > 0 && clientLimitSupported
            && clientLimitHelper !== "" && clientLimitRootRunner !== ""
            && apInterface !== ""
    }

    function syncLimitEnforcer() {
        limitRestart.stop()
        if (limitProcess.running) {
            _limitStopping = true
            limitProcess.running = false
            return
        }
        if (!_limitStopping && limitShouldRun()) {
            limitRestart.restart()
        }
    }

    onActiveChanged: syncLimitEnforcer()
    onMaxClientsChanged: syncLimitEnforcer()
    onClientLimitSupportedChanged: syncLimitEnforcer()
    onClientLimitHelperChanged: syncLimitEnforcer()
    onClientLimitRootRunnerChanged: syncLimitEnforcer()
    onWifiDeviceChanged: syncLimitEnforcer()
    onApInterfaceChanged: syncLimitEnforcer()

    Process {
        id: statusProcess
        command: ["python3", root.helperPath, "status"]
        stdout: StdioCollector { id: statusOutput; waitForEnd: true }
        stderr: SplitParser {
            onRead: line => {
                const value = line.trim()
                if (value !== "") root._statusErrors.push(value)
            }
        }
        onExited: code => {
            const result = root.parseResult(statusOutput.text,
                root._statusErrors.length ? root._statusErrors[root._statusErrors.length - 1]
                    : "Could not read hotspot state")
            if (code !== 0 && !result.error)
                result.error = "Could not read hotspot state"
            root.applyStatus(result)
        }
    }

    Process {
        id: credentialsProcess
        command: ["python3", root.helperPath, "credentials"]
        stdout: StdioCollector { id: credentialsOutput; waitForEnd: true }
        onExited: code => {
            const result = root.parseResult(credentialsOutput.text,
                "Could not read hotspot credentials")
            if (code === 0) {
                root.password = String(result.password || "")
                if (!root.profileExists && result.ssid)
                    root.ssid = String(result.ssid)
            } else if (root.popupActive) {
                root.error = String(result.error || "Could not read hotspot credentials")
            }
        }
    }

    Process {
        id: actionProcess
        stdinEnabled: true
        stdout: StdioCollector { id: actionOutput; waitForEnd: true }
        stderr: SplitParser {
            onRead: line => {
                const value = line.trim()
                if (value !== "") root._actionErrors.push(value)
            }
        }
        onStarted: {
            if (root._actionPayload !== "")
                write(root._actionPayload)
            root._actionPayload = ""
        }
        onExited: code => {
            actionTimeout.stop()
            if (root._actionTimedOut) {
                root._actionTimedOut = false
                return
            }
            const fallback = root._actionErrors.length
                ? root._actionErrors[root._actionErrors.length - 1]
                : "Hotspot action failed"
            const result = root.parseResult(actionOutput.text, fallback)
            root.busy = false
            root.action = ""
            root.message = code === 0 ? "Hotspot updated" : ""
            root.error = code === 0 ? String(result.error || "")
                : String(result.error || fallback)
            root.applyStatus(result)
            if (root.popupActive)
                root.refreshCredentials()
            clearMessage.restart()
        }
    }

    // NetworkManager's wpa_supplicant profile API does not expose a station
    // cap. One elevated watcher removes stations above the saved limit through
    // nl80211 while this hotspot is active, avoiding repeated authentication.
    Process {
        id: limitProcess
        stdout: StdioCollector { waitForEnd: true }
        stderr: SplitParser {
            onRead: line => {
                const value = line.trim()
                if (value !== "") root._limitErrors.push(value)
            }
        }
        onExited: code => {
            if (root._limitStopping) {
                root._limitStopping = false
                if (root.limitShouldRun()) limitRestart.restart()
                return
            }
            if (code !== 0 && root.limitShouldRun()) {
                root.error = root._limitErrors.length
                    ? root._limitErrors[root._limitErrors.length - 1]
                    : "Could not enforce the hotspot client limit."
            } else if (root.limitShouldRun()) {
                limitRestart.restart()
            }
        }
    }

    // NetworkManager events invalidate hotspot/upstream/profile state without
    // repeated nmcli polling. Client stations are refreshed modestly only
    // while their popup is visible.
    Process {
        id: nmMonitor
        command: ["nmcli", "monitor"]
        running: true
        stdout: SplitParser { onRead: line => refreshDebounce.restart() }
        onExited: monitorRestart.restart()
    }

    Timer {
        id: refreshDebounce
        interval: 300
        onTriggered: root.refresh()
    }

    Timer {
        id: actionTimeout
        interval: 75000
        onTriggered: {
            if (!actionProcess.running) return
            root._actionTimedOut = true
            actionProcess.running = false
            root.busy = false
            root.action = ""
            root.message = ""
            root.error = "Hotspot action timed out. Check NetworkManager and the polkit agent."
            refreshDebounce.restart()
        }
    }

    Timer {
        id: limitRestart
        interval: 2000
        onTriggered: {
            if (!root.limitShouldRun() || limitProcess.running) return
            root._limitErrors = []
            limitProcess.command = [root.clientLimitRootRunner,
                root.clientLimitHelper, "--watch", root.apInterface,
                String(root.maxClients)]
            limitProcess.running = true
        }
    }

    Timer {
        id: monitorRestart
        interval: 3000
        onTriggered: nmMonitor.running = true
    }

    Timer {
        interval: 5000
        repeat: true
        running: root.popupActive
        onTriggered: root.refresh()
    }

    Timer {
        id: clearMessage
        interval: 3500
        onTriggered: root.message = ""
    }

    IpcHandler {
        target: "hotspot"
        function status(): string {
            root.refresh()
            return JSON.stringify({
                available: root.available,
                supported: root.supported,
                active: root.active,
                ssid: root.ssid,
                wifiDevice: root.wifiDevice,
                upstreamType: root.upstreamType,
                upstreamUuid: root.upstreamUuid,
                upstreamLost: root.upstreamLost,
                vpnProtected: root.vpnProtected,
                band: root.band,
                channel: root.channel,
                clientCount: root.clientCount,
                error: root.error
            })
        }
        function enable(): string { root.turnOn(); return "accepted" }
        function disable(): string { root.turnOff(); return "accepted" }
        function toggle(): string { root.toggle(); return "accepted" }
        function clients(): string { return JSON.stringify(root.clients) }
        function openPopup(): string {
            root.popupRequested("open")
            return "accepted"
        }
    }

    Component.onCompleted: refresh()
}
