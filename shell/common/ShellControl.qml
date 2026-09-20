pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    readonly property int protocolVersion: 1
    readonly property string cliVersion: "0.1.0"

    IpcHandler {
        target: "anush"

        function ping(): string { return "anush" }

        function status(): string {
            return JSON.stringify({
                name: "anush",
                version: root.cliVersion,
                protocol: root.protocolVersion,
                ready: ShellState.ready,
                themeMode: String(ShellState.state?.theme?.mode ?? "dark"),
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
            ShellState.updateSection("theme", { mode: mode })
            return true
        }
    }
}
