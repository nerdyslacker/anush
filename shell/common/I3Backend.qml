import QtQuick
import ".."
import Quickshell
import Quickshell.Io

WindowManagerBackend {
    id: root

    name: "i3"
    layouts: [
        { name: "Split Horizontal", glyph: "󰙀", command: "splith" },
        { name: "Split Vertical", glyph: "󱥣", command: "splitv" },
        { name: "Stacking", glyph: "󰕮", command: "stacking" },
        { name: "Tabbed", glyph: "󰓩", command: "tabbed" }
    ]
    readonly property string provider: ShellState.scriptsDir + "/wm/i3-provider"
    property bool refreshPending: false

    function clearState() {
        connected = false
        capabilities = ({})
        screens = []
        workspaces = []
        windows = []
        changed()
    }

    function start() {
        if (!active) return
        refresh()
        eventMonitor.running = true
        reconcileTimer.start()
    }

    function stop() {
        reconnectTimer.stop()
        snapshotRetryTimer.stop()
        refreshTimer.stop()
        reconcileTimer.stop()
        refreshPending = false
        snapshotQuery.running = false
        eventMonitor.running = false
        clearState()
    }

    function refresh() {
        if (!active) return
        if (snapshotQuery.running) {
            refreshPending = true
            return
        }
        refreshPending = false
        snapshotQuery.running = true
    }

    function acceptSnapshot(text) {
        try {
            const value = JSON.parse(String(text ?? ""))
            if (value.error !== undefined) throw new Error(String(value.error))
            if (value.connected !== true)
                throw new Error("i3 is unavailable")
            snapshotRetryTimer.stop()
            connected = true
            capabilities = value.capabilities ?? ({})
            screens = Array.isArray(value.screens) ? value.screens : []
            workspaces = Array.isArray(value.workspaces) ? value.workspaces : []
            windows = Array.isArray(value.windows) ? value.windows : []
            changed()
        } catch (error) {
            console.warn("i3 snapshot:", error)
            clearState()
            if (active) snapshotRetryTimer.restart()
        }
    }

    function runAction(arguments) {
        if (!connected) return false
        Quickshell.execDetached([provider, "action"].concat(arguments))
        return true
    }

    function switchWorkspace(id, screenId) {
        const arguments = ["workspace", String(id)]
        if (screenId !== undefined && screenId !== null && String(screenId) !== "")
            arguments.push(String(screenId))
        return runAction(arguments)
    }
    function focusWindow(id) { return runAction(["focus", String(id)]) }
    function focusScreen(id) { return runAction(["focus-screen", String(id)]) }
    function closeWindow(id) { return runAction(["close", String(id)]) }
    function moveWindowToWorkspace(windowId, workspaceId) {
        return runAction(["move-workspace", String(windowId), String(workspaceId)])
    }
    function moveWindowToScreen(windowId, screenId) {
        return runAction(["move-screen", String(windowId), String(screenId)])
    }
    function sendFocusedWindowToWorkspace(workspaceId) {
        const focused = windows.find(window => window.focused === true)
        return focused
            ? moveWindowToWorkspace(focused.id, workspaceId)
            : unsupported("moveWindowToWorkspace")
    }
    function sendToScratchpad(id) {
        return runAction(["send-scratchpad", String(id)])
    }
    function toggleScratchpad(register) {
        return runAction(["toggle-scratchpad", String(register)])
    }
    function setGaps(value) { return runAction(["gaps", String(value)]) }
    function setLayout(command) {
        const value = String(command)
        const focused = workspaces.find(workspace => workspace.focused === true)
        const started = runAction(["layout", value])
        if (!started) return false
        if (focused) {
            workspaces = workspaces.map(workspace =>
                String(workspace.id) === String(focused.id)
                    ? Object.assign({}, workspace, { layout: value })
                    : workspace)
        }
        changed()
        layoutRefreshTimer.restart()
        return true
    }
    function reloadWindowManager() { return runAction(["reload"]) }
    function quitWindowManager() { return runAction(["quit"]) }

    onActiveChanged: {
        if (active) start()
        else stop()
    }

    Process {
        id: snapshotQuery
        command: [root.provider, "snapshot"]
        running: false
        stdout: StdioCollector { id: snapshotOutput }
        stderr: StdioCollector { id: snapshotError }
        onExited: exitCode => {
            if (!root.active) return
            if (exitCode === 0)
                root.acceptSnapshot(snapshotOutput.text)
            else {
                const detail = snapshotError.text.trim()
                if (detail !== "") console.warn("i3 provider:", detail)
                root.clearState()
                snapshotRetryTimer.restart()
            }
            if (root.refreshPending) refreshTimer.restart()
        }
    }

    Process {
        id: eventMonitor
        command: [root.provider, "monitor"]
        running: false
        stdout: SplitParser {
            onRead: line => { if (line !== "") refreshTimer.restart() }
        }
        onExited: {
            if (!root.active) return
            snapshotQuery.running = false
            root.clearState()
            reconnectTimer.restart()
        }
    }

    Timer {
        id: refreshTimer
        interval: 60
        onTriggered: root.refresh()
    }
    Timer {
        id: layoutRefreshTimer
        interval: 250
        onTriggered: root.refresh()
    }
    Timer {
        id: reconnectTimer
        interval: 2000
        onTriggered: root.start()
    }
    Timer {
        id: snapshotRetryTimer
        interval: 2000
        onTriggered: root.refresh()
    }
    Timer {
        id: reconcileTimer
        interval: 30000
        repeat: true
        onTriggered: root.refresh()
    }
}
