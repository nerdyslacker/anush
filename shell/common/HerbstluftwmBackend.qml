import QtQuick
import ".."
import Quickshell
import Quickshell.Io

WindowManagerBackend {
    id: root

    name: "herbstluftwm"
    layouts: [
        { name: "Vertical", glyph: "󰙀", command: "vertical" },
        { name: "Horizontal", glyph: "󰯋", command: "horizontal" },
        { name: "Max", glyph: "", command: "max" },
        { name: "Grid", glyph: "󰕮", command: "grid" }
    ]
    readonly property string provider:
        ShellState.scriptsDir + "/wm/herbstluftwm-provider"
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
                throw new Error("herbstluftwm is unavailable")
            snapshotRetryTimer.stop()
            connected = true
            capabilities = value.capabilities ?? ({})
            screens = Array.isArray(value.screens) ? value.screens : []
            workspaces = Array.isArray(value.workspaces) ? value.workspaces : []
            windows = Array.isArray(value.windows) ? value.windows : []
            changed()
        } catch (error) {
            console.warn("herbstluftwm snapshot:", error)
            clearState()
            if (active) snapshotRetryTimer.restart()
        }
    }

    function monitorForWorkspace(workspaceId) {
        const workspace = workspaces.find(item =>
            String(item.id) === String(workspaceId))
        return workspace ? (workspace.screenId ?? null) : null
    }

    function recomputeWorkspaceFlags() {
        workspaces = workspaces.map(workspace => Object.assign({}, workspace, {
            occupied: windows.some(window =>
                String(window.workspaceId) === String(workspace.id)),
            urgent: windows.some(window => window.urgent === true
                && String(window.workspaceId) === String(workspace.id))
        }))
    }

    function remapWindowScreens() {
        windows = windows.map(window => Object.assign({}, window, {
            screenId: monitorForWorkspace(window.workspaceId)
        }))
    }

    function changeTag(tagName, monitorId, focusedMonitorId) {
        const wantedTag = String(tagName)
        const wantedMonitor = String(monitorId)
        const focusedMonitor = String(focusedMonitorId)
        screens = screens.map(screen => Object.assign({}, screen, {
            focused: String(screen.id) === focusedMonitor
        }))
        workspaces = workspaces.map(workspace => {
            const selected = String(workspace.id) === wantedTag
            const replaced = String(workspace.screenId ?? "") === wantedMonitor
            if (!selected && !replaced)
                return Object.assign({}, workspace, {
                    focused: workspace.visible === true
                        && String(workspace.screenId ?? "") === focusedMonitor
                })
            return Object.assign({}, workspace, {
                screenId: selected ? wantedMonitor : null,
                active: selected,
                visible: selected,
                focused: selected && wantedMonitor === focusedMonitor
            })
        })
        remapWindowScreens()
    }

    function changeFocus(windowId, title) {
        const wanted = String(windowId).toLowerCase()
        windows = windows.map(window => {
            if (String(window.id).toLowerCase() !== wanted)
                return Object.assign({}, window, { focused: false })
            return Object.assign({}, window, {
                focused: wanted !== "0x0",
                title: String(title)
            })
        })
        const focused = windows.find(window => window.focused === true)
        if (focused && focused.screenId !== null
                && focused.screenId !== undefined) {
            const screenId = String(focused.screenId)
            screens = screens.map(screen => Object.assign({}, screen, {
                focused: String(screen.id) === screenId
            }))
            workspaces = workspaces.map(workspace =>
                Object.assign({}, workspace, {
                    focused: workspace.visible === true
                        && String(workspace.screenId ?? "") === screenId
                }))
        }
    }

    function updateWindow(windowId, update) {
        const wanted = String(windowId).toLowerCase()
        windows = windows.map(window =>
            String(window.id).toLowerCase() === wanted
                ? Object.assign({}, window, update) : window)
    }

    function acceptAttribute(fields) {
        if (fields.length < 4) return
        const match = String(fields[1]).match(
            /^clients\.(0x[0-9a-fA-F]+)\.(title|tag|floating_effectively|minimized|class|instance)$/)
        if (!match) return
        const windowId = match[1]
        const attribute = match[2]
        const value = fields.slice(3).join("\t")
        if (attribute === "title") updateWindow(windowId, { title: value })
        else if (attribute === "tag") {
            updateWindow(windowId, {
                workspaceId: value,
                screenId: monitorForWorkspace(value)
            })
            recomputeWorkspaceFlags()
        } else if (attribute === "floating_effectively")
            updateWindow(windowId, { floating: value === "true" })
        else if (attribute === "minimized")
            updateWindow(windowId, { minimized: value === "true" })
        else if (attribute === "class") {
            const current = windows.find(window =>
                String(window.id).toLowerCase() === windowId.toLowerCase())
            updateWindow(windowId, {
                class: value,
                appId: value || String(current ? (current.instance ?? "") : "")
            })
        } else if (attribute === "instance") {
            const current = windows.find(window =>
                String(window.id).toLowerCase() === windowId.toLowerCase())
            updateWindow(windowId, {
                instance: value,
                appId: String(current ? (current.class ?? "") : "") || value
            })
        }
    }

    function acceptEvent(line) {
        const fields = String(line).split("\t")
        const event = fields[0]
        let handled = true
        if (event === "anush_tag_changed" && fields.length >= 4)
            changeTag(fields[1], fields[2], fields[3])
        else if (event === "focus_changed" && fields.length >= 2)
            changeFocus(fields[1], fields.slice(2).join("\t"))
        else if (event === "window_title_changed" && fields.length >= 3)
            updateWindow(fields[1], { title: fields.slice(2).join("\t") })
        else if (event === "urgent" && fields.length >= 3) {
            updateWindow(fields[2], { urgent: fields[1] === "on" })
            recomputeWorkspaceFlags()
        } else if (event === "fullscreen" && fields.length >= 3)
            updateWindow(fields[2], { fullscreen: fields[1] === "on" })
        else if (event === "attribute_changed"
                && String(fields[1] ?? "").match(
                    /^tags\.[0-9]+\.tiling\.focused_frame\.algorithm$/)) {
            handled = false
            refreshTimer.restart()
        } else if (event === "attribute_changed")
            acceptAttribute(fields)
        else if (["tag_flags", "tag_added", "tag_removed", "tag_renamed",
                "reload"].indexOf(event) >= 0) {
            handled = false
            refreshTimer.restart()
        } else return
        if (handled) changed()
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
    function setGaps(value) { return runAction(["gaps", String(value)]) }
    function setLayout(command) {
        const changed = runAction(["layout", String(command)])
        if (changed) refreshAfterAction.restart()
        return changed
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
                if (detail !== "") console.warn("herbstluftwm provider:", detail)
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
        interval: 80
        onTriggered: root.refresh()
    }
    Timer {
        id: refreshAfterAction
        interval: 150
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
