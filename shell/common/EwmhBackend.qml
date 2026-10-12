import QtQuick
import ".."
import Quickshell
import Quickshell.Io

WindowManagerBackend {
    id: root

    name: "ewmh"
    property string profile: "ewmh"
    property string wmName: ""
    property string wmIdentity: "unknown"
    readonly property string provider:
        ShellState.scriptsDir + "/wm/ewmh-provider"

    function clearState() {
        connected = false
        wmName = ""
        wmIdentity = "unknown"
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
        refreshTimer.stop()
        reconcileTimer.stop()
        snapshotQuery.running = false
        eventMonitor.running = false
        clearState()
    }

    function refresh() {
        if (!active) return
        snapshotQuery.running = false
        snapshotQuery.running = true
    }

    function acceptSnapshot(text) {
        try {
            const value = JSON.parse(String(text ?? ""))
            if (value.error !== undefined) throw new Error(String(value.error))
            connected = value.connected === true
            wmName = String(value.wmName ?? "")
            wmIdentity = String(value.wmIdentity ?? "unknown")
            capabilities = value.capabilities ?? ({})
            screens = Array.isArray(value.screens) ? value.screens : []
            workspaces = Array.isArray(value.workspaces) ? value.workspaces : []
            windows = Array.isArray(value.windows) ? value.windows : []
            changed()
        } catch (error) {
            console.warn("EWMH snapshot:", error)
            clearState()
        }
    }

    function runAction(arguments) {
        if (!connected) return false
        Quickshell.execDetached([provider, "action"].concat(arguments))
        return true
    }

    function switchWorkspace(id, screenId) {
        if (capabilities.workspaces !== true)
            return unsupported("switchWorkspace")
        return runAction(["workspace", String(id)])
    }

    function focusWindow(id) {
        if (capabilities.focusWindow !== true)
            return unsupported("focusWindow")
        return runAction(["focus", String(id)])
    }

    function closeWindow(id) {
        if (capabilities.closeWindow !== true)
            return unsupported("closeWindow")
        return runAction(["close", String(id)])
    }

    function moveWindowToWorkspace(windowId, workspaceId) {
        if (capabilities.moveWindowToWorkspace !== true)
            return unsupported("moveWindowToWorkspace")
        return runAction([
            "move-workspace", String(windowId), String(workspaceId)
        ])
    }

    function sendFocusedWindowToWorkspace(workspaceId) {
        const focused = windows.find(window => window.focused === true)
        return focused
            ? moveWindowToWorkspace(focused.id, workspaceId)
            : unsupported("moveWindowToWorkspace")
    }

    onActiveChanged: {
        if (active) start()
        else stop()
    }

    Process {
        id: snapshotQuery
        command: [root.provider, "snapshot", root.profile]
        running: false
        stdout: StdioCollector { id: snapshotOutput }
        stderr: StdioCollector { id: snapshotError }
        onExited: exitCode => {
            if (!root.active) return
            if (exitCode === 0)
                root.acceptSnapshot(snapshotOutput.text)
            else {
                const detail = snapshotError.text.trim()
                if (detail !== "") console.warn("EWMH provider:", detail)
                root.clearState()
            }
        }
    }

    Process {
        id: eventMonitor
        command: [root.provider, "monitor"]
        running: false
        stdout: SplitParser {
            onRead: line => {
                if (line !== "") refreshTimer.restart()
            }
        }
        onExited: {
            if (!root.active) return
            root.clearState()
            reconnectTimer.restart()
        }
    }

    Timer {
        id: refreshTimer
        interval: 80
        onTriggered: root.refresh()
    }
    Timer {
        id: reconnectTimer
        interval: 2000
        onTriggered: root.start()
    }
    Timer {
        id: reconcileTimer
        interval: 15000
        repeat: true
        onTriggered: root.refresh()
    }
}
