import QtQuick
import ".."
import Quickshell
import Quickshell.Io

WindowManagerBackend {
    id: root

    name: "ewmh"
    property string profile: "ewmh"
    property string providerName: "ewmh-provider"
    property string wmName: ""
    property string wmIdentity: "unknown"
    property string integration: ""
    property bool refreshPending: false
    property string defaultLayout: ""
    property var rememberedLayouts: ({})
    readonly property string provider: ShellState.scriptsDir + "/wm/" + providerName

    function withRememberedLayouts(values) {
        return values.map(workspace => {
            const id = String(workspace.id)
            const reported = String(workspace.layout ?? "")
            const remembered = String(rememberedLayouts[id] ?? "")
            const layout = reported !== "" ? reported
                : remembered !== "" ? remembered : defaultLayout
            return layout !== ""
                ? Object.assign({}, workspace, { layout: layout }) : workspace
        })
    }

    function rememberFocusedLayout(command) {
        const next = Object.assign({}, rememberedLayouts)
        let found = false
        for (const workspace of workspaces) {
            if (workspace.focused === true) {
                next[String(workspace.id)] = command
                found = true
            }
        }
        if (!found) return
        rememberedLayouts = next
        workspaces = withRememberedLayouts(workspaces.map(workspace =>
            workspace.focused === true
                ? Object.assign({}, workspace, { layout: command }) : workspace))
        changed()
    }

    function clearState() {
        connected = false
        wmName = ""
        wmIdentity = "unknown"
        integration = ""
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
        actionRefreshTimer.stop()
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
            const previousIntegration = integration
            const value = JSON.parse(String(text ?? ""))
            if (value.error !== undefined) throw new Error(String(value.error))
            if (value.connected !== true)
                throw new Error("EWMH window manager is unavailable")
            snapshotRetryTimer.stop()
            connected = true
            wmName = String(value.wmName ?? "")
            wmIdentity = String(value.wmIdentity ?? "unknown")
            integration = String(value.integration ?? profile)
            capabilities = value.capabilities ?? ({})
            if (Array.isArray(value.layouts)) layouts = value.layouts
            screens = Array.isArray(value.screens) ? value.screens : []
            workspaces = withRememberedLayouts(
                Array.isArray(value.workspaces) ? value.workspaces : [])
            windows = Array.isArray(value.windows) ? value.windows : []
            changed()
            if (previousIntegration !== ""
                    && previousIntegration !== integration)
                eventMonitor.running = false
        } catch (error) {
            console.warn("EWMH snapshot:", error)
            clearState()
            if (active) snapshotRetryTimer.restart()
        }
    }

    function runAction(arguments) {
        if (!connected) return false
        Quickshell.execDetached([provider, "action", profile].concat(arguments))
        actionRefreshTimer.restart()
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

    function setLayout(command) {
        if (capabilities.layouts !== true)
            return unsupported("setLayout")
        const value = String(command)
        const started = runAction(["layout", value])
        if (started) rememberFocusedLayout(value)
        return started
    }

    function setGaps(value) {
        if (capabilities.gaps !== true)
            return unsupported("setGaps")
        return runAction(["gaps", String(value)])
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
        id: actionRefreshTimer
        interval: 500
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
        interval: 15000
        repeat: true
        onTriggered: root.refresh()
    }
}
