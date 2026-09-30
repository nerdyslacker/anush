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
    property var favorites: []
    property bool favoritesDirty: false
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
        // Ask the provider to check first. Missing names then resolve to an
        // empty URL instead of producing an image-provider warning.
        return Quickshell.iconPath(spec, true)
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

    function isFavorite(id) {
        const value = String(id ?? "")
        return value !== "" && favorites.indexOf(value) !== -1
    }

    function toggleFavorite(id) {
        const value = String(id ?? "")
        if (value === "")
            return
        const next = favorites.slice()
        const index = next.indexOf(value)
        if (index === -1)
            next.push(value)
        else
            next.splice(index, 1)
        favorites = next
        favoritesDirty = true
    }

    function saveFavorites() {
        if (!favoritesDirty)
            return
        const saved = favorites.slice()
        favoritesDirty = false
        ShellState.updateSection("launcher", { favorites: saved })
    }

    function loadState() {
        icon = String(ShellState.state.launcher.icon ?? "").trim()
        // An unrelated shell-state update must not replace favorites that were
        // changed while the launcher is still open but not yet persisted.
        if (favoritesDirty)
            return
        const saved = ShellState.state.launcher.favorites
        favorites = Array.isArray(saved)
            ? saved.map(value => String(value)).filter((value, index, values) =>
                value !== "" && values.indexOf(value) === index)
            : []
    }

    IpcHandler {
        target: "launcher"
        function toggle(): void {
            if (BarVisibility.enabled("launcher")) root.centeredRequested()
        }
        function show(): void {
            if (BarVisibility.enabled("launcher")) root.centeredRequested()
        }
        function toggleCentered(): void {
            if (BarVisibility.enabled("launcher")) root.centeredRequested()
        }
    }

    Connections {
        target: ShellState
        function onStateChanged() { root.loadState() }
        function onReadyChanged() { if (ShellState.ready) root.loadState() }
    }

    Component.onCompleted: if (ShellState.ready) loadState()
}
