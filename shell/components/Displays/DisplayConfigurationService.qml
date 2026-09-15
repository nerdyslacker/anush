pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import "../.."

// Backend-neutral staged display model. The current backend is XRandR; UI
// components only consume normalized output objects and these operations.
Singleton {
    id: root

    readonly property string backendPath: Theme.scriptsDir + "/display-config"
    property string backend: ""
    property bool supportsMirroring: false
    property bool supportsPrimary: false
    property var currentOutputs: []
    property var pendingOutputs: []
    property bool loading: false
    property bool applying: false
    property bool confirmationPending: false
    property int secondsRemaining: 0
    property string rollbackToken: ""
    property string error: ""
    signal applied()
    signal reverted()

    function clone(value) { return JSON.parse(JSON.stringify(value)) }

    function refresh() {
        if (applying || confirmationPending) return
        loading = true
        error = ""
        query.running = false
        query.running = true
    }

    function resetPending() {
        pendingOutputs = clone(currentOutputs)
        error = ""
    }

    function output(name) {
        return pendingOutputs.find(item => item.name === name) ?? null
    }

    function updateOutput(name, values) {
        const next = clone(pendingOutputs)
        const index = next.findIndex(item => item.name === name)
        if (index < 0) return
        for (const key in values) next[index][key] = values[key]
        pendingOutputs = next
        error = ""
    }

    function setPrimary(name) {
        const next = clone(pendingOutputs)
        for (const item of next) item.primary = item.name === name
        pendingOutputs = next
    }

    function validate() {
        if (pendingOutputs.filter(item => item.enabled).length === 0)
            return "At least one display must remain enabled."
        for (const item of pendingOutputs) {
            if (!item.enabled) continue
            if (!item.modes.some(mode => mode.width === item.width
                    && mode.height === item.height
                    && Math.abs(mode.refreshRate - item.refreshRate) < 0.001))
                return "Choose a supported mode for " + item.name + "."
        }
        return ""
    }

    function apply() {
        error = validate()
        if (error !== "") return
        applying = true
        applyProcess.command = [backendPath, "apply", JSON.stringify(pendingOutputs)]
        applyProcess.running = true
    }

    function keep() {
        if (!confirmationPending) return
        keepProcess.command = [backendPath, "keep", rollbackToken]
        keepProcess.running = true
        confirmationPending = false
        countdown.stop()
        currentOutputs = clone(pendingOutputs)
        applied()
        refreshDelay.restart()
    }

    function revert() {
        if (!confirmationPending) return
        revertProcess.command = [backendPath, "revert", rollbackToken]
        revertProcess.running = true
        confirmationPending = false
        countdown.stop()
        reverted()
        refreshDelay.restart()
    }

    Process {
        id: query
        command: [root.backendPath, "list"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const data = JSON.parse(text)
                    if (data.success === false) throw new Error(data.error)
                    root.backend = String(data.backend ?? "")
                    root.supportsMirroring = data.supportsMirroring === true
                    root.supportsPrimary = data.supportsPrimary === true
                    root.currentOutputs = Array.isArray(data.outputs) ? data.outputs : []
                    root.resetPending()
                } catch (failure) {
                    root.error = String(failure)
                }
                root.loading = false
            }
        }
    }

    Process {
        id: applyProcess
        stdout: StdioCollector {
            onStreamFinished: {
                root.applying = false
                try {
                    const data = JSON.parse(text)
                    if (data.success !== true) throw new Error(data.error ?? "Display apply failed")
                    root.rollbackToken = String(data.token)
                    root.secondsRemaining = Number(data.timeout) || 15
                    root.confirmationPending = true
                    countdown.restart()
                } catch (failure) {
                    root.error = String(failure)
                }
            }
        }
    }

    Process { id: keepProcess }
    Process { id: revertProcess }

    Timer {
        id: countdown
        interval: 1000
        repeat: true
        onTriggered: {
            root.secondsRemaining--
            if (root.secondsRemaining <= 0) root.revert()
        }
    }
    Timer { id: refreshDelay; interval: 700; onTriggered: root.refresh() }
    Timer { id: hotplugDelay; interval: 250; onTriggered: root.refresh() }
    Connections {
        target: Wm
        function onOutputsChanged() { hotplugDelay.restart() }
    }
    Component.onCompleted: refresh()
}
