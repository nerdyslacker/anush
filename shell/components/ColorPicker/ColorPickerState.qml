pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import "../.."

Singleton {
    id: root

    property string currentColor: ""
    property var history: []
    property bool picking: false
    property bool available: true
    property string errorMessage: ""
    property string statusMessage: ""
    property string clipboardBeforePick: ""
    property string pendingPickerOutput: ""
    property int resultAttempts: 0

    signal picked(string color)

    function initialize() {
        if (ShellState.ready)
            loadState()
    }

    function normalize(value) {
        const candidate = String(value ?? "").trim()
        const match = candidate.match(/^#?([0-9a-fA-F]{6})$/)
        return match ? ("#" + match[1]).toUpperCase() : ""
    }

    function finishPick(color) {
        resultRetry.stop()
        pendingPickerOutput = ""
        resultAttempts = 0
        remember(color)
        // Keep the selection alive after xcolor exits, including on systems
        // without a clipboard manager.
        Quickshell.clipboardText = color
        errorMessage = ""
        statusMessage = color + " copied"
        picked(color)
    }

    function resolvePickResult() {
        const outputColor = normalize(pendingPickerOutput)
        if (outputColor !== "") {
            finishPick(outputColor)
            return
        }

        const clipboardText = String(Quickshell.clipboardText ?? "").trim()
        const clipboardColor = normalize(clipboardText)
        if (clipboardColor !== "" && clipboardText !== clipboardBeforePick) {
            finishPick(clipboardColor)
            return
        }

        resultAttempts++
        if (resultAttempts < 5) {
            resultRetry.restart()
            return
        }

        // Selecting the same pixel twice may not emit a clipboard change.
        if (clipboardColor !== "") {
            finishPick(clipboardColor)
            return
        }
        pendingPickerOutput = ""
        errorMessage = "Could not read the picked color"
        statusMessage = ""
    }

    function loadState() {
        if (!ShellState.ready)
            return
        const saved = ShellState.state.colorPicker
        const next = []
        const values = Array.isArray(saved?.history) ? saved.history : []
        for (const value of values) {
            const normalized = normalize(value)
            if (normalized !== "" && next.indexOf(normalized) < 0)
                next.push(normalized)
            if (next.length >= 12)
                break
        }
        history = next
        const savedCurrent = normalize(saved?.current)
        currentColor = savedCurrent !== "" ? savedCurrent
            : next.length > 0 ? next[0] : ""
    }

    function persist() {
        ShellState.updateSection("colorPicker", {
            current: currentColor,
            history: history
        })
    }

    function remember(value) {
        const color = normalize(value)
        if (color === "")
            return false
        const next = [color]
        for (const existing of history) {
            const normalized = normalize(existing)
            if (normalized !== "" && normalized !== color)
                next.push(normalized)
            if (next.length >= 12)
                break
        }
        currentColor = color
        history = next
        persist()
        return true
    }

    function copy(value) {
        const color = normalize(value)
        if (!remember(color))
            return
        Quickshell.clipboardText = color
        errorMessage = ""
        statusMessage = color + " copied"
    }

    function clearHistory() {
        if (history.length === 0)
            return
        history = []
        persist()
        errorMessage = ""
        statusMessage = "Color history cleared"
    }

    function pick() {
        if (picking)
            return
        resultRetry.stop()
        if (!available) {
            errorMessage = "xcolor is not installed"
            statusMessage = ""
            return
        }
        errorMessage = ""
        statusMessage = "Select a pixel anywhere on screen"
        clipboardBeforePick = String(Quickshell.clipboardText ?? "").trim()
        pendingPickerOutput = ""
        resultAttempts = 0
        picking = true
        picker.running = true
    }

    IpcHandler {
        target: "colorPicker"
        function pick(): void { root.pick() }
        function copy(color: string): void { root.copy(color) }
        function clear(): void { root.clearHistory() }
    }

    Process {
        id: availabilityCheck
        running: true
        command: ["which", "xcolor"]
        onExited: exitCode => root.available = exitCode === 0
    }

    Process {
        id: picker
        command: ["xcolor", "--format", "hex", "--selection", "clipboard"]
        stdout: StdioCollector { id: pickerOutput }
        stderr: StdioCollector { id: pickerError }
        onExited: exitCode => {
            root.picking = false
            if (exitCode !== 0) {
                const detail = pickerError.text.trim()
                root.errorMessage = detail !== "" ? detail : ""
                root.statusMessage = detail === "" ? "Picking cancelled" : ""
                return
            }
            root.pendingPickerOutput = pickerOutput.text
            root.resolvePickResult()
        }
    }

    Timer {
        id: resultRetry
        interval: 100
        repeat: false
        onTriggered: root.resolvePickResult()
    }

    Connections {
        target: ShellState
        function onReadyChanged() {
            if (ShellState.ready)
                root.loadState()
        }
    }

    Component.onCompleted: if (ShellState.ready) loadState()
}
