pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Optional tmux integration shared by every bar. All tmux arguments are passed
// as argv entries; session names never pass through shell interpolation.
Singleton {
    id: root

    property bool initialized: false
    property bool available: false
    property bool popupVisible: false
    property var sessions: []
    property string error: ""
    property string _pendingCreatedSession: ""
    property string _actionError: ""
    readonly property bool checking: availabilityCheck.running
    readonly property bool busy: createProcess.running || renameProcess.running
        || killProcess.running

    function initialize() {
        if (initialized)
            return
        initialized = true
        availabilityCheck.running = true
    }

    function refresh() {
        initialize()
        if (available && !sessionList.running)
            sessionList.running = true
    }

    function validName(value) {
        const name = String(value ?? "").trim()
        return name !== "" && name.indexOf(":") < 0 && name.indexOf(".") < 0
    }

    function createSession(value) {
        const name = String(value ?? "").trim()
        if (!validName(name)) {
            error = "Session names cannot be empty or contain ':' or '.'."
            return false
        }
        if (busy)
            return false
        error = ""
        _actionError = ""
        _pendingCreatedSession = name
        createProcess.command = ["tmux", "new-session", "-d", "-s", name]
        createProcess.running = true
        return true
    }

    function attachSession(value) {
        const name = String(value ?? "")
        if (!validName(name))
            return
        openTerminal(["tmux", "attach-session", "-t", name])
    }

    function renameSession(oldValue, newValue) {
        const oldName = String(oldValue ?? "")
        const newName = String(newValue ?? "").trim()
        if (!validName(oldName) || !validName(newName)) {
            error = "Session names cannot be empty or contain ':' or '.'."
            return false
        }
        if (oldName === newName)
            return true
        if (busy)
            return false
        error = ""
        _actionError = ""
        renameProcess.command = ["tmux", "rename-session", "-t",
            oldName, newName]
        renameProcess.running = true
        return true
    }

    function killSession(value) {
        const name = String(value ?? "")
        if (!validName(name) || busy)
            return false
        error = ""
        _actionError = ""
        killProcess.command = ["tmux", "kill-session", "-t", name]
        killProcess.running = true
        return true
    }

    function openTerminal(arguments) {
        const script =
            "unset TMUX; " +
            "config=${ANUSH_CONFIG_DIR:-${XDG_CONFIG_HOME:-$HOME/.config}/anush/config}; " +
            "if [ -n \"${TERMINAL:-}\" ] && command -v \"$TERMINAL\" >/dev/null 2>&1; then " +
            "if [ \"${TERMINAL##*/}\" = kitty ]; then " +
            "exec \"$TERMINAL\" --config \"$config/kitty/kitty.conf\" -- \"$@\"; " +
            "else exec \"$TERMINAL\" -e \"$@\"; fi; " +
            "elif command -v kitty >/dev/null 2>&1; then " +
            "exec kitty --config \"$config/kitty/kitty.conf\" -- \"$@\"; " +
            "elif command -v foot >/dev/null 2>&1; then exec foot -- \"$@\"; " +
            "elif command -v alacritty >/dev/null 2>&1; then exec alacritty -e \"$@\"; " +
            "elif command -v wezterm >/dev/null 2>&1; then exec wezterm start -- \"$@\"; " +
            "elif command -v xterm >/dev/null 2>&1; then exec xterm -e \"$@\"; " +
            "else command -v notify-send >/dev/null 2>&1 && " +
            "notify-send -u critical 'Anush tmux' 'No supported terminal was found.'; exit 127; fi"
        Quickshell.execDetached(["sh", "-c", script, "anush-tmux"].concat(arguments))
    }

    function actionFinished(exitCode, verb) {
        if (exitCode !== 0)
            error = _actionError !== "" ? _actionError
                : "Could not " + verb + " the tmux session."
        refreshDelay.restart()
    }

    Process {
        id: availabilityCheck
        command: ["sh", "-c", "command -v tmux >/dev/null 2>&1"]
        onExited: exitCode => {
            root.available = exitCode === 0
            if (root.available) root.refresh()
            else root.sessions = []
        }
    }

    Process {
        id: sessionList
        command: ["tmux", "list-sessions", "-F",
            "#{session_name}\t#{session_windows}\t#{session_attached}\t#{session_created}"]
        stdout: StdioCollector {
            onStreamFinished: {
                let result = []
                for (const line of text.trim().split("\n")) {
                    if (line.trim() === "") continue
                    const fields = line.split("\t")
                    if (fields.length < 4) continue
                    result.push({
                        name: fields[0],
                        windows: Number(fields[1]) || 0,
                        attached: Number(fields[2]) || 0,
                        created: Number(fields[3]) || 0
                    })
                }
                root.sessions = result
            }
        }
        onExited: exitCode => {
            // tmux exits nonzero when no server exists; that is an empty list,
            // not an error requiring user action.
            if (exitCode !== 0) root.sessions = []
        }
    }

    Process {
        id: createProcess
        stderr: StdioCollector {
            onStreamFinished: root._actionError = text.trim()
        }
        onExited: exitCode => {
            if (exitCode === 0 && root._pendingCreatedSession !== "")
                root.attachSession(root._pendingCreatedSession)
            root._pendingCreatedSession = ""
            root.actionFinished(exitCode, "create")
        }
    }

    Process {
        id: renameProcess
        stderr: StdioCollector {
            onStreamFinished: root._actionError = text.trim()
        }
        onExited: exitCode => root.actionFinished(exitCode, "rename")
    }

    Process {
        id: killProcess
        stderr: StdioCollector {
            onStreamFinished: root._actionError = text.trim()
        }
        onExited: exitCode => root.actionFinished(exitCode, "kill")
    }

    Timer {
        id: refreshDelay
        interval: 200
        onTriggered: root.refresh()
    }

    Timer {
        interval: 5000
        repeat: true
        running: root.available && root.popupVisible
        onTriggered: root.refresh()
    }
}
