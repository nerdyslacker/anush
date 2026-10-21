import QtQuick
import Quickshell
import Quickshell.Io

Item {
    id: root

    visible: false

    property bool enabled: false
    property bool available: false
    property bool busy: false
    property bool paused: false
    property bool backendAvailable: false
    property bool supportsImages: false
    property bool incompatible: false
    property string errorCode: ""
    property string errorMessage: ""
    property var entries: []
    property string query: ""

    readonly property string executable: {
        const configured = String(Quickshell.env("ANUSH_MINNI_CLI") ?? "")
        return configured !== "" ? configured : "minni"
    }

    property var pageEntries: []
    property string pageCursor: ""
    property string loadingQuery: ""
    property string queuedQuery: ""
    property bool refreshQueued: false
    property var actionQueue: []
    property var previewQueue: []
    property string activeAction: ""
    property string activeActionItemId: ""
    property string activePreviewId: ""

    readonly property bool actionBusy: actionProcess.running
        || actionQueue.length > 0

    signal previewReady(string itemId, string path, int width, int height)
    signal previewFailed(string itemId, string errorCode)
    signal actionFinished(string action, bool ok, string errorCode)

    function parseEnvelope(text, context) {
        try {
            const value = JSON.parse(text)
            if (!value || typeof value !== "object")
                throw new Error("response is not an object")
            return value
        } catch (error) {
            root.errorCode = "INVALID_RESPONSE"
            root.errorMessage = "Invalid minni " + context + " response."
            return null
        }
    }

    function setProtocolError(envelope, fallback) {
        const error = envelope && envelope.error ? envelope.error : {}
        const code = String(error.code ?? "")
        root.errorCode = code
        root.incompatible = code === "UNSUPPORTED_VERSION"
        if (root.incompatible)
            root.errorMessage = "minni protocol v1 is required."
        else if (code === "LIMIT_EXCEEDED")
            root.errorMessage = "minni storage limit reached."
        else if (code === "PERMISSION_DENIED")
            root.errorMessage = "minni cannot access its state directory."
        else if (code === "INTERNAL")
            root.errorMessage = "minni storage failed. Check permissions and free space."
        else
            root.errorMessage = String(error.message ?? fallback)
    }

    function start() {
        if (!enabled || capabilityProcess.running || statusProcess.running)
            return
        errorCode = ""
        errorMessage = ""
        capabilityProcess.running = true
    }

    function stop() {
        reconnectTimer.stop()
        capabilityProcess.running = false
        statusProcess.running = false
        listProcess.running = false
        actionProcess.running = false
        previewProcess.running = false
        actionQueue = []
        previewQueue = []
        entries = []
        available = false
        busy = false
        supportsImages = false
    }

    function refresh(searchQuery) {
        if (!enabled || !available)
            return
        const nextQuery = String(searchQuery ?? "")
        if (listProcess.running) {
            queuedQuery = nextQuery
            refreshQueued = true
            return
        }
        loadingQuery = nextQuery
        query = nextQuery
        pageEntries = []
        pageCursor = ""
        busy = true
        runPage()
    }

    function runPage() {
        const command = [executable, "--json"]
        if (loadingQuery === "")
            command.push("list")
        else
            command.push("search", loadingQuery)
        command.push("--limit", "200")
        if (pageCursor !== "")
            command.push("--cursor", pageCursor)
        listProcess.command = command
        listProcess.running = true
    }

    function finishRefresh() {
        busy = false
        if (refreshQueued) {
            const nextQuery = queuedQuery
            refreshQueued = false
            queuedQuery = ""
            Qt.callLater(() => root.refresh(nextQuery))
        }
    }

    function enqueueAction(action, itemId, scope) {
        if (!enabled || !available)
            return
        const next = actionQueue.slice()
        if (next.length >= 64)
            return
        next.push({ action: action, itemId: itemId ?? "", scope: scope ?? "" })
        actionQueue = next
        runNextAction()
    }

    function runNextAction() {
        if (actionProcess.running || actionQueue.length === 0)
            return
        const next = actionQueue[0]
        actionQueue = actionQueue.slice(1)
        activeAction = next.action
        activeActionItemId = next.itemId
        const command = [executable, "--json", next.action]
        if (next.itemId !== "")
            command.push(next.itemId)
        if (next.action === "clear")
            command.push(next.scope === "all" ? "--all" : "--unpinned")
        actionProcess.command = command
        actionProcess.running = true
    }

    function copy(itemId) { enqueueAction("copy", itemId, "") }
    function pin(itemId) { enqueueAction("pin", itemId, "") }
    function unpin(itemId) { enqueueAction("unpin", itemId, "") }
    function remove(itemId) { enqueueAction("remove", itemId, "") }
    function clear(scope) { enqueueAction("clear", "", scope) }
    function pause() { enqueueAction("pause", "", "") }
    function resume() { enqueueAction("resume", "", "") }

    function requestPreview(itemId) {
        if (!enabled || !available || itemId === "")
            return
        if (!supportsImages) {
            previewFailed(itemId, "UNSUPPORTED_IMAGE")
            return
        }
        if (activePreviewId === itemId
                || previewQueue.indexOf(itemId) !== -1)
            return
        const next = previewQueue.slice()
        if (next.length < 32)
            next.push(itemId)
        previewQueue = next
        runNextPreview()
    }

    function runNextPreview() {
        if (previewProcess.running || previewQueue.length === 0)
            return
        activePreviewId = previewQueue[0]
        previewQueue = previewQueue.slice(1)
        previewProcess.command = [executable, "--json", "preview", activePreviewId]
        previewProcess.running = true
    }

    onEnabledChanged: {
        if (enabled)
            start()
        else
            stop()
    }
    Component.onCompleted: {
        if (enabled)
            start()
    }

    Process {
        id: capabilityProcess
        command: [root.executable, "--json", "capabilities"]
        stdout: StdioCollector { id: capabilityOutput }
        stderr: StdioCollector {}
        onExited: exitCode => {
            if (!root.enabled)
                return
            const envelope = root.parseEnvelope(capabilityOutput.text,
                "capability")
            const result = envelope && envelope.result ? envelope.result : {}
            const capabilities = Array.isArray(result.capabilities)
                ? result.capabilities : []
            const compatible = exitCode === 0 && envelope && envelope.ok === true
                && Number(result.version) === 1
                && capabilities.indexOf("text") !== -1
            if (compatible) {
                root.incompatible = false
                root.supportsImages = capabilities.indexOf("image") !== -1
                    && capabilities.indexOf("preview") !== -1
                statusProcess.running = true
                return
            }
            root.available = false
            root.incompatible = exitCode !== 3
            root.errorCode = root.incompatible
                ? "UNSUPPORTED_VERSION" : "DISCONNECTED"
            root.errorMessage = root.incompatible
                ? "minni protocol v1 with text support is required."
                : "minni is not running. Select clipmenu to use the fallback."
            reconnectTimer.start()
        }
    }

    Process {
        id: statusProcess
        command: [root.executable, "--json", "status"]
        stdout: StdioCollector { id: statusOutput }
        stderr: StdioCollector { id: statusError }
        onExited: exitCode => {
            if (!root.enabled)
                return
            const envelope = root.parseEnvelope(statusOutput.text, "status")
            if (exitCode === 0 && envelope && envelope.ok === true) {
                const result = envelope.result || {}
                root.available = true
                root.incompatible = false
                root.errorCode = ""
                root.errorMessage = ""
                root.paused = result.paused === true
                root.backendAvailable = result.backend !== "unavailable"
                root.refresh(root.query)
            } else {
                root.available = false
                const detail = statusError.text.trim()
                root.incompatible = detail.indexOf("protocol handshake failed") !== -1
                root.errorCode = root.incompatible ? "UNSUPPORTED_VERSION" : "DISCONNECTED"
                root.errorMessage = root.incompatible
                    ? "minni protocol v1 is required."
                    : "minni is not running. Select clipmenu to use the fallback."
                reconnectTimer.start()
            }
        }
    }

    Process {
        id: listProcess
        stdout: StdioCollector { id: listOutput }
        stderr: StdioCollector {}
        onExited: exitCode => {
            if (!root.enabled)
                return
            if (exitCode === 3) {
                root.available = false
                root.errorCode = "DISCONNECTED"
                root.errorMessage = "minni is not running. Select clipmenu to use the fallback."
                root.finishRefresh()
                reconnectTimer.start()
                return
            }
            const envelope = root.parseEnvelope(listOutput.text, "history")
            if (exitCode !== 0 || !envelope || !envelope.ok) {
                if (envelope && envelope.error
                        && envelope.error.code === "CURSOR_STALE") {
                    root.pageEntries = []
                    root.pageCursor = ""
                    Qt.callLater(() => root.runPage())
                    return
                }
                if (envelope)
                    root.setProtocolError(envelope, "Could not load clipboard history.")
                root.finishRefresh()
                return
            }
            const result = envelope.result || {}
            const items = Array.isArray(result.items)
                ? envelope.result.items : []
            root.pageEntries = root.pageEntries.concat(items)
            root.pageCursor = String(result.next_cursor ?? "")
            if (root.pageCursor !== "" && root.pageEntries.length < 2000) {
                Qt.callLater(() => root.runPage())
            } else {
                root.entries = root.pageEntries
                root.errorCode = ""
                root.errorMessage = ""
                root.finishRefresh()
            }
        }
    }

    Process {
        id: actionProcess
        stdout: StdioCollector { id: actionOutput }
        stderr: StdioCollector {}
        onExited: exitCode => {
            const action = root.activeAction
            const envelope = root.parseEnvelope(actionOutput.text, "action")
            const ok = exitCode === 0 && envelope && envelope.ok === true
            if (!ok && envelope)
                root.setProtocolError(envelope, "minni rejected the action.")
            const responseError = envelope && envelope.error ? envelope.error : {}
            if (!ok && responseError.code === "NOT_FOUND") {
                root.entries = root.entries.filter(
                    item => item.id !== root.activeActionItemId)
            }
            if (!ok && responseError.code === "BACKEND_UNAVAILABLE")
                root.backendAvailable = false
            if (!ok && exitCode === 3) {
                root.available = false
                root.errorCode = "DISCONNECTED"
                root.errorMessage = "minni is not running. Select clipmenu to use the fallback."
                reconnectTimer.start()
            }
            if (ok && (action === "pause" || action === "resume"))
                root.paused = envelope.result && envelope.result.paused === true
            if (ok) {
                root.errorCode = ""
                root.errorMessage = ""
                if (action !== "copy")
                    Qt.callLater(() => root.refresh(root.query))
            }
            root.actionFinished(action, ok, String(responseError.code ?? ""))
            root.activeAction = ""
            root.activeActionItemId = ""
            root.runNextAction()
        }
    }

    Process {
        id: previewProcess
        stdout: StdioCollector { id: previewOutput }
        stderr: StdioCollector {}
        onExited: exitCode => {
            if (!root.enabled)
                return
            const envelope = root.parseEnvelope(previewOutput.text, "preview")
            if (exitCode === 0 && envelope && envelope.ok === true) {
                const result = envelope.result
                root.previewReady(String(result.item_id), String(result.path),
                    Number(result.width), Number(result.height))
            } else {
                const error = envelope && envelope.error ? envelope.error : {}
                root.previewFailed(root.activePreviewId,
                    String(error.code ?? "PREVIEW_UNAVAILABLE"))
            }
            root.activePreviewId = ""
            root.runNextPreview()
        }
    }

    Timer {
        id: refreshTimer
        interval: 1000
        repeat: true
        running: root.enabled && root.available
        onTriggered: {
            if (!root.busy && !root.actionBusy)
                root.refresh(root.query)
        }
    }

    Timer {
        interval: 3000
        repeat: true
        running: root.enabled && root.available
        onTriggered: {
            if (!statusProcess.running && !capabilityProcess.running)
                statusProcess.running = true
        }
    }

    Timer {
        id: reconnectTimer
        interval: 2000
        onTriggered: {
            if (root.enabled)
                root.start()
        }
    }
}
