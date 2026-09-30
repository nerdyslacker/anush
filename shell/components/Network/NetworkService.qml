pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Networking as QsNetwork
import "../.."

// Reactive NetworkManager state comes from Quickshell's native networking
// backend. Actions preserve the shell's established nmcli behaviour, while
// `nmcli monitor` invalidates saved-profile/VPN snapshots without polling.
Singleton {
    id: root

    readonly property bool widgetEnabled: BarVisibility.enabled("network")

    // Shared invalidation stream for every NetworkManager-backed service.
    // Keeping this here avoids one persistent `nmcli monitor` per consumer.
    signal networkStateInvalidated()

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

    property var nmVpns: []
    property var openvpn3Vpns: []
    readonly property var vpns: nmVpns.concat(openvpn3Vpns)
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
    property string _openvpn3Configs: ""
    property string _openvpn3Sessions: ""
    property string _openvpn3StartingPath: ""
    property string _openvpn3StartError: ""
    property string _vpnMetadata: ""
    signal vpnProfileCreated()

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
        // Metadata enrichment is optional and must never block the primary
        // NetworkManager profile refresh or its loading indicator.
        if (!widgetEnabled || vpnList.running)
            return
        if (vpnMetadata.running)
            vpnMetadata.running = false
        loadingVpns = true
        vpnLoadingTimeout.restart()
        vpnList.running = true
        refreshOpenvpn3()
    }

    function toggleVpn(vpn) {
        if (!vpn || busy)
            return
        if (vpn.engine === "fortivpn") {
            startFortiVpn(vpn)
            return
        }
        if (vpn.engine === "openvpn3") {
            if (vpn.active) {
                runAction(["openvpn3", "session-manage", "--session-path",
                    vpn.sessionPath, "--disconnect"], "Disconnecting "
                    + vpn.name + "…")
            } else {
                startOpenvpn3(vpn.configPath)
            }
            return
        }
        if (vpn.external)
            return
        if (vpn.active) {
            runAction(["nmcli", "connection", "down", "uuid", vpn.uuid],
                "Disconnecting " + vpn.name + "…")
        } else {
            startNmVpn(vpn.uuid, vpn.name)
        }
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

    function createVpn(details) {
        if (busy)
            return
        error = ""
        status = details.uuid ? "Updating VPN profile…" : "Adding VPN profile…"
        busy = true
        profileCreate.updating = Boolean(details.uuid)
        profileCreate.payload = JSON.stringify(details)
        profileCreate.running = true
    }

    function importVpn(kind, fileUrl, name) {
        if (busy)
            return
        const path = decodeURIComponent(String(fileUrl).replace(/^file:\/\//, ""))
        if (path === "") {
            error = "Choose a VPN configuration file"
            return
        }
        error = ""
        status = "Importing VPN profile…"
        busy = true
        if (kind === "openvpn3") {
            const command = ["openvpn3", "config-import", "--config", path]
            if (String(name || "").trim() !== "")
                command.push("--name", String(name).trim())
            importAction.command = command
            importAction.running = true
        } else {
            openvpnImport.payload = JSON.stringify({ path: path,
                name: String(name || "").trim() })
            openvpnImport.running = true
        }
    }

    function editVpnExternally(uuid) {
        if (!/^[A-Fa-f0-9-]{36}$/.test(uuid)) {
            error = "Invalid NetworkManager VPN profile"
            return
        }
        openInTerminal(["nmcli", "connection", "edit", "uuid", uuid])
        status = "VPN profile editor opened in a terminal…"
        clearStatus.restart()
    }

    function removeVpn(vpn) {
        if (!vpn || busy || vpn.active || vpn.external)
            return
        if (vpn.engine === "openvpn3") {
            if (!/^\/net\/openvpn\/v3\/configuration\/[A-Za-z0-9_-]+$/.test(vpn.configPath)) {
                error = "Invalid OpenVPN 3 profile"
                return
            }
            runAction(["openvpn3", "config-remove", "--path",
                vpn.configPath, "--force"], "Removing " + vpn.name + "…")
        } else if (/^[A-Fa-f0-9-]{36}$/.test(vpn.uuid || "")) {
            runAction(["nmcli", "connection", "delete", "uuid", vpn.uuid],
                "Removing " + vpn.name + "…")
        } else {
            error = "Invalid NetworkManager VPN profile"
        }
    }

    function refreshOpenvpn3() {
        if (widgetEnabled && !openvpn3Configs.running
                && !openvpn3Sessions.running) {
            _openvpn3Configs = ""
            _openvpn3Sessions = ""
            openvpn3Configs.running = true
        }
    }

    function applyOpenvpn3() {
        let configs
        try {
            configs = JSON.parse(_openvpn3Configs || "{}")
        } catch (e) {
            openvpn3Vpns = []
            return
        }
        const sessions = []
        const blocks = _openvpn3Sessions.split(/-{20,}/)
        for (const block of blocks) {
            const pathMatch = block.match(/Path:\s*(\/net\/openvpn\/v3\/sessions\/[A-Za-z0-9_-]+)/)
            const nameMatch = block.match(/Config name:\s*([^\n\r]+)/)
            const stateMatch = block.match(/Status:\s*([^\n\r]+)/)
            if (pathMatch && nameMatch)
                sessions.push({ path: pathMatch[1], name: nameMatch[1].trim(),
                    active: !stateMatch || stateMatch[1].toLowerCase().indexOf("disconnect") < 0 })
        }
        const rows = []
        for (const path of Object.keys(configs)) {
            if (!/^\/net\/openvpn\/v3\/configuration\/[A-Za-z0-9_-]+$/.test(path))
                continue
            const name = String(configs[path]?.name ?? "OpenVPN 3").trim()
            const session = sessions.find(item => item.name === name)
            rows.push({ name: name, active: session !== undefined,
                external: false, device: "", engine: "openvpn3",
                configPath: path, sessionPath: session ? session.path : "" })
        }
        openvpn3Vpns = rows
        if (_openvpn3StartingPath !== "") {
            const connected = rows.some(vpn => vpn.configPath
                === _openvpn3StartingPath && vpn.active)
            if (connected) {
                _openvpn3StartingPath = ""
                status = "Network updated"
                openvpn3StartProcess.connected = true
                if (openvpn3StartProcess.running)
                    openvpn3StartProcess.running = false
                openvpn3RefreshTimer.stop()
                clearStatus.restart()
            }
        }
    }

    function startOpenvpn3(configPath) {
        if (!/^\/net\/openvpn\/v3\/configuration\/[A-Za-z0-9_-]+$/.test(configPath)) {
            error = "Invalid OpenVPN 3 profile"
            return
        }
        if (_openvpn3StartingPath === configPath)
            return
        error = ""
        status = "Connecting OpenVPN 3…"
        _openvpn3StartingPath = configPath
        _openvpn3StartError = ""
        // This CLI can remain attached after the daemon connects. A dedicated
        // process keeps it out of the global action queue; the poll below stops
        // the client once the independently managed D-Bus session appears.
        openvpn3StartProcess.connected = false
        openvpn3StartProcess.command = ["openvpn3", "session-start",
            "--config-path", configPath]
        openvpn3StartProcess.running = true
        openvpn3RefreshTimer.restart()
    }

    function startNmVpn(uuid, name) {
        if (!/^[A-Fa-f0-9-]{36}$/.test(uuid)) {
            error = "Invalid NetworkManager VPN profile"
            return
        }
        openInTerminal(["nmcli", "--ask", "connection", "up", "uuid", uuid])
        status = "Connecting " + name + " in a terminal…"
        clearStatus.restart()
    }

    function startFortiVpn(vpn) {
        const target = String(vpn.gateway || "")
            .replace(/^https?:\/\//, "").replace(/\/$/, "")
        const port = String(vpn.samlPort || "8020")
        if (!/^[A-Za-z0-9._:[\]-]+$/.test(target)
                || !/^\d{1,5}$/.test(port) || Number(port) < 1
                || Number(port) > 65535) {
            error = "Invalid FortiVPN SAML gateway or callback port"
            return
        }
        const fortiSession = vpn.saml
            ? "target=$1; port=$2; cert=$3; key=$4; sudo -v || exit $?; "
            + "if [ -n \"$cert\" ] || [ -n \"$key\" ]; then "
            + "sudo -n openfortivpn \"$target\" \"--saml-login=$port\" "
            + "\"--user-cert=$cert\" \"--user-key=$key\" & "
            + "else sudo -n openfortivpn \"$target\" \"--saml-login=$port\" & fi; "
            + "vpn_pid=$!; trap 'sudo kill $vpn_pid 2>/dev/null' EXIT HUP INT TERM; "
            + "sleep 1; xdg-open \"https://$target/remote/saml/start?redirect=1\" "
            + ">/dev/null 2>&1 & wait $vpn_pid"
            : "target=$1; username=$2; cert=$3; key=$4; sudo -v || exit $?; "
            + "if [ -n \"$cert\" ] || [ -n \"$key\" ]; then "
            + "sudo -n openfortivpn \"$target\" \"--username=$username\" "
            + "\"--user-cert=$cert\" \"--user-key=$key\"; "
            + "else sudo -n openfortivpn \"$target\" \"--username=$username\"; fi"
        openInTerminal(["sh", "-c", fortiSession,
            vpn.saml ? "anush-forti-saml" : "anush-forti-vpn",
            target, vpn.saml ? port : (vpn.username || ""),
            vpn.clientCert || "", vpn.privateKey || ""])
        status = vpn.saml ? "FortiVPN browser sign-in opened in a terminal…"
            : "FortiVPN authentication opened in a terminal…"
        clearStatus.restart()
    }

    function applyVpnMetadata() {
        let metadata = []
        try {
            metadata = JSON.parse(_vpnMetadata || "[]")
        } catch (e) {
            metadata = []
        }
        nmVpns = _vpnBuffer.map(vpn => {
            const details = metadata.find(item => item.uuid === vpn.uuid)
            if (!details) return vpn
            return Object.assign({}, vpn, details, {
                engine: details.kind === "fortisslvpn"
                    ? "fortivpn" : "networkmanager"
            })
        })
    }

    function openInTerminal(argv) {
        const launcher =
            "config=${ANUSH_CONFIG_DIR:-${XDG_CONFIG_HOME:-$HOME/.config}/skarwm/anush}; "
            + "if [ -n \"${TERMINAL:-}\" ] && command -v \"$TERMINAL\" >/dev/null 2>&1; then "
            + "if [ \"${TERMINAL##*/}\" = kitty ]; then exec \"$TERMINAL\" --config \"$config/kitty/kitty.conf\" -- \"$@\"; "
            + "else exec \"$TERMINAL\" -e \"$@\"; fi; "
            + "elif command -v kitty >/dev/null 2>&1; then exec kitty --config \"$config/kitty/kitty.conf\" -- \"$@\"; "
            + "elif command -v foot >/dev/null 2>&1; then exec foot -- \"$@\"; "
            + "elif command -v alacritty >/dev/null 2>&1; then exec alacritty -e \"$@\"; "
            + "elif command -v wezterm >/dev/null 2>&1; then exec wezterm start -- \"$@\"; "
            + "elif command -v xterm >/dev/null 2>&1; then exec xterm -e \"$@\"; fi"
        const session =
            "\"$@\"; status=$?; if [ \"$status\" -ne 0 ]; then "
            + "printf '\\nVPN command exited with status %s. Press Enter to close.\\n' \"$status\"; "
            + "read answer; fi; exit \"$status\""
        Quickshell.execDetached(["sh", "-c", launcher, "anush-vpn-terminal",
            "sh", "-c", session, "anush-vpn"].concat(argv))
    }

    Process {
        id: vpnList
        // Put the human-controlled name last. Older nmcli releases do not
        // support --separator, so only split the four safe fields before it.
        command: ["nmcli", "-t", "-f", "TYPE,ACTIVE,DEVICE,UUID,NAME",
            "connection", "show"]
        stdout: SplitParser {
            onRead: line => {
                const first = line.indexOf(":")
                const second = line.indexOf(":", first + 1)
                const third = line.indexOf(":", second + 1)
                const fourth = line.indexOf(":", third + 1)
                if (first < 0 || second < 0 || third < 0 || fourth < 0)
                    return
                const type = line.slice(0, first)
                const name = root.unescapeNm(line.slice(fourth + 1))
                if (type.indexOf("wireless") !== -1)
                    root._wifiBuffer.push(name)
                else if (type === "vpn" || type === "wireguard" || type === "tun")
                    root._vpnBuffer.push({
                        name: name, type: type,
                        uuid: line.slice(third + 1, fourth),
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
            root.loadingVpns = false
            vpnLoadingTimeout.stop()
            root.savedWifi = root._wifiBuffer
            root.vpnError = code === 0 ? "" : (root._vpnErrors.length
                ? root._vpnErrors[root._vpnErrors.length - 1]
                : "VPN profiles are unavailable")
            root.nmVpns = root._vpnBuffer
            root._vpnMetadata = ""
            vpnMetadata.running = true
        }
    }

    Process {
        id: vpnMetadata
        command: ["python3", ShellState.scriptsDir
            + "/network/vpn-profile-helper", "metadata"]
        stdout: StdioCollector {
            waitForEnd: true
            onStreamFinished: root._vpnMetadata = text
        }
        onExited: code => root.applyVpnMetadata()
    }

    Process {
        id: profileCreate
        property string payload: ""
        property bool updating: false
        command: ["python3", ShellState.scriptsDir
            + "/network/vpn-profile-helper"]
        stdinEnabled: true
        stderr: StdioCollector { id: profileCreateError; waitForEnd: true }
        onStarted: {
            write(payload)
            payload = ""
            stdinEnabled = false
        }
        onExited: code => {
            stdinEnabled = true
            root.busy = false
            root.status = code === 0
                ? (updating ? "VPN profile updated" : "VPN profile added") : ""
            root.error = code === 0 ? "" : (profileCreateError.text.trim()
                || (updating ? "Could not update VPN profile"
                    : "Could not add VPN profile"))
            if (code === 0) root.vpnProfileCreated()
            root.refreshVpns()
            clearStatus.restart()
        }
    }

    Process {
        id: importAction
        stderr: StdioCollector { id: importError; waitForEnd: true }
        onExited: code => {
            root.busy = false
            root.status = code === 0 ? "VPN profile imported" : ""
            root.error = code === 0 ? "" : (importError.text.trim()
                || "Could not import VPN profile")
            if (code === 0) root.vpnProfileCreated()
            root.refreshVpns()
            clearStatus.restart()
        }
    }

    Process {
        id: openvpnImport
        property string payload: ""
        command: ["python3", ShellState.scriptsDir
            + "/network/vpn-profile-helper", "import-openvpn"]
        stdinEnabled: true
        stderr: StdioCollector { id: openvpnImportError; waitForEnd: true }
        onStarted: {
            write(payload)
            payload = ""
            stdinEnabled = false
        }
        onExited: code => {
            stdinEnabled = true
            root.busy = false
            root.status = code === 0 ? "VPN profile imported" : ""
            root.error = code === 0 ? "" : (openvpnImportError.text.trim()
                || "Could not import VPN profile")
            if (code === 0) root.vpnProfileCreated()
            root.refreshVpns()
            clearStatus.restart()
        }
    }

    Process {
        id: openvpn3Configs
        command: ["openvpn3", "configs-list", "--json"]
        stdout: StdioCollector {
            waitForEnd: true
            onStreamFinished: root._openvpn3Configs = text
        }
        onExited: code => {
            if (code !== 0) {
                root.openvpn3Vpns = []
                return
            }
            openvpn3Sessions.running = true
        }
    }

    Process {
        id: openvpn3Sessions
        command: ["openvpn3", "sessions-list"]
        stdout: StdioCollector {
            waitForEnd: true
            onStreamFinished: root._openvpn3Sessions = text
        }
        onExited: code => root.applyOpenvpn3()
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

    Process {
        id: openvpn3StartProcess
        property bool connected: false
        command: []
        stderr: SplitParser {
            onRead: line => {
                const value = line.trim()
                if (value !== "") root._openvpn3StartError = value
            }
        }
        onExited: code => {
            if (connected) {
                connected = false
                root.error = ""
                return
            }
            if (code !== 0 && root._openvpn3StartingPath !== "") {
                root._openvpn3StartingPath = ""
                root.status = ""
                root.error = root._openvpn3StartError
                    || "OpenVPN 3 could not start the session"
                openvpn3RefreshTimer.stop()
            }
        }
    }

    Timer {
        id: clearStatus
        interval: 3500
        onTriggered: root.status = ""
    }

    Timer {
        id: vpnLoadingTimeout
        interval: 8000
        repeat: false
        onTriggered: {
            if (!root.loadingVpns)
                return
            root.loadingVpns = false
            if (root.nmVpns.length === 0)
                root.vpnError = "VPN profile refresh timed out"
            if (vpnList.running)
                vpnList.running = false
        }
    }

    Timer {
        id: openvpn3RefreshTimer
        property int ticks: 0
        interval: 2000
        repeat: true
        onTriggered: {
            ticks += 1
            root.refreshOpenvpn3()
            if (ticks >= 15) {
                if (openvpn3StartProcess.running)
                    openvpn3StartProcess.running = false
                root._openvpn3StartingPath = ""
                root.status = ""
                if (root.error === "")
                    root.error = "OpenVPN 3 connection timed out"
                stop()
            }
        }
        onRunningChanged: if (running) ticks = 0
    }

    // Event-driven invalidation rather than a refresh timer. This also catches
    // NetworkManager restarts; if the monitor exits, retry at a low cadence.
    Process {
        id: nmMonitor
        running: root.widgetEnabled && !monitorRestart.running
        command: ["nmcli", "monitor"]
        stdout: SplitParser {
            onRead: line => {
                root.networkStateInvalidated()
                vpnRefreshDebounce.restart()
            }
        }
        onExited: if (root.widgetEnabled) monitorRestart.restart()
    }

    Timer {
        id: vpnRefreshDebounce
        interval: 250
        onTriggered: root.refreshVpns()
    }

    Timer {
        id: monitorRestart
        interval: 3000
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

    Component.onCompleted: if (widgetEnabled) refreshVpns()
}
