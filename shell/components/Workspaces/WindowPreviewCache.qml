pragma Singleton

import QtQuick
import "../.."
import Quickshell
import Quickshell.Io

// Inactive skarwm workspaces are parked off-screen, where X11 window capture
// is unreliable. Cache each workspace while it is visible so the overview can
// display those windows immediately when browsing or moving between tags.
Singleton {
    id: root

    property var readyWindows: ({})
    property var revisions: ({})
    property var pendingIds: []
    property var queuedIds: ({})
    property string activeId: ""

    function path(windowId) {
        const safe = String(windowId ?? "").replace(/[^0-9A-Za-z_-]/g, "_")
        return ShellState.stateDir + "/window-previews/" + safe + ".png"
    }

    function isReady(windowId) {
        return readyWindows[String(windowId)] === true
    }

    function request(windowId, refresh) {
        const id = String(windowId ?? "")
        if (id === "" || id === activeId || queuedIds[id] === true
                || (refresh !== true && isReady(id)))
            return
        const queued = Object.assign({}, queuedIds)
        queued[id] = true
        queuedIds = queued
        pendingIds = pendingIds.concat([id])
        startNext()
    }

    function cacheVisibleWindows() {
        if (!Wm.isSkarwm)
            return
        const visibleWorkspaces = ({})
        for (const workspace of Wm.workspaces) {
            if (workspace.visible === true)
                visibleWorkspaces[String(workspace.id)] = true
        }
        for (const win of Wm.windows) {
            if (!win || win.dock === true || win.scratchpad === true)
                continue
            const workspaceId = String(win.workspaceId ?? win.workspace ?? "")
            if (visibleWorkspaces[workspaceId] === true)
                request(win.id, false)
        }
    }

    function startNext() {
        if (capture.running || pendingIds.length === 0)
            return
        const next = pendingIds.slice()
        activeId = String(next.shift())
        pendingIds = next
        capture.running = true
    }

    function finish(windowId, succeeded) {
        const queued = ({})
        for (const id in queuedIds) {
            if (id !== windowId)
                queued[id] = true
        }
        queuedIds = queued
        if (succeeded) {
            const ready = Object.assign({}, readyWindows)
            ready[windowId] = true
            readyWindows = ready
            const nextRevisions = Object.assign({}, revisions)
            nextRevisions[windowId] = Number(nextRevisions[windowId] ?? 0) + 1
            revisions = nextRevisions
        }
        activeId = ""
        Qt.callLater(() => root.startNext())
    }

    Timer {
        id: refreshDebounce
        interval: 180
        onTriggered: root.cacheVisibleWindows()
    }

    Process {
        id: capture
        property string capturedId: root.activeId
        command: [ShellState.scriptsDir + "/window/window-preview",
            capturedId, root.path(capturedId)]
        onExited: exitCode => root.finish(capturedId, exitCode === 0)
    }

    Connections {
        target: Wm
        function onWindowsChanged() { refreshDebounce.restart() }
        function onWorkspacesChanged() { refreshDebounce.restart() }
        function onConnectedChanged() { refreshDebounce.restart() }
    }

    Component.onCompleted: refreshDebounce.restart()
}
