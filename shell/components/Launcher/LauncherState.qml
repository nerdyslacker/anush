pragma Singleton

import QtQuick
import "../.."
import Quickshell
import Quickshell.Io

// One IPC endpoint fans the request out to the launcher attached to each bar.
// Each instance then checks whether its screen is the focused skarwm output.
Singleton {
    id: root

    readonly property string defaultGlyph: "󰀻"
    property string icon: ""
    signal centeredRequested()

    function resolveIcon(value) {
        const spec = String(value ?? "").trim()
        if (spec === "" || spec.startsWith("glyph:"))
            return ""
        if (spec.startsWith("file://"))
            return spec
        if (spec.startsWith("/"))
            return "file://" + spec
        // Paths containing a slash are portable paths relative to anush's
        // writable config directory; bare values are icon-theme names.
        if (spec.indexOf("/") !== -1) {
            const relative = spec.replace(/^\.\//, "")
            return "file://" + Theme.configDir + "/" + relative
        }
        return Quickshell.iconPath(spec, "")
    }

    function displayGlyph(value) {
        const spec = String(value ?? "").trim()
        return spec.startsWith("glyph:") ? spec.slice(6) : defaultGlyph
    }

    function setIcon(value) {
        const next = String(value ?? "").trim()
        icon = next
        ShellState.updateSection("launcher", { icon: next })
    }

    function resetIcon() { setIcon("") }

    function loadState() {
        icon = String(ShellState.state.launcher.icon ?? "").trim()
    }

    IpcHandler {
        target: "launcher"
        function toggle(): void { root.centeredRequested() }
        function show(): void { root.centeredRequested() }
        function toggleCentered(): void { root.centeredRequested() }
    }

    Connections {
        target: ShellState
        function onStateChanged() { root.loadState() }
        function onReadyChanged() { if (ShellState.ready) root.loadState() }
    }

    Component.onCompleted: if (ShellState.ready) loadState()
}
