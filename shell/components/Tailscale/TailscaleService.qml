pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import "../.."
import "TailscaleModel.js" as Model

// One serialized control plane shared by every monitor. Reads use the
// unprivileged Tailscale CLI; mutations use Tailscale operator mode.
Singleton {
    id: root

    property bool initialized: false
    property bool installed: false
    property bool running: false
    property bool needsLogin: false
    property bool refreshing: false
    property string backendState: "Unknown"
    property string authUrl: ""
    property string selfName: ""
    property string selfDnsName: ""
    property string selfIp: ""
    property string selfUserId: ""
    property bool fileSharing: false
    property var peers: []
    property var tailnetExitNodes: []
    property var mullvadNodes: []
    property var mullvadRegions: []
    property int onlineCount: 0
    property string activeMullvadExit: ""
    property var health: []
    property var acknowledgedHealth: []
    property bool prefsAvailable: false
    property bool acceptRoutes: false
    property bool acceptDns: true
    property bool shieldsUp: false
    property bool allowLanAccess: false
    property bool advertiseExitNode: false
    property bool runSsh: false
    property string suggestedExitNode: ""
    property var accounts: []
    property string selectedAccountId: ""
    property string selectedAccountLabel: ""
    property bool operatorRequired: false
    property string error: ""
    property string status: ""
    property string _statusOutput: ""
    property string _statusError: ""
    property string _prefsOutput: ""
    property string _exitListOutput: ""
    property string _accountsOutput: ""
    property string _accountsError: ""
    property string _suggestOutput: ""
    property string _actionOutput: ""
    property string _actionError: ""
    property string _actionKind: ""
    property string _loginOutput: ""
    property string _loginError: ""
    property bool _loginOpened: false
    property string _operatorUser: ""
    property string tailscaleExecutable: ""
    property var pendingFiles: []
    property var _knownPendingFiles: []
    property string _taildropOutput: ""
    property string _taildropError: ""
    readonly property string taildropHelper:
        Theme.scriptsDir + "/tailscale/taildrop-inbox"
    readonly property string taildropInbox:
        ShellState.stateDir + "/taildrop/inbox"
    readonly property string downloadsDirectory:
        String(Quickshell.env("HOME") || "") + "/Downloads"
    readonly property bool taildropBusy:
        taildropPollProcess.running || taildropActionProcess.running

    readonly property bool busy: actionProcess.running || loginProcess.running
    readonly property bool active: running
    readonly property var visibleHealth: health.filter(warning =>
        acknowledgedHealth.indexOf(warning) < 0)
    readonly property string currentExitNode: {
        for (const item of peers)
            if (item.ExitNode === true) return item.HostName
        return activeMullvadExit
    }

    function initialize() {
        if (initialized) return
        initialized = true
        loadState()
        refresh()
        refreshTimer.start()
        refreshTaildrop(false)
    }

    function loadState() {
        const saved = ShellState.state.tailscale?.acknowledgedHealth
        acknowledgedHealth = Array.isArray(saved) ? saved : []
    }

    function acknowledgeHealth(warning) {
        if (acknowledgedHealth.indexOf(warning) >= 0) return
        acknowledgedHealth = acknowledgedHealth.concat([warning])
        ShellState.updateSection("tailscale", {
            acknowledgedHealth: acknowledgedHealth
        })
    }

    function restoreHealthWarnings() {
        acknowledgedHealth = []
        ShellState.updateSection("tailscale", { acknowledgedHealth: [] })
    }

    function refreshTaildrop(fetchRemote) {
        if (taildropPollProcess.running || taildropActionProcess.running)
            return
        _taildropOutput = ""
        _taildropError = ""
        taildropPollProcess.command = fetchRemote === true
            && installed && running && tailscaleExecutable !== ""
            ? [taildropHelper, "poll", taildropInbox, tailscaleExecutable]
            : [taildropHelper, "list", taildropInbox]
        taildropPollProcess.running = true
    }

    function applyPendingFiles(text, notifyNew) {
        let next
        try {
            next = JSON.parse(String(text || "[]"))
        } catch (parseError) {
            return
        }
        if (!Array.isArray(next)) return
        const known = _knownPendingFiles
        if (notifyNew) {
            for (const item of next) {
                const name = String(item.name || "")
                if (name !== "" && known.indexOf(name) < 0) {
                    Quickshell.execDetached(["notify-send", "--app-name=anush",
                        "Taildrop file waiting",
                        name + " — open Tailscale to receive or reject it"])
                }
            }
        }
        pendingFiles = next
        _knownPendingFiles = next.map(item => String(item.name || ""))
    }

    function acceptTaildrop(name) {
        runTaildropAction("accept", name)
    }

    function rejectTaildrop(name) {
        runTaildropAction("reject", name)
    }

    function runTaildropAction(action, name) {
        if (taildropBusy || String(name || "") === "") return
        _taildropOutput = ""
        _taildropError = ""
        taildropActionProcess.action = action
        taildropActionProcess.fileName = String(name)
        taildropActionProcess.command = action === "accept"
            ? [taildropHelper, "accept", taildropInbox, downloadsDirectory,
                String(name)]
            : [taildropHelper, "reject", taildropInbox, String(name)]
        taildropActionProcess.running = true
    }

    function refresh() {
        if (whichProcess.running || statusProcess.running) return
        if (!installed) {
            refreshing = true
            whichProcess.command = ["which", "tailscale"]
            whichProcess.running = true
            return
        }
        refreshDetails()
    }

    function refreshDetails() {
        if (!installed || statusProcess.running) return
        refreshing = true
        _statusOutput = ""
        _statusError = ""
        statusProcess.command = ["tailscale", "status", "--json"]
        statusProcess.running = true
        if (!prefsProcess.running) {
            _prefsOutput = ""
            prefsProcess.command = ["tailscale", "debug", "prefs"]
            prefsProcess.running = true
        }
        if (!exitListProcess.running) {
            _exitListOutput = ""
            exitListProcess.command = ["tailscale", "exit-node", "list"]
            exitListProcess.running = true
        }
        if (!accountsProcess.running) {
            _accountsOutput = ""
            _accountsError = ""
            accountsProcess.command = ["tailscale", "switch", "--list", "--json"]
            accountsProcess.running = true
        }
        watchdog.restart()
    }

    function applyStatus(text) {
        const result = Model.parseStatus(text)
        if (!result.ok) {
            running = false
            peers = []
            tailnetExitNodes = []
            error = result.message
            return
        }
        backendState = result.backendState
        running = result.running
        needsLogin = result.needsLogin
        authUrl = result.authUrl
        selfName = result.selfName
        selfDnsName = result.selfDnsName
        selfIp = result.selfIp
        selfUserId = result.selfUserId
        fileSharing = result.fileSharing
        peers = result.running ? result.peers : []
        tailnetExitNodes = result.running ? result.exitNodes : []
        activeMullvadExit = result.activeMullvadExit
        onlineCount = result.onlineCount
        health = result.health
        error = ""
    }

    function toggle() {
        if (!installed || busy) return
        if (running) runAction("down", ["tailscale", "down"], "Disconnecting…")
        else login()
    }

    function login() {
        if (!installed || loginProcess.running) return
        if (needsLogin && /^https?:\/\//.test(authUrl)) {
            Quickshell.execDetached(["xdg-open", authUrl])
            return
        }
        _loginOutput = ""
        _loginError = ""
        _loginOpened = false
        status = needsLogin ? "Starting browser login…" : "Connecting…"
        loginProcess.command = ["tailscale", "up"]
        loginProcess.running = true
    }

    function loginNewAccount() {
        if (!installed || loginProcess.running) return
        _loginOutput = ""
        _loginError = ""
        _loginOpened = false
        status = "Starting login for another account…"
        loginProcess.command = ["tailscale", "login"]
        loginProcess.running = true
    }

    function runAction(kind, command, label) {
        if (busy) return false
        _actionKind = kind
        _actionOutput = ""
        _actionError = ""
        error = ""
        status = label
        actionProcess.command = command
        actionProcess.running = true
        return true
    }

    function setPreference(flag, enabled) {
        const values = ({
            "--accept-routes": "acceptRoutes",
            "--accept-dns": "acceptDns",
            "--shields-up": "shieldsUp",
            "--exit-node-allow-lan-access": "allowLanAccess",
            "--advertise-exit-node": "advertiseExitNode",
            "--ssh": "runSsh"
        })
        if (!values[flag]) return
        root[values[flag]] = enabled
        runAction("preference", ["tailscale", "set",
            flag + "=" + (enabled ? "true" : "false")], "Updating preference…")
    }

    function setExitNode(item) {
        if (!item || !running) return
        if (item.ExitNode === true) {
            clearExitNode()
            return
        }
        const ips = item.TailscaleIPs || []
        const target = item.Mullvad === true && ips.length
            ? ips[0] : String(item.DNSName || item.HostName || "")
        if (target !== "") runAction("exit-node", ["tailscale", "set",
            "--exit-node=" + target], "Selecting exit node…")
    }

    function setExitNodeByName(name) {
        const target = String(name || "")
        if (target === "") clearExitNode()
        else runAction("exit-node", ["tailscale", "set",
            "--exit-node=" + target], "Selecting exit node…")
    }

    function clearExitNode() {
        runAction("exit-node", ["tailscale", "set", "--exit-node="],
            "Using a direct connection…")
    }

    function refreshSuggestion() {
        if (!running || suggestProcess.running) return
        _suggestOutput = ""
        suggestProcess.command = ["tailscale", "exit-node", "suggest"]
        suggestProcess.running = true
    }

    function switchAccount(id) {
        id = String(id || "")
        if (id !== "" && id !== selectedAccountId)
            runAction("account", ["tailscale", "switch", id],
                "Switching account…")
    }

    function authorizeOperator() {
        if (busy) return
        if (tailscaleExecutable === "") {
            error = "Could not resolve the Tailscale executable."
            return
        }
        if (_operatorUser === "") {
            userProcess.command = ["/usr/bin/id", "-un"]
            userProcess.running = true
            return
        }
        runAction("operator", ["/usr/bin/pkexec", tailscaleExecutable, "set",
            "--operator=" + _operatorUser], "Authorizing Tailscale…")
    }

    function copy(value) {
        const text = String(value || "")
        if (text !== "") Quickshell.clipboardText = text
    }

    function address(peer) {
        if (!peer) return ""
        if (peer.DNSName) return peer.DNSName
        return peer.TailscaleIPs && peer.TailscaleIPs.length
            ? peer.TailscaleIPs[0] : peer.HostName
    }

    function canSend(peer) {
        return running && fileSharing && peer && peer.Online
            && Model.canTaildrop(peer, selfUserId)
    }

    function sendFile(peer, url) {
        if (!canSend(peer)) return
        const path = decodeURIComponent(String(url || "").replace(/^file:\/\//, ""))
        const target = address(peer)
        if (path !== "" && target !== "")
            runAction("taildrop", ["tailscale", "file", "cp", path,
                target + ":"], "Sending file to " + peer.HostName + "…")
    }

    function ssh(peer) {
        if (!peer || !peer.Online) return
        const host = String(peer.HostName || "")
        if (!/^[A-Za-z0-9][A-Za-z0-9.-]{0,252}$/.test(host)) return
        const launcher =
            "host=$1; title=\"Tailscale SSH — $host\"; "
            + "config=${ANUSH_CONFIG_DIR:-${XDG_CONFIG_HOME:-$HOME/.config}/skarwm/anush}; "
            + "terminal=${TERMINAL:-}; "
            + "if [ -n \"$terminal\" ] && command -v \"$terminal\" >/dev/null 2>&1; then "
            + "case ${terminal##*/} in "
            + "kitty) exec \"$terminal\" --config \"$config/kitty/kitty.conf\" --title \"$title\" -- tailscale ssh \"$host\" ;; "
            + "foot) exec \"$terminal\" --title=\"$title\" -- tailscale ssh \"$host\" ;; "
            + "alacritty) exec \"$terminal\" -T \"$title\" -e tailscale ssh \"$host\" ;; "
            + "wezterm) exec \"$terminal\" start -- tailscale ssh \"$host\" ;; "
            + "st) exec \"$terminal\" -t \"$title\" -e tailscale ssh \"$host\" ;; "
            + "xterm) exec \"$terminal\" -T \"$title\" -e tailscale ssh \"$host\" ;; "
            + "*) exec \"$terminal\" -e tailscale ssh \"$host\" ;; esac; "
            + "elif command -v kitty >/dev/null 2>&1; then "
            + "exec kitty --config \"$config/kitty/kitty.conf\" --title \"$title\" -- tailscale ssh \"$host\"; "
            + "elif command -v st >/dev/null 2>&1; then "
            + "exec st -t \"$title\" -e tailscale ssh \"$host\"; "
            + "elif command -v xterm >/dev/null 2>&1; then "
            + "exec xterm -T \"$title\" -e tailscale ssh \"$host\"; "
            + "else notify-send --app-name=anush \"Tailscale SSH\" \"No terminal emulator was found\"; fi"
        Quickshell.execDetached(["sh", "-c", launcher,
            "anush-tailscale-ssh", host])
    }

    function openAdmin() {
        Quickshell.execDetached(["xdg-open", "https://login.tailscale.com/admin/machines"])
    }

    function filteredPeers(query, online) {
        return Model.filterPeers(peers, query).filter(item => item.Online === online)
    }

    function fmtBytes(value) { return Model.fmtBytes(value) }
    function fmtLastSeen(value) { return Model.fmtLastSeen(value) }
    function osIcon(value) { return Model.osIcon(value) }

    Timer {
        id: refreshTimer
        interval: 30000
        repeat: true
        onTriggered: root.refresh()
    }
    Timer {
        id: taildropTimer
        interval: 8000
        repeat: true
        triggeredOnStart: true
        running: root.initialized && root.installed && root.running
            && root.fileSharing
        onTriggered: root.refreshTaildrop(true)
    }
    Timer {
        id: delayedRefresh
        interval: 700
        onTriggered: root.refreshDetails()
    }
    Timer {
        id: clearStatus
        interval: 2800
        onTriggered: root.status = ""
    }
    Timer {
        id: watchdog
        interval: 15000
        onTriggered: {
            if (statusProcess.running) statusProcess.running = false
            if (prefsProcess.running) prefsProcess.running = false
            if (exitListProcess.running) exitListProcess.running = false
            if (accountsProcess.running) accountsProcess.running = false
            root.refreshing = false
        }
    }

    Process {
        id: whichProcess
        command: []
        stdout: StdioCollector {
            onStreamFinished: {
                const value = text.trim()
                root.tailscaleExecutable = /^\/[A-Za-z0-9_./+-]+$/.test(value)
                    ? value : ""
            }
        }
        onExited: exitCode => {
            root.installed = exitCode === 0 && root.tailscaleExecutable !== ""
            root.refreshing = false
            if (root.installed) root.refreshDetails()
            else {
                root.running = false
                root.error = "Tailscale is not installed."
            }
        }
    }
    Process {
        id: statusProcess
        command: []
        stdout: StdioCollector { onStreamFinished: root._statusOutput = text }
        stderr: StdioCollector { onStreamFinished: root._statusError = text }
        onExited: exitCode => {
            root.refreshing = false
            if (exitCode === 0) root.applyStatus(root._statusOutput)
            else {
                root.running = false
                root.backendState = "Unavailable"
                root.error = String(root._statusError).trim() || "Tailscale is unavailable."
            }
        }
    }
    Process {
        id: prefsProcess
        command: []
        stdout: StdioCollector { onStreamFinished: root._prefsOutput = text }
        onExited: exitCode => {
            if (exitCode !== 0) return
            const result = Model.parsePrefs(root._prefsOutput)
            if (!result.ok) return
            root.prefsAvailable = true
            root.acceptRoutes = result.routeAll
            root.acceptDns = result.corpDns
            root.shieldsUp = result.shieldsUp
            root.allowLanAccess = result.allowLanAccess
            root.advertiseExitNode = result.advertiseExitNode
            root.runSsh = result.runSsh
        }
    }
    Process {
        id: exitListProcess
        command: []
        stdout: StdioCollector { onStreamFinished: root._exitListOutput = text }
        onExited: exitCode => {
            root.mullvadNodes = exitCode === 0
                ? Model.parseExitNodes(root._exitListOutput) : []
            root.mullvadRegions = Model.mullvadRegions(root.mullvadNodes)
        }
    }
    Process {
        id: accountsProcess
        command: []
        stdout: StdioCollector { onStreamFinished: root._accountsOutput = text }
        stderr: StdioCollector { onStreamFinished: root._accountsError = text }
        onExited: exitCode => {
            const combined = root._accountsOutput + "\n" + root._accountsError
            root.operatorRequired = exitCode !== 0 && /access denied/i.test(combined)
            const result = Model.parseAccounts(root._accountsOutput)
            root.accounts = result.accounts
            root.selectedAccountId = result.selectedAccountId
            root.selectedAccountLabel = result.selectedAccountLabel
        }
    }
    Process {
        id: suggestProcess
        command: []
        stdout: StdioCollector { onStreamFinished: root._suggestOutput = text }
        onExited: exitCode => root.suggestedExitNode = exitCode === 0
            ? Model.parseSuggest(root._suggestOutput) : ""
    }
    Process {
        id: loginProcess
        command: []
        stdout: SplitParser {
            onRead: data => {
                root._loginOutput += data + "\n"
                const match = String(data).match(/https?:\/\/\S+/)
                if (match && !root._loginOpened) {
                    root._loginOpened = true
                    Quickshell.execDetached(["xdg-open", match[0]])
                }
            }
        }
        stderr: SplitParser {
            onRead: data => {
                root._loginError += data + "\n"
                const match = String(data).match(/https?:\/\/\S+/)
                if (match && !root._loginOpened) {
                    root._loginOpened = true
                    Quickshell.execDetached(["xdg-open", match[0]])
                }
            }
        }
        onExited: exitCode => {
            if (exitCode !== 0)
                root.error = (root._loginError || root._loginOutput).trim()
            root.status = ""
            delayedRefresh.restart()
        }
    }
    Process {
        id: actionProcess
        command: []
        stdout: StdioCollector { onStreamFinished: root._actionOutput = text }
        stderr: StdioCollector { onStreamFinished: root._actionError = text }
        onExited: exitCode => {
            const combined = (root._actionError || root._actionOutput).trim()
            if (exitCode !== 0) {
                root.error = combined || "Tailscale action failed."
                if (/access denied/i.test(combined)) root.operatorRequired = true
            } else {
                root.error = ""
                if (root._actionKind === "operator") {
                    root.operatorRequired = false
                    root.status = "Tailscale operator authorized"
                    clearStatus.restart()
                } else {
                    root.status = ""
                }
            }
            root._actionKind = ""
            delayedRefresh.restart()
        }
    }
    Process {
        id: userProcess
        command: []
        stdout: StdioCollector {
            onStreamFinished: {
                const value = text.trim()
                if (/^[a-z_][a-z0-9_-]{0,31}$/.test(value))
                    root._operatorUser = value
            }
        }
        onExited: exitCode => {
            if (exitCode === 0 && root._operatorUser !== "")
                Qt.callLater(() => root.authorizeOperator())
            else root.error = "Could not identify the current user."
        }
    }

    Process {
        id: taildropPollProcess
        command: []
        stdout: StdioCollector {
            onStreamFinished: root._taildropOutput = text
        }
        stderr: StdioCollector {
            onStreamFinished: root._taildropError = text
        }
        onExited: exitCode => {
            if (exitCode === 0)
                root.applyPendingFiles(root._taildropOutput, true)
            else if (root.pendingFiles.length === 0
                    && root._taildropError.trim() !== "")
                console.warn(root._taildropError.trim())
        }
    }

    Process {
        id: taildropActionProcess
        property string action: ""
        property string fileName: ""
        command: []
        stdout: StdioCollector {
            onStreamFinished: root._taildropOutput = text
        }
        stderr: StdioCollector {
            onStreamFinished: root._taildropError = text
        }
        onExited: exitCode => {
            if (exitCode === 0) {
                root.error = ""
                root.status = action === "accept"
                    ? "Taildrop file saved to Downloads"
                    : "Taildrop file rejected"
                clearStatus.restart()
            } else {
                root.error = root._taildropError.trim()
                    || "Could not update the Taildrop inbox."
            }
            action = ""
            fileName = ""
            Qt.callLater(() => root.refreshTaildrop(false))
        }
    }

    Connections {
        target: ShellState
        function onReadyChanged() { if (ShellState.ready) root.loadState() }
    }
}
