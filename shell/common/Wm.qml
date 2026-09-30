pragma Singleton
import QtQuick
import ".."
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    property var workspaces: []
    property var windows: []
    property var outputs: []
    property var lastFocusedWindowByOutput: ({})
    property var registeredScratchpads: []
    signal overviewCommand(string action)
    signal uiEvent(var event)
    signal physicalOutputConnected()
    signal physicalOutputDisconnected()
    property int tagCount: 1
    readonly property int dynamicTagCount: {
        let highestOccupied = 0
        let focused = 1
        for (const ws of workspaces) {
            const id = Math.max(1, Number(ws.id) || 1)
            if (ws.windows > 0)
                highestOccupied = Math.max(highestOccupied, id)
            if (ws.focused)
                focused = id
        }
        return Math.max(1, focused, highestOccupied + 1)
    }
    property string title: ""
    property string activeWinId: ""
    readonly property string msgPath: "skarwm-msg"

    readonly property var layouts: [
        { name: "Scrolling Tile", glyph: "󰙀", command: "scrolling-tile" },
        { name: "Vertical Scroller", glyph: "󱥣", command: "vertical-scrolling-tile" },
        { name: "Tabbed", glyph: "󰓩", command: "tabbed" },
        { name: "Dwindle", glyph: "󰕮", command: "dwindle" },
        { name: "Monocle", glyph: "󰍹", command: "monocle" },
        { name: "Floating", glyph: "󰕰", command: "floating" }
    ]
    readonly property var workspaceLayoutCommands: [
        "scrolling-tile", "vertical-scrolling-tile", "dwindle", "monocle", "floating"
    ]
    readonly property var focusedWindow: {
        for (const win of windows)
            if (win.focused && !win.dock) return win
        return null
    }
    readonly property var focusedOutput: {
        for (const output of outputs)
            if (output.focused) return output
        return outputs.length > 0 ? outputs[0] : null
    }
    readonly property var focusedWorkspace: {
        for (const ws of workspaces)
            if (ws.focused === true) return ws
        return null
    }
    readonly property string workspaceLayout: String(
        focusedWorkspace?.layout ?? "scrolling-tile")
    readonly property int layoutIndex: {
        if (workspaceLayout === "scrolling-tile"
                && focusedWindow?.column_layout === "tabbed")
            return layouts.findIndex(layout => layout.command === "tabbed")
        const index = layouts.findIndex(layout => layout.command === workspaceLayout)
        return index >= 0 ? index : 0
    }
    property int gaps: 8
    property bool decorationsEnabled: false
    property bool decorationStateLoaded: false
    property bool picomAvailable: false
    property bool picomEnabled: false
    property bool picomBusy: false

    function outputNameForScreen(screen) {
        const nativeName = String(screen?.name ?? "")
        for (const output of outputs)
            if (String(output.name ?? "") === nativeName)
                return nativeName

        if (screen) {
            const x = Number(screen.x)
            const y = Number(screen.y)
            const width = Number(screen.width)
            const height = Number(screen.height)
            for (const output of outputs) {
                const rect = output.rect
                if (rect && Number(rect.x) === x && Number(rect.y) === y
                        && Number(rect.width) === width
                        && Number(rect.height) === height)
                    return String(output.name ?? nativeName)
            }
        }

        if (outputs.length === 1)
            return String(outputs[0].name ?? nativeName)
        return nativeName
    }

    function workspaceAt(index, outputName) {
        const id = index + 1
        for (const ws of workspaces)
            if (Number(ws.id) === id
                    && (!outputName || String(ws.output) === String(outputName))) return ws
        return null
    }
    function isSelected(index, outputName) {
        const ws = workspaceAt(index, outputName)
        return ws !== null && (outputName ? ws.visible === true : ws.focused === true)
    }
    function isOccupied(index, outputName) {
        const ws = workspaceAt(index, outputName)
        return ws !== null && ws.windows > 0
    }
    function isUrgent(index, outputName) {
        const ws = workspaceAt(index, outputName)
        return ws !== null && ws.urgent
    }

    function windowForOutput(outputName) {
        const wantedOutput = String(outputName ?? "")
        if (wantedOutput === "") return null

        let workspace = -1
        for (const output of outputs) {
            if (String(output.name) === wantedOutput) {
                workspace = Number(output.current_workspace)
                break
            }
        }

        const candidates = windows.filter(win => win && !win.dock
            && win.scratchpad !== true
            && String(win.output ?? "") === wantedOutput
            && (workspace < 0 || Number(win.workspace) === workspace))
        if (candidates.length === 0) return null

        const focused = candidates.find(win => win.focused === true)
        if (focused) return focused

        const rememberedId = lastFocusedWindowByOutput[wantedOutput]
        const remembered = candidates.find(win => String(win.id) === String(rememberedId))
        if (remembered) return remembered

        return candidates.find(win => win.tab_active === true) ?? candidates[0]
    }

    function refreshWorkspaces() {
        workspaceQuery.running = false
        workspaceQuery.running = true
    }
    function refreshWindows() {
        windowQuery.running = false
        windowQuery.running = true
    }
    function refreshAll() {
        refreshWorkspaces()
        refreshWindows()
        outputQuery.running = false
        outputQuery.running = true
    }

    function acceptWorkspaces(line) {
        try {
            const value = JSON.parse(line)
            if (!Array.isArray(value)) return
            workspaces = value
            let highest = 1
            for (const ws of value) highest = Math.max(highest, ws.id)
            tagCount = Math.max(1, highest)
        } catch (e) {
            console.warn("skarwm workspace snapshot:", e)
        }
    }

    function acceptWindows(line) {
        try {
            const value = JSON.parse(line)
            if (!value || !Array.isArray(value.windows)) return
            windows = value.windows
            let focused = null
            const scratchpads = []
            for (const win of windows) {
                if (win.focused && !win.dock) { focused = win; break }
            }
            if (focused && focused.output !== null && focused.output !== undefined) {
                const nextFocusedByOutput = Object.assign({}, lastFocusedWindowByOutput)
                nextFocusedByOutput[String(focused.output)] = focused.id
                lastFocusedWindowByOutput = nextFocusedByOutput
            }
            for (const win of windows) {
                const registers = Array.isArray(win.scratchpad_registers)
                    ? win.scratchpad_registers
                    : win.scratchpad_register === null || win.scratchpad_register === undefined
                        ? [] : [win.scratchpad_register]
                for (const register of registers) {
                    scratchpads.push({
                        register: Number(register),
                        id: win.id,
                        title: win.title || win.class || win.instance || "Untitled window",
                        className: win.class || win.instance || "",
                        hidden: win.scratchpad === true,
                        workspace: win.workspace,
                        output: win.output
                    })
                }
            }
            scratchpads.sort((a, b) => a.register - b.register)
            registeredScratchpads = scratchpads
            activeWinId = focused ? "0x" + Number(focused.id).toString(16) : ""
            title = focused ? focused.title : ""
        } catch (e) {
            console.warn("skarwm window snapshot:", e)
        }
    }

    function acceptOutputs(line) {
        try {
            const value = JSON.parse(line)
            if (Array.isArray(value)) outputs = value
        } catch (e) {
            console.warn("skarwm output snapshot:", e)
        }
    }

    Process {
        id: workspaceQuery
        command: [root.msgPath, "get-workspaces"]
        running: true
        stdout: SplitParser { onRead: line => root.acceptWorkspaces(line) }
    }
    Process {
        id: windowQuery
        command: [root.msgPath, "get-windows"]
        running: true
        stdout: SplitParser { onRead: line => root.acceptWindows(line) }
    }
    Process {
        id: outputQuery
        command: [root.msgPath, "get-outputs"]
        running: true
        stdout: SplitParser { onRead: line => root.acceptOutputs(line) }
    }
    Process {
        command: [root.msgPath, "subscribe", "workspace", "window", "output", "ui"]
        running: true
        stdout: SplitParser {
            onRead: line => {
                // The first line is the subscription acknowledgement. Every
                // later event is a cheap invalidation signal; snapshots keep
                // the QML model deterministic even after event bursts.
                try {
                    const event = JSON.parse(line)
                    if (!event || event.change === undefined) return
                    const change = String(event.change)
                    if (change.startsWith("ui-")) {
                        root.uiEvent(event)
                        return
                    }
                    if (change.startsWith("overview-")) {
                        root.overviewCommand(change.slice(9))
                        return
                    }
                    if (change === "connected")
                        root.physicalOutputConnected()
                    else if (change === "disconnected")
                        root.physicalOutputDisconnected()
                    root.refreshAll()
                } catch (e) {
                    console.warn("skarwm event:", e)
                }
            }
        }
    }

    function viewTag(index, outputName) {
        const command = [msgPath, "workspace", String(index + 1)]
        if (outputName) command.push("output", String(outputName))
        Quickshell.execDetached(command)
    }
    function toggleViewTag(index, outputName) { viewTag(index, outputName) }
    function sendToTag(index) {
        Quickshell.execDetached([msgPath, "move", "workspace", String(index + 1)])
    }
    function cycleTag(direction, visibleCount, outputName) {
        const count = Math.max(1, Math.round(Number(visibleCount) || tagCount))
        let current = 0
        for (const ws of workspaces) {
            if ((!outputName && ws.focused)
                    || (outputName && String(ws.output) === String(outputName) && ws.visible)) {
                current = Math.max(0, Number(ws.id) - 1)
                break
            }
        }
        const step = direction > 0 ? 1 : -1
        viewTag((current + step + count) % count, outputName)
    }
    function setLayout(index) {
        const layout = layouts[index]
        if (layout) {
            const command = layout.command === "scrolling-tile"
                    && focusedWindow?.column_layout === "tabbed"
                ? "stacked" : layout.command
            Quickshell.execDetached([msgPath, "layout", command])
        }
    }
    function cycleLayout(direction) {
        let index = workspaceLayoutCommands.indexOf(workspaceLayout)
        if (index < 0) index = 0
        const next = (index + direction + workspaceLayoutCommands.length)
            % workspaceLayoutCommands.length
        Quickshell.execDetached([msgPath, "layout", workspaceLayoutCommands[next]])
    }
    function focusWindow(id) {
        if (id !== undefined && id !== null)
            Quickshell.execDetached([msgPath, "focus", "window", String(id)])
    }
    function setGaps(value, persist) {
        const next = Math.min(40, Math.max(0, Math.round(value)))
        gaps = next
        Quickshell.execDetached([msgPath, "gaps", String(next)])
        if (persist !== false)
            ShellState.updateSection("windowManager", { gap: next })
    }
    function persistGaps(value) {
        const next = Math.min(40, Math.max(0, Math.round(value)))
        gaps = next
        ShellState.updateSection("windowManager", { gap: next })
    }
    function setDecorationsEnabled(enabled) {
        const next = enabled === true
        decorationsEnabled = next
        ShellState.updateSection("windowManager", { decorations: next })
        Quickshell.execDetached([
            ShellState.scriptsDir + "/theme/apply-window-decorations",
            next ? "true" : "false", msgPath
        ])
    }
    function acceptPicomStatus(text) {
        try {
            const value = JSON.parse(String(text ?? ""))
            picomAvailable = value.available === true
            picomEnabled = value.enabled === true
        } catch (error) {
            console.warn("picom status:", error)
        }
    }
    function refreshPicomState() {
        if (picomBusy)
            return
        picomStatus.running = false
        picomStatus.running = true
    }
    function setPicomEnabled(enabled) {
        if (picomBusy)
            return
        picomEnabled = enabled === true
        picomBusy = true
        picomControl.command = [ShellState.scriptsDir + "/theme/picom-control",
            picomEnabled ? "enable" : "disable", msgPath]
        picomControl.running = true
    }
    function toggleScratchpad(register) {
        Quickshell.execDetached([msgPath, "scratchpad", "toggle", String(register)])
    }

    function addReminder(minutes, message) {
        Quickshell.execDetached([
            msgPath, "reminder", "add", String(minutes), String(message)
        ])
    }

    function loadWindowManagerState() {
        const saved = Number(ShellState.state.windowManager.gap)
        if (!isNaN(saved)) {
            root.gaps = Math.min(40, Math.max(0, Math.round(saved)))
            restoreGap.restart()
        }
        const nextDecorations =
            ShellState.state.windowManager.decorations === true
        if (!root.decorationStateLoaded) {
            root.decorationsEnabled = nextDecorations
            root.decorationStateLoaded = true
        } else if (root.decorationsEnabled !== nextDecorations) {
            root.decorationsEnabled = nextDecorations
            Quickshell.execDetached([
                ShellState.scriptsDir + "/theme/apply-window-decorations",
                nextDecorations ? "true" : "false", root.msgPath
            ])
        }
    }

    Connections {
        target: ShellState
        function onStateChanged() { root.loadWindowManagerState() }
        function onReadyChanged() {
            if (ShellState.ready) root.loadWindowManagerState()
        }
    }

    Component.onCompleted: if (ShellState.ready) loadWindowManagerState()

    Process {
        id: picomStatus
        command: [ShellState.scriptsDir + "/theme/picom-control", "status", root.msgPath]
        running: true
        stdout: StdioCollector { id: picomStatusOutput }
        onExited: exitCode => {
            if (exitCode === 0)
                root.acceptPicomStatus(picomStatusOutput.text)
        }
    }

    Process {
        id: picomControl
        running: false
        stdout: StdioCollector { id: picomControlOutput }
        stderr: StdioCollector { id: picomControlError }
        onExited: exitCode => {
            root.picomBusy = false
            if (exitCode === 0)
                root.acceptPicomStatus(picomControlOutput.text)
            else {
                const detail = picomControlError.text.trim()
                console.warn(detail !== "" ? detail : "Could not update Picom")
                root.refreshPicomState()
            }
        }
    }

    Timer {
        id: restoreGap
        interval: 150
        onTriggered: Quickshell.execDetached(
            [root.msgPath, "gaps", String(root.gaps)])
    }

}
