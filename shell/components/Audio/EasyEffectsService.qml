pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Small CLI-backed Easy Effects integration. The service is intentionally
// optional: systems without Easy Effects keep the normal audio mixer intact.
Singleton {
    id: root

    property bool initialized: false
    property bool available: false
    property bool serviceReady: false
    property bool bypassed: false
    property bool popupVisible: false
    property var outputPresets: []
    property var inputPresets: []
    property string activeOutputPreset: ""
    property string activeInputPreset: ""
    property string error: ""
    readonly property bool checking: availabilityCheck.running
    readonly property bool busy: bypassToggle.running || presetLoader.running

    function initialize() {
        if (initialized)
            return
        initialized = true
        availabilityCheck.running = true
    }

    function refresh() {
        initialize()
        if (!available) {
            if (!availabilityCheck.running)
                availabilityCheck.running = true
            return
        }
        if (!bypassQuery.running)
            bypassQuery.running = true
        if (!presetQuery.running)
            presetQuery.running = true
        if (!activePresetQuery.running)
            activePresetQuery.running = true
    }

    function toggleBypass() {
        if (!available || !serviceReady || busy)
            return
        error = ""
        bypassToggle.command = ["easyeffects", "--bypass-toggle"]
        bypassToggle.running = true
    }

    function loadOutputPreset(name) {
        loadPreset(String(name), true)
    }

    function loadInputPreset(name) {
        loadPreset(String(name), false)
    }

    function loadPreset(name, output) {
        if (!available || !serviceReady || busy || name === "")
            return
        error = ""
        if (output)
            activeOutputPreset = name
        else
            activeInputPreset = name
        presetLoader.command = ["easyeffects", "-l", name]
        presetLoader.running = true
    }

    function openApp() {
        if (available) {
            Quickshell.execDetached(["easyeffects"])
            appStartDelay.restart()
        }
    }

    function parsePresets(text) {
        let section = ""
        let outputs = []
        let inputs = []
        for (const rawLine of String(text).split("\n")) {
            const line = rawLine.trim()
            const lower = line.toLowerCase()
            if (lower.indexOf("no output presets") >= 0) {
                section = ""
                continue
            }
            if (lower.indexOf("no input presets") >= 0) {
                section = ""
                continue
            }
            if (lower.indexOf("output") >= 0
                    && lower.indexOf("preset") >= 0) {
                section = "output"
                const colon = line.indexOf(":")
                if (colon >= 0 && line.slice(colon + 1).trim() !== "")
                    outputs = outputs.concat(line.slice(colon + 1).split(",")
                        .map(value => value.trim()).filter(value => value !== ""))
                continue
            }
            if (lower.indexOf("input") >= 0
                    && lower.indexOf("preset") >= 0) {
                section = "input"
                const colon = line.indexOf(":")
                if (colon >= 0 && line.slice(colon + 1).trim() !== "")
                    inputs = inputs.concat(line.slice(colon + 1).split(",")
                        .map(value => value.trim()).filter(value => value !== ""))
                continue
            }
            if (line !== "") {
                if (section === "output") outputs.push(line)
                else if (section === "input") inputs.push(line)
            }
        }
        outputPresets = outputs
        inputPresets = inputs
    }

    function parseActivePresets(text) {
        for (const rawLine of String(text).split("\n")) {
            const line = rawLine.trim()
            const colon = line.indexOf(":")
            if (colon < 0)
                continue
            const kind = line.slice(0, colon).trim().toLowerCase()
            const name = line.slice(colon + 1).trim()
            if (kind === "output") activeOutputPreset = name
            else if (kind === "input") activeInputPreset = name
        }
    }

    Process {
        id: availabilityCheck
        command: ["sh", "-c", "command -v easyeffects >/dev/null 2>&1"]
        onExited: exitCode => {
            root.available = exitCode === 0
            if (root.available)
                root.refresh()
        }
    }

    Process {
        id: bypassQuery
        command: ["env", "LANG=C.UTF-8", "LC_ALL=C.UTF-8",
            "easyeffects", "-b", "3"]
        stdout: StdioCollector {
            onStreamFinished: {
                const value = text.trim()
                root.serviceReady = value !== ""
                if (root.serviceReady)
                    root.bypassed = value === "1"
            }
        }
    }

    Process {
        id: presetQuery
        command: ["env", "LANG=C.UTF-8", "LC_ALL=C.UTF-8",
            "easyeffects", "-p"]
        stdout: StdioCollector {
            onStreamFinished: root.parsePresets(text)
        }
    }

    Process {
        id: activePresetQuery
        // Current Easy Effects uses -s for both input and output presets.
        command: ["env", "LANG=C.UTF-8", "LC_ALL=C.UTF-8",
            "easyeffects", "-s"]
        stdout: StdioCollector {
            onStreamFinished: root.parseActivePresets(text)
        }
    }

    Process {
        id: bypassToggle
        onExited: exitCode => {
            if (exitCode !== 0)
                root.error = "Could not change the Easy Effects bypass state."
            refreshDelay.restart()
        }
    }

    Process {
        id: presetLoader
        onExited: exitCode => {
            if (exitCode !== 0)
                root.error = "Could not load the Easy Effects preset."
            refreshDelay.restart()
        }
    }

    Timer {
        id: refreshDelay
        interval: 150
        onTriggered: root.refresh()
    }

    Timer {
        id: appStartDelay
        interval: 1200
        onTriggered: root.refresh()
    }

    Timer {
        interval: 5000
        repeat: true
        running: root.available && root.popupVisible
        onTriggered: root.refresh()
    }
}
