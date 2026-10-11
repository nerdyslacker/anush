pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import "../.."

Singleton {
    id: root

    readonly property string helperPath: Theme.scriptsDir + "/skarwm/config-editor"
    property var document: ({ settings: {}, barBlocks: [], autostart: [],
        bindings: [], rules: [], workspaceLayouts: [], virtualScreens: [], extras: [] })
    property var pending: clone(document)
    property bool loading: false
    property bool saving: false
    property string error: ""
    property string status: ""
    signal saved()

    function clone(value) { return JSON.parse(JSON.stringify(value)) }

    function refresh() {
        if (loading || saving) return
        loading = true
        error = ""
        status = ""
        readProcess.running = false
        readProcess.running = true
    }

    function resetPending() {
        pending = clone(document)
        error = ""
        status = ""
    }

    function setSetting(key, value) {
        const next = clone(pending)
        next.settings[key] = value
        if (!next._fileSettings) next._fileSettings = {}
        if (!next._fileSettings[next.path]) next._fileSettings[next.path] = {}
        next._fileSettings[next.path][key] = value
        pending = next
        error = ""
    }

    function list(name) { return pending[name] ?? [] }

    function updateItem(name, index, values) {
        const next = clone(pending)
        if (!Array.isArray(next[name]) || index < 0 || index >= next[name].length) return
        if (values !== null && typeof values === "object")
            for (const key in values) next[name][index][key] = values[key]
        else
            next[name][index] = values
        pending = next
        error = ""
    }

    function addItem(name, value) {
        const next = clone(pending)
        if (!Array.isArray(next[name])) next[name] = []
        if (value !== null && typeof value === "object") {
            const item = clone(value)
            item._source = next.path
            next[name].push(item)
        } else {
            next[name].push(value)
            if (name === "autostart" || name === "extras") {
                if (!next._owners) next._owners = {}
                if (!Array.isArray(next._owners[name])) next._owners[name] = []
                next._owners[name].push(next.path)
            }
        }
        pending = next
        error = ""
    }

    function removeItem(name, index) {
        const next = clone(pending)
        if (!Array.isArray(next[name]) || index < 0 || index >= next[name].length) return
        next[name].splice(index, 1)
        if ((name === "autostart" || name === "extras") && next._owners
                && Array.isArray(next._owners[name]))
            next._owners[name].splice(index, 1)
        pending = next
        error = ""
    }

    function saveAndReload() {
        if (saving || loading) return
        saving = true
        error = ""
        status = "Saving and reloading skarwm…"
        saveProcess.payload = JSON.stringify(pending) + "\n"
        saveProcess.stdinEnabled = true
        saveProcess.running = true
    }

    function accept(text, operation) {
        try {
            const result = JSON.parse(text)
            if (result.success !== true) throw new Error(result.error ?? operation + " failed")
            document = result.document
            pending = clone(document)
            error = ""
            status = operation === "save" ? "Saved and reloaded" : ""
            if (operation === "save") saved()
        } catch (failure) {
            error = String(failure)
            status = ""
        }
    }

    Process {
        id: readProcess
        command: [root.helperPath, "read"]
        stdout: StdioCollector {
            waitForEnd: true
            onStreamFinished: root.accept(text, "read")
        }
        stderr: StdioCollector { id: readError; waitForEnd: true }
        onExited: code => {
            root.loading = false
            if (code !== 0 && root.error === "")
                root.error = readError.text.trim() || "Could not read skarwm configuration"
        }
    }

    Process {
        id: saveProcess
        property string payload: ""
        command: [root.helperPath, "save-reload"]
        stdinEnabled: true
        stdout: StdioCollector {
            id: saveOutput
            waitForEnd: true
            onStreamFinished: root.accept(text, "save")
        }
        stderr: StdioCollector { id: saveError; waitForEnd: true }
        onStarted: {
            write(payload)
            payload = ""
            stdinEnabled = false
        }
        onExited: code => {
            stdinEnabled = true
            root.saving = false
            if (code !== 0 && root.error === "")
                root.error = saveError.text.trim() || "Could not save skarwm configuration"
        }
    }

    Component.onCompleted: refresh()
}
