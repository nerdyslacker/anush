import QtQuick
import ".."
import Quickshell
import Quickshell.Io

WindowManagerBackend {
    id: root

    name: "skarwm"
    capabilities: ({
        screens: true,
        perScreenWorkspaces: true,
        workspaces: true,
        renameWorkspace: false,
        windows: true,
        windowTitles: true,
        windowAppIdentity: true,
        focusWindow: true,
        closeWindow: false,
        moveWindowToWorkspace: false,
        moveWindowToScreen: false,
        scratchpad: true,
        virtualScreens: true,
        decorationStyling: true,
        eventStream: true,
        layouts: true,
        gaps: true,
        reload: true,
        sessionControl: true,
        keybindings: true,
        configurationEditor: true
    })

    readonly property string msgPath: "skarwm-msg"
    property var rawOutputs: []
    property var workspaceConfigurations: ({})
    property var registeredScratchpads: []
    property string activeWinId: ""
    property string title: ""

    function clearState() {
        connected = false
        screens = []
        workspaces = []
        windows = []
        rawOutputs = []
        registeredScratchpads = []
        activeWinId = ""
        title = ""
        changed()
    }

    function start() {
        if (!active) return
        snapshotRetryTimer.stop()
        versionQuery.running = true
        workspaceQuery.running = true
        workspaceConfigQuery.running = true
        windowQuery.running = true
        outputQuery.running = true
        eventSubscription.running = true
        reconcileTimer.start()
    }

    function stop() {
        reconnectTimer.stop()
        snapshotRetryTimer.stop()
        reconcileTimer.stop()
        versionQuery.running = false
        workspaceQuery.running = false
        workspaceConfigQuery.running = false
        windowQuery.running = false
        outputQuery.running = false
        eventSubscription.running = false
        clearState()
    }

    function refresh() {
        if (!active) return
        workspaceQuery.running = false
        workspaceQuery.running = true
        windowQuery.running = false
        windowQuery.running = true
        workspaceConfigQuery.running = false
        workspaceConfigQuery.running = true
        outputQuery.running = false
        outputQuery.running = true
    }

    function snapshotFailed(source) {
        console.warn("skarwm " + source + " query failed")
        clearState()
        if (active) snapshotRetryTimer.restart()
    }

    function acceptWorkspaceConfig(line) {
        try {
            const value = JSON.parse(line)
            const entries = value?.document?.workspaceLayouts
            if (!Array.isArray(entries)) return
            const next = ({})
            for (const entry of entries) {
                const id = Number(entry?.workspace)
                const icon = String(entry?.icon ?? "")
                if (isFinite(id) && id >= 1 && icon !== "")
                    next[String(Math.round(id))] = {
                        icon: icon, name: String(entry?.name ?? "")
                    }
            }
            workspaceConfigurations = next
            changed()
        } catch (error) {
            console.warn("skarwm workspace configuration:", error)
        }
    }

    function acceptWorkspaces(line) {
        try {
            const value = JSON.parse(line)
            if (!Array.isArray(value)) return
            workspaces = value.map(ws => Object.assign({}, ws, {
                id: String(ws.id),
                name: String(ws.name ?? ws.id),
                index: Number(ws.num ?? ws.id) - 1,
                screenId: ws.output === null || ws.output === undefined
                    ? null : String(ws.output),
                active: ws.visible === true,
                focused: ws.focused === true,
                visible: ws.visible === true,
                occupied: Number(ws.windows) > 0,
                urgent: ws.urgent === true
            }))
            changed()
        } catch (error) {
            console.warn("skarwm workspace snapshot:", error)
            snapshotFailed("workspace")
        }
    }

    function acceptWindows(line) {
        try {
            const value = JSON.parse(line)
            if (!value || !Array.isArray(value.windows)) return
            windows = value.windows.map(win => Object.assign({}, win, {
                id: String(win.id),
                appId: String(win.class || win.instance || ""),
                workspaceId: win.workspace === null || win.workspace === undefined
                    ? null : String(win.workspace),
                screenId: win.output === null || win.output === undefined
                    ? null : String(win.output),
                focused: win.focused === true,
                urgent: win.urgent === true,
                floating: win.floating === true,
                fullscreen: win.fullscreen === true,
                maximized: null,
                scratchpad: win.scratchpad === true
            }))
            let focused = null
            const scratchpads = []
            for (const win of windows) {
                if (win.focused && !win.dock) focused = win
                const registers = Array.isArray(win.scratchpad_registers)
                    ? win.scratchpad_registers
                    : win.scratchpad_register === null
                        || win.scratchpad_register === undefined
                        ? [] : [win.scratchpad_register]
                for (const register of registers) {
                    scratchpads.push({
                        register: Number(register),
                        id: win.id,
                        title: win.title || win.class || win.instance
                            || "Untitled window",
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
            title = focused ? String(focused.title ?? "") : ""
            changed()
        } catch (error) {
            console.warn("skarwm window snapshot:", error)
            snapshotFailed("window")
        }
    }

    function acceptOutputs(line) {
        try {
            const value = JSON.parse(line)
            if (!Array.isArray(value)) return
            rawOutputs = value
            screens = value.map(output => ({
                id: String(output.name),
                name: String(output.name),
                geometry: output.rect ?? null,
                workarea: output.workarea ?? null,
                focused: output.focused === true,
                physicalOutput: output.physical_output === null
                    || output.physical_output === undefined
                    ? String(output.name) : String(output.physical_output),
                virtual: output.virtual === true
            }))
            changed()
        } catch (error) {
            console.warn("skarwm output snapshot:", error)
            snapshotFailed("output")
        }
    }

    function switchWorkspace(id, screenId) {
        if (!connected) return false
        const command = [msgPath, "workspace", String(id)]
        if (screenId !== undefined && screenId !== null && String(screenId) !== "")
            command.push("output", String(screenId))
        Quickshell.execDetached(command)
        return true
    }

    function focusWindow(id) {
        if (!connected || id === undefined || id === null) return false
        Quickshell.execDetached([msgPath, "focus", "window", String(id)])
        return true
    }

    function sendFocusedWindowToWorkspace(workspaceId) {
        if (!connected) return false
        Quickshell.execDetached([
            msgPath, "move", "workspace", String(workspaceId)
        ])
        return true
    }

    function setLayout(command) {
        if (!connected || String(command ?? "") === "") return false
        Quickshell.execDetached([msgPath, "layout", String(command)])
        return true
    }

    function setGaps(value) {
        if (!connected) return false
        Quickshell.execDetached([msgPath, "gaps", String(value)])
        return true
    }

    function setDecorationsEnabled(enabled) {
        if (!active) return false
        Quickshell.execDetached([
            ShellState.scriptsDir + "/theme/apply-window-decorations",
            enabled === true ? "true" : "false", msgPath
        ])
        return true
    }

    function toggleScratchpad(register) {
        if (!connected) return false
        Quickshell.execDetached([msgPath, "scratchpad", "toggle", String(register)])
        return true
    }

    function addReminder(minutes, message) {
        if (!connected) return false
        Quickshell.execDetached([
            msgPath, "reminder", "add", String(minutes), String(message)
        ])
        return true
    }

    function reloadWindowManager() {
        if (!connected) return false
        const script =
            "wm=$1; notification_id=991049; " +
            "if ! \"$wm\" reload >/dev/null 2>&1; then " +
            "notify-send -a skarwm -r $notification_id -u critical " +
            "-i dialog-error 'Desktop reload failed' " +
            "'skarwm rejected the configuration; Quickshell was left running.'; " +
            "exit 1; fi; " +
            "notify-send -a skarwm -r $notification_id -t 2000 " +
            "-i system-run 'Reloading desktop' " +
            "'skarwm reloaded; restarting Quickshell…'; " +
            "sleep 0.25; " +
            "if anushctl restart >/dev/null 2>&1; then " +
            "sleep 0.8; notify-send -a skarwm -r $notification_id -t 2500 " +
            "-i dialog-information 'Desktop reloaded' " +
            "'skarwm and Quickshell restarted successfully.'; " +
            "else notify-send -a skarwm -r $notification_id -u critical " +
            "-i dialog-error 'Quickshell restart failed' " +
            "'skarwm reloaded, but Quickshell could not be started.'; fi"
        Quickshell.execDetached([
            "sh", "-c", script, "skarwm-reload", msgPath
        ])
        return true
    }

    function quitWindowManager() {
        if (!connected) return false
        Quickshell.execDetached([msgPath, "quit"])
        return true
    }

    function showKeybindings() {
        if (!connected) return false
        Quickshell.execDetached([msgPath, "show-bindings"])
        return true
    }

    onActiveChanged: {
        if (active) start()
        else stop()
    }

    Process {
        id: versionQuery
        command: [root.msgPath, "get-version"]
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const value = JSON.parse(text)
                    root.connected = String(value?.human_readable ?? "")
                        .toLowerCase().indexOf("skarwm") !== -1
                } catch (error) {
                    if (root.active) root.snapshotFailed("version")
                }
            }
        }
        onExited: code => {
            if (code !== 0 && root.active) root.snapshotFailed("version")
        }
    }

    Process {
        id: workspaceQuery
        command: [root.msgPath, "get-workspaces"]
        running: false
        stdout: SplitParser { onRead: line => root.acceptWorkspaces(line) }
        onExited: code => {
            if (code !== 0 && root.active) root.snapshotFailed("workspace")
        }
    }

    Process {
        id: workspaceConfigQuery
        command: [Theme.scriptsDir + "/skarwm/config-editor", "read"]
        running: false
        stdout: SplitParser { onRead: line => root.acceptWorkspaceConfig(line) }
    }

    Process {
        id: windowQuery
        command: [root.msgPath, "get-windows"]
        running: false
        stdout: SplitParser { onRead: line => root.acceptWindows(line) }
        onExited: code => {
            if (code !== 0 && root.active) root.snapshotFailed("window")
        }
    }

    Process {
        id: outputQuery
        command: [root.msgPath, "get-outputs"]
        running: false
        stdout: SplitParser { onRead: line => root.acceptOutputs(line) }
        onExited: code => {
            if (code !== 0 && root.active) root.snapshotFailed("output")
        }
    }

    Process {
        id: eventSubscription
        command: [root.msgPath, "subscribe", "workspace", "window", "output", "ui"]
        running: false
        stdout: SplitParser {
            onRead: line => {
                try {
                    const event = JSON.parse(line)
                    if (!event || event.change === undefined) return
                    root.connected = true
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
                    root.refresh()
                } catch (error) {
                    console.warn("skarwm event:", error)
                }
            }
        }
        onExited: {
            if (!root.active) return
            root.clearState()
            reconnectTimer.restart()
        }
    }

    Timer {
        id: reconnectTimer
        interval: 2000
        onTriggered: root.start()
    }
    Timer {
        id: snapshotRetryTimer
        interval: 2000
        onTriggered: root.refresh()
    }
    Timer {
        id: reconcileTimer
        interval: 30000
        repeat: true
        onTriggered: root.refresh()
    }
}
