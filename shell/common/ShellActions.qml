pragma Singleton

import QtQuick
import ".."
import Quickshell
import Quickshell.Io

// Own the shell-wide IPC names exactly once. Bar widgets are instantiated for
// every output, so putting IpcHandler directly in a popup makes later copies
// lose registration. Requests are broadcast here and the popup attached to
// skarwm's focused output handles them.
Singleton {
    id: root

    readonly property int protocolVersion: 1
    signal networkRequested(string action)
    signal bluetoothRequested(string action)
    signal commandsRequested(string action)
    signal weatherRequested(string action)
    signal wallpaperRequested(string action, string path)
    signal layoutsRequested(string action)

    function ownsFocusedOutput(anchorItem) {
        if (!anchorItem)
            return true

        const window = anchorItem.QsWindow.window
        const screen = window ? window.screen : null
        const focused = Wm.focusedOutput
        if (screen && focused && String(focused.name ?? "") !== "")
            return String(screen.name ?? "") === String(focused.name)

        // Wm may still be collecting its first output snapshot. Pick one
        // deterministic bar instead of making every monitor handle the call.
        return !screen || Quickshell.screens.length === 0
            || screen === Quickshell.screens[0]
    }

    IpcHandler {
        target: "network"
        function toggle(): void { root.networkRequested("toggle") }
        function open(): void { root.networkRequested("open") }
        function close(): void { root.networkRequested("close") }
    }

    IpcHandler {
        target: "bluetooth"
        function toggle(): void { root.bluetoothRequested("toggle") }
        function open(): void { root.bluetoothRequested("open") }
        function close(): void { root.bluetoothRequested("close") }
    }

    IpcHandler {
        target: "commands"
        function toggle(): void { root.commandsRequested("toggle") }
    }

    IpcHandler {
        target: "weather"
        function toggle(): void { root.weatherRequested("toggle") }
    }

    IpcHandler {
        target: "wallpapers"
        function toggle(): void { root.wallpaperRequested("toggle", "") }
        function random(): void { root.wallpaperRequested("random", "") }
        function set(path: string): void { root.wallpaperRequested("set", path) }
    }

    IpcHandler {
        target: "layouts"
        function toggle(): void { root.layoutsRequested("toggle") }
    }
}
