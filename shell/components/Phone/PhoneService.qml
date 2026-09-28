pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import "../.."

// KDE Connect and Valent expose different D-Bus models. The helper normalizes
// both into one bounded JSON snapshot while this singleton owns polling and
// serializes actions for every bar instance.
Singleton {
    id: root

    property bool initialized: false
    property bool running: false
    property string backend: ""
    property var installedBackends: ({ kdeconnect: false, valent: false })
    property var devices: []
    property string error: ""
    property string status: ""
    property string _statusOutput: ""
    property string _actionOutput: ""
    property string _actionLabel: ""
    property string _replyOutput: ""
    property string _replyPayload: ""
    property string _replyDevice: ""
    property string _dataOutput: ""
    property string _dataKind: ""
    property string _discoveryOutput: ""
    property bool discoveryLoaded: false
    property var customAddresses: []
    property var tailscalePeers: []
    property bool tailscaleInstalled: false
    property bool tailscaleRunning: false
    property string localLanAddress: ""
    property string localTailscaleAddress: ""
    property string smsDeviceId: ""
    property string _afterSmsKind: ""
    property string _afterSmsDevice: ""
    property string _afterSmsThread: ""
    property string _afterNotificationDevice: ""
    property var conversations: []
    property var messages: []
    property var contacts: []
    property var notifications: []
    property string notificationDeviceId: ""

    readonly property string helperPath:
        Theme.scriptsDir + "/phone/phone-control"
    readonly property bool installed: installedBackends.kdeconnect === true
        || installedBackends.valent === true
    readonly property bool available: running && backend !== ""
    readonly property bool checking: statusProcess.running
    readonly property bool busy: actionProcess.running || replyProcess.running
        || dataProcess.running
        || discoveryProcess.running
    readonly property bool smsLoading: dataProcess.running
    readonly property bool discoveryLoading: discoveryProcess.running
    readonly property var connectedDevices: devices.filter(device =>
        device.paired === true && device.reachable === true)
    readonly property var primaryDevice: connectedDevices.length > 0
        ? connectedDevices[0] : devices.length > 0 ? devices[0] : null

    function initialize() {
        if (initialized)
            return
        initialized = true
        refresh()
    }

    function refresh() {
        if (statusProcess.running)
            return
        _statusOutput = ""
        statusProcess.command = [helperPath, "status"]
        statusProcess.running = true
    }

    function replaceIfChanged(current, next) {
        return JSON.stringify(current) === JSON.stringify(next) ? current : next
    }

    function applyStatus(text, exitCode) {
        const value = String(text ?? "").trim()
        if (value === "") {
            if (exitCode !== 0) error = "Could not query phone integration."
            return
        }
        try {
            const result = JSON.parse(value)
            if (result.ok !== true) {
                error = String(result.error ?? "Could not query phone integration.")
                running = false
                devices = []
                return
            }
            backend = String(result.backend ?? "")
            running = result.running === true
            installedBackends = replaceIfChanged(installedBackends,
                result.installed ?? ({
                kdeconnect: false, valent: false
            }))
            devices = replaceIfChanged(devices,
                Array.isArray(result.devices) ? result.devices : [])
            error = ""
            if (backend === "kdeconnect" && !discoveryLoaded)
                Qt.callLater(() => loadDiscovery())
            else if (backend !== "kdeconnect")
                discoveryLoaded = false
        } catch (parseError) {
            error = "Phone integration returned invalid data."
        }
    }

    function deviceById(deviceId) {
        for (const device of devices)
            if (String(device.id) === String(deviceId)) return device
        return null
    }

    function hasPlugin(device, plugin) {
        return !!device && Array.isArray(device.plugins)
            && device.plugins.indexOf(plugin) >= 0
    }

    function runArguments(action, deviceId, values, label) {
        if (busy || backend === "" || String(deviceId ?? "") === "")
            return false
        _actionOutput = ""
        _actionLabel = String(label ?? "Updating phone…")
        error = ""
        status = _actionLabel
        const command = [helperPath, String(action), backend, String(deviceId)]
        for (const value of (values ?? []))
            command.push(String(value))
        actionProcess.command = command
        actionProcess.running = true
        return true
    }

    function runAction(action, deviceId, value, label) {
        const values = value !== undefined && value !== null
                && String(value) !== "" ? [value] : []
        return runArguments(action, deviceId, values, label)
    }

    function pair(deviceId) { return runAction("pair", deviceId, "", "Pairing…") }
    function accept(deviceId) { return runAction("accept", deviceId, "", "Accepting pairing…") }
    function reject(deviceId) { return runAction("reject", deviceId, "", "Rejecting pairing…") }
    function unpair(deviceId) { return runAction("unpair", deviceId, "", "Unpairing…") }
    function ping(deviceId) { return runAction("ping", deviceId, "", "Ping sent") }
    function ring(deviceId) { return runAction("ring", deviceId, "", "Ringing phone…") }
    function sendClipboard(deviceId) { return runAction("clipboard", deviceId, "", "Clipboard sent") }
    function browse(deviceId) { return runAction("browse", deviceId, "", "Opening phone files…") }
    function shareText(deviceId, text) { return runAction("share-text", deviceId, text, "Text sent") }
    function shareFile(deviceId, path) { return runAction("share-file", deviceId, path, "File sent") }
    function shareFiles(deviceId, paths) {
        if (!Array.isArray(paths) || paths.length === 0) return false
        return runArguments("share-files", deviceId, paths,
            paths.length === 1 ? "File sent" : paths.length + " files sent")
    }

    function runUtility(action, values, label) {
        if (busy || backend !== "kdeconnect") return false
        _actionOutput = ""
        _actionLabel = String(label)
        error = ""
        status = _actionLabel
        actionProcess.command = [helperPath, action].concat(values ?? [])
        actionProcess.running = true
        return true
    }

    function discover() {
        return runUtility("discover", [], "Looking for devices…")
    }

    function addAddress(value) {
        const address = String(value ?? "").trim()
        if (address === "") return false
        return runUtility("address-add", [address], "Adding discovery address…")
    }

    function removeAddress(value) {
        return runUtility("address-remove", [String(value)],
            "Removing discovery address…")
    }

    function loadDiscovery() {
        if (discoveryProcess.running || backend !== "kdeconnect") return
        _discoveryOutput = ""
        discoveryProcess.command = [helperPath, "discovery-info"]
        discoveryProcess.running = true
    }

    function matchingTailscalePeers(query) {
        const needle = String(query ?? "").trim().toLocaleLowerCase()
        if (needle === "") return tailscalePeers.slice(0, 12)
        return tailscalePeers.filter(peer =>
            String(peer.name ?? "").toLocaleLowerCase().includes(needle)
            || String(peer.dnsName ?? "").toLocaleLowerCase().includes(needle)
            || String(peer.address ?? "").includes(needle)
            || String(peer.os ?? "").toLocaleLowerCase().includes(needle)
        ).slice(0, 12)
    }

    function toggleBackend() {
        if (busy || !installed)
            return
        const selected = backend !== "" ? backend
            : installedBackends.kdeconnect === true ? "kdeconnect" : "valent"
        _actionOutput = ""
        _actionLabel = running ? "Phone service stopped" : "Phone service started"
        error = ""
        status = running ? "Stopping phone service…" : "Starting phone service…"
        actionProcess.command = running ? [helperPath, "stop-all"]
            : [helperPath, "start", selected]
        actionProcess.running = true
    }

    function loadSms(kind, deviceId, values) {
        if (dataProcess.running || backend !== "kdeconnect"
                || String(deviceId ?? "") === "")
            return false
        _dataOutput = ""
        _dataKind = kind
        smsDeviceId = String(deviceId)
        error = ""
        dataProcess.command = [helperPath, kind, backend, smsDeviceId]
            .concat(values ?? [])
        dataProcess.running = true
        return true
    }

    function loadConversations(deviceId) {
        messages = []
        return loadSms("conversations", deviceId, [])
    }
    function loadConversation(deviceId, threadId) {
        return loadSms("conversation", deviceId, [String(threadId)])
    }
    function loadContacts(deviceId) {
        return loadSms("contacts", deviceId, [])
    }
    function loadNotifications(deviceId) {
        if (dataProcess.running || backend !== "kdeconnect"
                || String(deviceId ?? "") === "") return false
        if (notificationDeviceId !== String(deviceId)) notifications = []
        notificationDeviceId = String(deviceId)
        _dataOutput = ""
        _dataKind = "notifications"
        dataProcess.command = [helperPath, "notifications", backend,
            String(deviceId)]
        dataProcess.running = true
        return true
    }
    function dismissNotification(deviceId, notificationId) {
        const started = runArguments("notification-dismiss", deviceId,
            [notificationId], "Notification dismissed")
        if (started) _afterNotificationDevice = String(deviceId)
        return started
    }
    function replyNotification(deviceId, notificationId, replyId, text) {
        const message = String(text ?? "")
        if (busy || backend !== "kdeconnect" || message.trim() === "")
            return false
        _replyOutput = ""
        _replyPayload = message
        _replyDevice = String(deviceId)
        error = ""
        status = "Sending reply…"
        replyProcess.command = [helperPath, "notification-reply-stdin",
            backend, String(deviceId), String(notificationId), String(replyId)]
        replyProcess.stdinEnabled = true
        replyProcess.running = true
        return true
    }
    function smsSend(deviceId, number, text) {
        const started = runArguments("sms-send", deviceId,
            [number, text], "Message sent")
        if (started) {
            _afterSmsKind = "conversations"
            _afterSmsDevice = String(deviceId)
            _afterSmsThread = ""
        }
        return started
    }
    function smsReply(deviceId, threadId, text) {
        const started = runArguments("sms-reply", deviceId,
            [threadId, text], "Reply sent")
        if (started) {
            _afterSmsKind = "conversation"
            _afterSmsDevice = String(deviceId)
            _afterSmsThread = String(threadId)
        }
        return started
    }
    function openSmsApp(deviceId) {
        return runArguments("sms-app", deviceId, [], "Opening messages…")
    }

    function clearSms() {
        smsDeviceId = ""
        conversations = []
        messages = []
        contacts = []
    }

    function openManager() {
        if (busy || !installed)
            return
        _actionOutput = ""
        _actionLabel = "Opening phone manager…"
        status = _actionLabel
        actionProcess.command = [helperPath, "open", backend]
        actionProcess.running = true
    }

    Process {
        id: statusProcess
        stdout: StdioCollector {
            onStreamFinished: root._statusOutput = text
        }
        onExited: exitCode => Qt.callLater(() =>
            root.applyStatus(root._statusOutput, exitCode))
    }

    Process {
        id: actionProcess
        stdout: StdioCollector {
            onStreamFinished: root._actionOutput = text
        }
        onExited: exitCode => Qt.callLater(() => {
            const output = root._actionOutput.trim()
            let detail = ""
            if (output !== "") {
                try {
                    const result = JSON.parse(output)
                    detail = result.ok === true ? "" : String(result.error ?? "")
                } catch (parseError) {
                    detail = output
                }
            }
            root.error = exitCode === 0 ? ""
                : detail !== "" ? detail : "Phone action failed."
            root.status = exitCode === 0 ? root._actionLabel : ""
            clearStatus.restart()
            refreshDelay.restart()
            if (root.backend === "kdeconnect") discoveryDelay.restart()
            const afterKind = root._afterSmsKind
            const afterDevice = root._afterSmsDevice
            const afterThread = root._afterSmsThread
            const afterNotification = root._afterNotificationDevice
            root._afterSmsKind = ""
            root._afterSmsDevice = ""
            root._afterSmsThread = ""
            root._afterNotificationDevice = ""
            if (exitCode === 0 && afterKind !== "")
                Qt.callLater(() => afterKind === "conversation"
                    ? root.loadConversation(afterDevice, afterThread)
                    : root.loadConversations(afterDevice))
            else if (exitCode === 0 && afterNotification !== "")
                Qt.callLater(() => root.loadNotifications(afterNotification))
        })
    }

    Process {
        id: replyProcess
        stdinEnabled: true
        stdout: StdioCollector {
            onStreamFinished: root._replyOutput = text
        }
        onStarted: {
            replyProcess.write(root._replyPayload)
            root._replyPayload = ""
            replyProcess.stdinEnabled = false
        }
        onExited: exitCode => Qt.callLater(() => {
            let detail = ""
            try {
                const result = JSON.parse(root._replyOutput.trim())
                detail = result.ok === true ? "" : String(result.error ?? "")
            } catch (parseError) {
                detail = root._replyOutput.trim()
            }
            root.error = exitCode === 0 ? ""
                : detail !== "" ? detail : "Could not send reply."
            root.status = exitCode === 0 ? "Reply sent" : ""
            clearStatus.restart()
            refreshDelay.restart()
            const deviceId = root._replyDevice
            root._replyDevice = ""
            if (exitCode === 0 && deviceId !== "")
                Qt.callLater(() => root.loadNotifications(deviceId))
        })
    }

    Process {
        id: dataProcess
        stdout: StdioCollector {
            onStreamFinished: root._dataOutput = text
        }
        onExited: exitCode => Qt.callLater(() => {
            const output = root._dataOutput.trim()
            try {
                const result = JSON.parse(output)
                if (exitCode !== 0 || result.ok !== true) {
                    root.error = String(result.error ?? "Could not load messages.")
                    return
                }
                if (root._dataKind === "conversations")
                    root.conversations = root.replaceIfChanged(
                        root.conversations, result.conversations ?? [])
                else if (root._dataKind === "conversation")
                    root.messages = root.replaceIfChanged(
                        root.messages, result.messages ?? [])
                else if (root._dataKind === "contacts")
                    root.contacts = root.replaceIfChanged(
                        root.contacts, result.contacts ?? [])
                else if (root._dataKind === "notifications")
                    root.notifications = root.replaceIfChanged(
                        root.notifications, result.notifications ?? [])
            } catch (parseError) {
                root.error = "Phone messaging returned invalid data."
            }
        })
    }

    Process {
        id: discoveryProcess
        stdout: StdioCollector {
            onStreamFinished: root._discoveryOutput = text
        }
        onExited: exitCode => Qt.callLater(() => {
            try {
                const result = JSON.parse(root._discoveryOutput.trim())
                if (exitCode !== 0 || result.ok !== true) {
                    root.error = String(result.error ?? "Could not load discovery information.")
                    return
                }
                root.customAddresses = root.replaceIfChanged(
                    root.customAddresses, result.customAddresses ?? [])
                root.discoveryLoaded = true
                root.localLanAddress = String(result.lanAddress ?? "")
                const tailscale = result.tailscale ?? ({})
                root.tailscaleInstalled = tailscale.installed === true
                root.tailscaleRunning = tailscale.running === true
                root.localTailscaleAddress = String(tailscale.address ?? "")
                root.tailscalePeers = root.replaceIfChanged(
                    root.tailscalePeers, tailscale.peers ?? [])
            } catch (parseError) {
                root.error = "Discovery returned invalid data."
            }
        })
    }

    Timer {
        interval: 12000
        repeat: true
        running: root.initialized
        onTriggered: root.refresh()
    }
    Timer {
        id: refreshDelay
        interval: 450
        onTriggered: {
            root.refresh()
            settleRefresh.restart()
        }
    }
    Timer { id: settleRefresh; interval: 1600; onTriggered: root.refresh() }
    Timer { id: discoveryDelay; interval: 650; onTriggered: root.loadDiscovery() }
    Timer { id: clearStatus; interval: 3500; onTriggered: root.status = "" }
}
