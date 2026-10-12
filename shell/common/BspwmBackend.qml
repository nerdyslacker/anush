import QtQuick
import ".."
import Quickshell
import Quickshell.Io

WindowManagerBackend {
    id: root

    name: "bspwm"
    readonly property string provider:
        ShellState.scriptsDir + "/wm/bspwm-provider"
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
                throw new Error("bspwm is unavailable")
            snapshotRetryTimer.stop()
            connected = true
            capabilities = value.capabilities ?? ({})
            screens = Array.isArray(value.screens) ? value.screens : []
            workspaces = Array.isArray(value.workspaces) ? value.workspaces : []
            windows = Array.isArray(value.windows) ? value.windows : []
            changed()
        } catch (error) {
            console.warn("bspwm snapshot:", error)
            clearState()
            if (active) snapshotRetryTimer.restart()
        }
    }

    function normalizedId(value) {
        const number = Number.parseInt(String(value), 0)
        if (!Number.isFinite(number)) return String(value).toLowerCase()
        return "0x" + number.toString(16).padStart(8, "0")
    }

    function focusMonitor(monitorId) {
        const wanted = normalizedId(monitorId)
        screens = screens.map(screen => Object.assign({}, screen, {
            focused: String(screen.id) === wanted
        }))
        workspaces = workspaces.map(workspace => Object.assign({}, workspace, {
            focused: String(workspace.screenId) === wanted
                && workspace.visible === true
        }))
    }

    function focusDesktop(monitorId, desktopId, focusMonitorToo) {
        const wantedMonitor = normalizedId(monitorId)
        const wantedDesktop = normalizedId(desktopId)
        if (focusMonitorToo) focusMonitor(wantedMonitor)
        workspaces = workspaces.map(workspace => {
            if (String(workspace.screenId) !== wantedMonitor)
                return workspace
            const selected = String(workspace.id) === wantedDesktop
            return Object.assign({}, workspace, {
                active: selected,
                visible: selected,
                focused: selected && screens.some(screen =>
                    String(screen.id) === wantedMonitor
                        && screen.focused === true)
            })
        })
        if (focusMonitorToo)
            windows = windows.map(window => Object.assign({}, window, {
                focused: false
            }))
    }

    function focusNode(monitorId, desktopId, nodeId) {
        focusDesktop(monitorId, desktopId, true)
        const wanted = normalizedId(nodeId)
        windows = windows.map(window => Object.assign({}, window, {
            focused: String(window.id) === wanted
        }))
    }

    function updateNodeState(nodeId, state, enabled) {
        const wanted = normalizedId(nodeId)
        windows = windows.map(window => {
            if (String(window.id) !== wanted) return window
            const update = {}
            if (state === "floating") update.floating = enabled
            if (state === "fullscreen") update.fullscreen = enabled
            if (state === "tiled" && enabled) update.floating = false
            return Object.assign({}, window, update)
        })
    }

    function updateUrgency(nodeId, enabled) {
        const wanted = normalizedId(nodeId)
        windows = windows.map(window => String(window.id) === wanted
            ? Object.assign({}, window, { urgent: enabled }) : window)
        workspaces = workspaces.map(workspace => Object.assign({}, workspace, {
            urgent: windows.some(window => window.urgent === true
                && String(window.workspaceId) === String(workspace.id))
        }))
    }

    function updateLayout(desktopId, layout) {
        const wanted = normalizedId(desktopId)
        workspaces = workspaces.map(workspace => String(workspace.id) === wanted
            ? Object.assign({}, workspace, { layout: String(layout) })
            : workspace)
    }

    function acceptEvent(line) {
        const fields = String(line).trim().split(/\s+/)
        const event = fields[0]
        let handled = true
        if (event === "monitor_focus" && fields.length >= 2)
            focusMonitor(fields[1])
        else if (event === "desktop_focus" && fields.length >= 3)
            focusDesktop(fields[1], fields[2], true)
        else if (event === "desktop_activate" && fields.length >= 3)
            focusDesktop(fields[1], fields[2], false)
        else if (event === "desktop_layout" && fields.length >= 4)
            updateLayout(fields[2], fields[3])
        else if (event === "node_focus" && fields.length >= 4)
            focusNode(fields[1], fields[2], fields[3])
        else if (event === "node_state" && fields.length >= 6)
            updateNodeState(fields[3], fields[4], fields[5] === "on")
        else if (event === "node_flag" && fields.length >= 6
                && fields[4] === "urgent")
            updateUrgency(fields[3], fields[5] === "on")
        else if (["node_activate", "node_geometry", "node_layer",
                "node_presel", "node_stack", "pointer_action"]
                .indexOf(event) >= 0)
            return
        else handled = false
        if (handled) changed()
        else refreshTimer.restart()
    }

    function runAction(arguments) {
        if (!connected) return false
        Quickshell.execDetached([provider, "action"].concat(arguments))
        return true
    }

    function switchWorkspace(id, screenId) {
        return runAction(["workspace", String(id)])
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
    function setGaps(value) { return runAction(["gaps", String(value)]) }

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
                if (detail !== "") console.warn("bspwm provider:", detail)
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
            onRead: line => { if (line !== "") root.acceptEvent(line) }
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
