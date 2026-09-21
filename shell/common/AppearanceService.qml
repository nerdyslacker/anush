pragma Singleton

import QtQuick
import ".."
import Quickshell
import Quickshell.Io

// Discovers desktop themes and applies explicit user choices. An empty saved
// value means Anush leaves the pre-existing desktop setting alone.
Singleton {
    id: root

    property var iconThemes: []
    property var cursorThemes: []
    property string iconTheme: ""
    property string cursorTheme: ""
    property var _iconsFound: []
    property var _cursorsFound: []
    property bool _ensured: false

    function refresh() {
        iconLister.running = false
        cursorLister.running = false
        iconLister.running = true
        cursorLister.running = true
        if (iconTheme === "") iconCurrent.running = true
        if (cursorTheme === "") cursorCurrent.running = true
    }

    function loadState() {
        const state = ShellState.state.theme
        const savedIcon = String(state.iconTheme ?? "")
        const savedCursor = String(state.cursorTheme ?? "")
        if (savedIcon !== "") iconTheme = savedIcon
        if (savedCursor !== "") cursorTheme = savedCursor
    }

    function ensureThemes(accent) {
        loadState()
        if (_ensured) return
        _ensured = true
        if (iconTheme !== "")
            Quickshell.execDetached([ShellState.scriptsDir + "/apply-icon-theme",
                "--set", iconTheme, String(accent)])
        if (cursorTheme !== "")
            Quickshell.execDetached([ShellState.scriptsDir + "/apply-cursor-theme",
                "--set", cursorTheme])
    }

    function setIconTheme(name, accent) {
        const selected = String(name ?? "")
        if (selected === "") return
        iconTheme = selected
        ShellState.updateSection("theme", { iconTheme: selected })
        Quickshell.execDetached([ShellState.scriptsDir + "/apply-icon-theme",
            "--set", selected, String(accent)])
    }

    function setCursorTheme(name) {
        const selected = String(name ?? "")
        if (selected === "") return
        cursorTheme = selected
        ShellState.updateSection("theme", { cursorTheme: selected })
        Quickshell.execDetached([ShellState.scriptsDir + "/apply-cursor-theme",
            "--set", selected])
    }

    function applyAccent(accent) {
        if (iconTheme !== "")
            Quickshell.execDetached([ShellState.scriptsDir + "/apply-icon-theme",
                "--accent", iconTheme, String(accent)])
    }

    Process {
        id: iconLister
        command: [ShellState.scriptsDir + "/apply-icon-theme", "--list"]
        stdout: SplitParser {
            onRead: line => {
                const value = line.trim()
                if (value !== "") root._iconsFound.push(value)
            }
        }
        onRunningChanged: {
            if (running) root._iconsFound = []
            else {
                if (root.iconTheme !== ""
                        && root._iconsFound.indexOf(root.iconTheme) < 0)
                    root._iconsFound.push(root.iconTheme)
                root.iconThemes = root._iconsFound.sort((a, b) =>
                    a.localeCompare(b))
            }
        }
    }

    Process {
        id: cursorLister
        command: [ShellState.scriptsDir + "/apply-cursor-theme", "--list"]
        stdout: SplitParser {
            onRead: line => {
                const value = line.trim()
                if (value !== "") root._cursorsFound.push(value)
            }
        }
        onRunningChanged: {
            if (running) root._cursorsFound = []
            else {
                if (root.cursorTheme !== ""
                        && root._cursorsFound.indexOf(root.cursorTheme) < 0)
                    root._cursorsFound.push(root.cursorTheme)
                root.cursorThemes = root._cursorsFound.sort((a, b) =>
                    a.localeCompare(b))
            }
        }
    }

    Process {
        id: iconCurrent
        command: [ShellState.scriptsDir + "/apply-icon-theme", "--current"]
        stdout: StdioCollector {
            onStreamFinished: {
                const value = text.trim()
                if (root.iconTheme === "" && value !== "")
                    root.iconTheme = value
            }
        }
    }

    Process {
        id: cursorCurrent
        command: [ShellState.scriptsDir + "/apply-cursor-theme", "--current"]
        stdout: StdioCollector {
            onStreamFinished: {
                const value = text.trim()
                if (root.cursorTheme === "" && value !== "")
                    root.cursorTheme = value
            }
        }
    }

    Connections {
        target: ShellState
        function onStateChanged() { root.loadState() }
        function onReadyChanged() {
            if (ShellState.ready) {
                root.loadState()
                root.refresh()
            }
        }
    }

    Component.onCompleted: if (ShellState.ready) {
        loadState()
        refresh()
    }
}
