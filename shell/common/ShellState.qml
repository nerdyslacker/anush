pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    readonly property string shellDir: {
        let value = String(Quickshell.shellDir ?? "")
        if (value.startsWith("file://"))
            value = value.slice(7)
        return value.replace(/\/$/, "")
    }
    readonly property string stateDir: {
        const configured = String(Quickshell.env("ANUSH_STATE_DIR") ?? "")
        if (configured !== "")
            return configured
        const xdg = String(Quickshell.env("XDG_STATE_HOME") ?? "")
        if (xdg !== "")
            return xdg + "/anush"
        return String(Quickshell.env("HOME") ?? "") + "/.local/state/anush"
    }
    readonly property string scriptsDir: shellDir + "/scripts"
    readonly property string bundledStatePath: shellDir + "/states/shell-state.json"
    readonly property string legacyStateDir: {
        const configured = String(Quickshell.env("SKARWM_STATE_DIR") ?? "")
        return configured !== "" ? configured
            : String(Quickshell.env("HOME") ?? "") + "/.config/skarwm"
    }
    readonly property string filePath: stateDir + "/shell-state.json"
    property bool ready: false
    property var state: defaults()

    function defaults() {
        return {
            bar: {
                height: 34, scale: 1.0, backgroundOpacity: 1.0,
                widgets: {}, clusters: {}, showOnAllMonitors: true,
                position: "top"
            },
            weather: { location: "", units: "c" },
            keyboard: { layout: {} },
            tray: { hidden: [] },
            tags: { count: 9, showNumbers: true, dynamicWorkspaces: false },
            pomodoro: { endMs: 0, minutes: 25 },
            theme: {
                accent: "orange", defaultAccent: "brightYellow",
                wallpaperEnabled: false, palette: null
            },
            windowManager: { gap: 8 },
            desktop: { nightLight: false }
        }
    }

    function merged(saved) {
        const next = defaults()
        if (!saved || typeof saved !== "object")
            return next
        for (const section in next) {
            const value = saved[section]
            if (!value || typeof value !== "object")
                continue
            for (const key in next[section]) {
                if (value[key] !== undefined)
                    next[section][key] = value[key]
            }
        }
        return next
    }

    function updateSection(section, values) {
        if (!state[section] || !values || typeof values !== "object")
            return
        const next = JSON.parse(JSON.stringify(state))
        for (const key in values)
            next[section][key] = values[key]
        const serialized = JSON.stringify(next)
        if (serialized === JSON.stringify(state))
            return
        state = next
        stateFile.setText(JSON.stringify(next, null, 2) + "\n")
    }

    Process {
        id: migration
        running: true
        command: [root.scriptsDir + "/migrate-state", root.filePath,
            root.bundledStatePath, root.legacyStateDir]
        onExited: exitCode => {
            if (exitCode !== 0)
                console.warn("shell state migration exited with", exitCode)
            stateFile.reload()
        }
    }

    FileView {
        id: stateFile
        path: root.filePath
        watchChanges: true
        atomicWrites: true
        onFileChanged: reload()
        onLoaded: {
            try {
                root.state = root.merged(JSON.parse(text()))
            } catch (error) {
                console.warn("shell state:", error)
            }
            root.ready = true
        }
        onLoadFailed: if (!migration.running) {
            root.state = root.defaults()
            setText(JSON.stringify(root.state, null, 2) + "\n")
            root.ready = true
        }
    }
}
