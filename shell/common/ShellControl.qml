pragma Singleton

import QtQuick
import ".."
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    readonly property int protocolVersion: 1
    readonly property string cliVersion: "0.1.0"

    function wmStatus() {
        return {
            wm: Wm.detectedWmName,
            detectedIdentity: Wm.detectedWmIdentity,
            requestedBackend: Wm.requestedBackend,
            backend: Wm.backendName,
            integration: Wm.backendIntegration,
            connected: Wm.connected,
            connectionState: Wm.connectionState,
            focusedScreen: Wm.focusedScreen ? Wm.focusedScreen.id : null,
            focusedWorkspace: Wm.focusedWorkspace
                ? Wm.focusedWorkspace.id : null,
            focusedWindow: Wm.focusedWindow ? Wm.focusedWindow.id : null,
            screenCount: Wm.screens.length,
            workspaceCount: Wm.workspaces.length,
            windowCount: Wm.windows.length
        }
    }

    function wmFailure(reason) {
        return JSON.stringify({ ok: false, error: String(reason) })
    }

    function wmAction(capability, action, callback) {
        const unavailable = wmUnavailable(capability, action)
        if (unavailable !== "") return unavailable
        if (callback() !== true)
            return wmFailure(Wm.backendName + " rejected " + action)
        return JSON.stringify({ ok: true })
    }

    function wmUnavailable(capability, action) {
        if (!Wm.connected)
            return wmFailure(Wm.backendName + " backend is disconnected")
        if (Wm.capabilities[capability] !== true)
            return wmFailure(Wm.backendName + " does not support " + action)
        return ""
    }

    function wmEntry(values, id) {
        const wanted = String(id)
        return values.find(entry => String(entry.id) === wanted) ?? null
    }

    IpcHandler {
        target: "anush"

        function ping(): string { return "anush" }

        function status(): string {
            const theme = ShellState.state && ShellState.state.theme
                ? ShellState.state.theme : {}
            return JSON.stringify({
                name: "anush",
                version: root.cliVersion,
                protocol: root.protocolVersion,
                ready: ShellState.ready,
                themeMode: String(theme.mode ?? "dark"),
                themePreset: String(theme.preset ?? "srcery-dark"),
                notepadOpen: NotepadState.opened
            })
        }

        function reload(): void {
            // Let the IPC reply flush before replacing the QML engine.
            Qt.callLater(() => Quickshell.reload(true))
        }

        function themeMode(mode: string): bool {
            if (mode !== "light" && mode !== "dark")
                return false
            Theme.persistThemeMode(mode)
            return true
        }
    }

    IpcHandler {
        target: "wm"

        function status(): string { return JSON.stringify(root.wmStatus()) }
        function capabilities(): string {
            return JSON.stringify(Wm.capabilities)
        }
        function screens(): string { return JSON.stringify(Wm.screens) }
        function workspaces(): string { return JSON.stringify(Wm.workspaces) }
        function windows(): string { return JSON.stringify(Wm.windows) }
        function state(): string {
            return JSON.stringify(Object.assign(root.wmStatus(), {
                capabilities: Wm.capabilities,
                screens: Wm.screens,
                workspaces: Wm.workspaces,
                windows: Wm.windows
            }))
        }

        function workspaceFocus(id: string): string {
            const unavailable = root.wmUnavailable(
                "workspaces", "workspace focus")
            if (unavailable !== "") return unavailable
            const workspace = root.wmEntry(Wm.workspaces, id)
            if (!workspace)
                return root.wmFailure("unknown workspace " + id)
            return root.wmAction("workspaces", "workspace focus", () =>
                Wm.switchWorkspace(workspace.id, workspace.screenId))
        }

        function screenFocus(id: string): string {
            const unavailable = root.wmUnavailable("screens", "screen focus")
            if (unavailable !== "") return unavailable
            const screen = root.wmEntry(Wm.screens, id)
            if (!screen)
                return root.wmFailure("unknown screen " + id)
            return root.wmAction("screens", "screen focus", () =>
                Wm.focusScreen(screen.id))
        }

        function windowFocus(id: string): string {
            const unavailable = root.wmUnavailable(
                "focusWindow", "window focus")
            if (unavailable !== "") return unavailable
            const window = root.wmEntry(Wm.windows, id)
            if (!window)
                return root.wmFailure("unknown window " + id)
            return root.wmAction("focusWindow", "window focus", () =>
                Wm.focusWindow(window.id))
        }

        function windowClose(id: string): string {
            const unavailable = root.wmUnavailable(
                "closeWindow", "window close")
            if (unavailable !== "") return unavailable
            const window = root.wmEntry(Wm.windows, id)
            if (!window)
                return root.wmFailure("unknown window " + id)
            return root.wmAction("closeWindow", "window close", () =>
                Wm.closeWindow(window.id))
        }

        function windowMoveWorkspace(id: string, workspaceId: string): string {
            const unavailable = root.wmUnavailable(
                "moveWindowToWorkspace", "moving a window to a workspace")
            if (unavailable !== "") return unavailable
            const window = root.wmEntry(Wm.windows, id)
            if (!window)
                return root.wmFailure("unknown window " + id)
            const workspace = root.wmEntry(Wm.workspaces, workspaceId)
            if (!workspace)
                return root.wmFailure("unknown workspace " + workspaceId)
            return root.wmAction("moveWindowToWorkspace",
                "moving a window to a workspace", () =>
                    Wm.moveWindowToWorkspace(window.id, workspace.id))
        }

        function windowMoveScreen(id: string, screenId: string): string {
            const unavailable = root.wmUnavailable(
                "moveWindowToScreen", "moving a window to a screen")
            if (unavailable !== "") return unavailable
            const window = root.wmEntry(Wm.windows, id)
            if (!window)
                return root.wmFailure("unknown window " + id)
            const screen = root.wmEntry(Wm.screens, screenId)
            if (!screen)
                return root.wmFailure("unknown screen " + screenId)
            return root.wmAction("moveWindowToScreen",
                "moving a window to a screen", () =>
                    Wm.moveWindowToScreen(window.id, screen.id))
        }
    }
}
