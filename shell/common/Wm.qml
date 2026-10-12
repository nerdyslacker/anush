pragma Singleton
import QtQuick
import ".."
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    readonly property string requestedBackend: {
        const override = String(Quickshell.env("ANUSH_WM_BACKEND") ?? "")
            .trim().toLowerCase()
        if (override !== "") return override
        return String(ShellState.state.windowManager?.backend ?? "auto")
            .trim().toLowerCase()
    }
    property bool detectionComplete: false
    property string detectedWmName: ""
    property string detectedWmIdentity: "unknown"
    readonly property string selectedBackendName: {
        if (requestedBackend === "auto") {
            if (!detectionComplete) return "detecting"
            if (["skarwm", "bspwm", "herbstluftwm", "i3", "spectrwm", "dwm"]
                    .indexOf(detectedWmIdentity) >= 0)
                return detectedWmIdentity
            return "ewmh"
        }
        if (["ewmh"]
                .indexOf(requestedBackend) >= 0)
            return "ewmh"
        return requestedBackend
    }
    readonly property var backend: selectedBackendName === "skarwm"
        ? skarwmBackend : selectedBackendName === "mock"
            ? mockBackend : selectedBackendName === "bspwm"
                ? bspwmBackend : selectedBackendName === "herbstluftwm"
                    ? herbstluftwmBackend : selectedBackendName === "i3"
                        ? i3Backend : selectedBackendName === "spectrwm"
                            ? spectrwmBackend : selectedBackendName === "dwm"
                                ? dwmBackend : selectedBackendName === "ewmh"
                                    ? ewmhBackend : unavailableBackend
    readonly property string backendName: String(backend.name)
    readonly property string backendIntegration: String(backend.integration ?? "")
    readonly property bool connected: backend.connected === true
    readonly property var capabilities: backend.capabilities ?? ({})
    readonly property var screens: backend.screens ?? []
    readonly property var workspaces: backend.workspaces ?? []
    readonly property var windows: backend.windows ?? []

    readonly property var outputs: backend === skarwmBackend
        ? skarwmBackend.rawOutputs : compatibilityOutputs()
    readonly property var workspaceConfigurations: backend === skarwmBackend
        ? skarwmBackend.workspaceConfigurations : ({})
    readonly property var registeredScratchpads: backend === skarwmBackend
        ? skarwmBackend.registeredScratchpads
        : capabilities.scratchpad === true ? windows
            .filter(window => window.scratchpad === true)
            .map(window => ({
                register: window.id,
                title: String(window.title ?? "Scratchpad"),
                className: String(window.class ?? window.instance ?? ""),
                hidden: window.screenId === null || window.screenId === undefined,
                workspace: window.workspaceId
            })) : []
    readonly property string msgPath: backend === skarwmBackend
        ? skarwmBackend.msgPath : ""
    readonly property bool isSkarwm: backend === skarwmBackend && connected
    readonly property string activeWinId: backend === skarwmBackend
        ? skarwmBackend.activeWinId : ""
    readonly property string title: backend === skarwmBackend
        ? skarwmBackend.title : String(focusedWindow?.title ?? "")

    signal overviewCommand(string action)
    signal uiEvent(var event)
    signal actionFailed(string action, string reason)
    signal physicalOutputConnected()
    signal physicalOutputDisconnected()

    readonly property int tagCount: {
        let highest = 1
        for (const workspace of workspaces)
            highest = Math.max(highest, Number(workspace.index) + 1)
        return highest
    }
    readonly property int dynamicTagCount: {
        let highestOccupied = 0
        let focused = 1
        for (const workspace of workspaces) {
            const index = Math.max(0, Number(workspace.index) || 0)
            if (workspace.occupied === true)
                highestOccupied = Math.max(highestOccupied, index + 1)
            if (workspace.focused === true)
                focused = index + 1
        }
        return Math.max(1, focused, highestOccupied + 1)
    }
    readonly property var focusedWindow:
        windows.find(window => window.focused === true) ?? null
    readonly property var focusedScreen:
        screens.find(screen => screen.focused === true)
            ?? (screens.length > 0 ? screens[0] : null)
    readonly property var focusedOutput: {
        const screen = focusedScreen
        if (!screen) return null
        for (const output of outputs)
            if (String(output.name) === String(screen.id)) return output
        return {
            name: screen.name,
            rect: screen.geometry,
            workarea: screen.workarea,
            focused: screen.focused
        }
    }
    readonly property var focusedWorkspace:
        workspaces.find(workspace => workspace.focused === true) ?? null

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
    readonly property string workspaceLayout: String(
        focusedWorkspace?.layout ?? "scrolling-tile")
    readonly property int layoutIndex: {
        if (workspaceLayout === "scrolling-tile"
                && focusedWindow?.column_layout === "tabbed")
            return layouts.findIndex(layout => layout.command === "tabbed")
        const index = layouts.findIndex(layout => layout.command === workspaceLayout)
        return index >= 0 ? index : 0
    }

    property var lastFocusedWindowByScreen: ({})
    property int gaps: 8
    property bool decorationsEnabled: false
    property bool picomAvailable: false
    property bool picomEnabled: false
    property bool picomBusy: false

    function compatibilityOutputs() {
        return screens.map(screen => {
            const workspace = focusedWorkspaceForScreen(screen.id)
            return {
                name: screen.id,
                active: true,
                focused: screen.focused,
                rect: screen.geometry,
                workarea: screen.workarea,
                physical_output: screen.physicalOutput,
                virtual: screen.virtual,
                current_workspace: workspace ? workspace.id : null
            }
        })
    }

    function outputNameForScreen(screen) {
        const nativeName = String(screen?.name ?? "")
        for (const wmScreen of screens)
            if (String(wmScreen.name) === nativeName
                    || String(wmScreen.id) === nativeName)
                return String(wmScreen.id)
        if (screen) {
            for (const wmScreen of screens) {
                const geometry = wmScreen.geometry
                if (geometry && Number(geometry.x) === Number(screen.x)
                        && Number(geometry.y) === Number(screen.y)
                        && Number(geometry.width) === Number(screen.width)
                        && Number(geometry.height) === Number(screen.height))
                    return String(wmScreen.id)
            }
        }
        if (screens.length === 1) return String(screens[0].id)
        return nativeName
    }

    function workspaceAt(index, screenId) {
        for (const workspace of workspaces)
            if (Number(workspace.index) === index
                    && (capabilities.perScreenWorkspaces !== true
                        || !screenId
                        || String(workspace.screenId) === String(screenId)))
                return workspace
        return null
    }
    function isSelected(index, screenId) {
        const workspace = workspaceAt(index, screenId)
        if (workspace === null) return false
        if (screenId && workspace.screenId !== null
                && workspace.screenId !== undefined)
            return workspace.visible === true
                && String(workspace.screenId) === String(screenId)
        return screenId ? workspace.visible === true : workspace.focused === true
    }
    function isOccupied(index, screenId) {
        const workspace = workspaceAt(index, screenId)
        return workspace !== null && workspace.occupied === true
    }
    function isUrgent(index, screenId) {
        const workspace = workspaceAt(index, screenId)
        return workspace !== null && workspace.urgent === true
    }
    function workspaceIcon(index) {
        return String(workspaceConfigurations[String(index + 1)]?.icon ?? "")
    }
    function workspaceName(index) {
        const configured = workspaceConfigurations[String(index + 1)]?.name
        if (configured !== undefined && String(configured) !== "")
            return String(configured)
        const workspace = workspaceAt(index, "")
        return String(workspace?.name ?? "")
    }

    function workspacesForScreen(screenId) {
        const wanted = String(screenId ?? "")
        return workspaces.filter(workspace => String(workspace.screenId ?? "") === wanted)
    }
    function windowsForScreen(screenId) {
        const wanted = String(screenId ?? "")
        return windows.filter(window => String(window.screenId ?? "") === wanted)
    }
    function focusedWorkspaceForScreen(screenId) {
        const wanted = String(screenId ?? "")
        const local = workspaces.find(workspace =>
            String(workspace.screenId ?? "") === wanted
                && workspace.visible === true)
        if (local) return local
        if (capabilities.perScreenWorkspaces !== true)
            return workspaces.find(workspace => workspace.focused === true)
                ?? workspaces.find(workspace => workspace.visible === true) ?? null
        return null
    }
    function windowForScreen(screenId) {
        const wanted = String(screenId ?? "")
        const workspace = focusedWorkspaceForScreen(wanted)
        const candidates = windows.filter(window => window.scratchpad !== true
            && window.dock !== true
            && (capabilities.screens !== true
                || String(window.screenId ?? "") === wanted)
            && (!workspace || window.workspaceId === null
                || window.workspaceId === undefined
                || String(window.workspaceId) === String(workspace.id)))
        return candidates.find(window => window.focused === true)
            ?? candidates.find(window => String(window.id)
                === String(lastFocusedWindowByScreen[wanted]))
            ?? candidates.find(window => window.tab_active === true)
            ?? (candidates.length > 0 ? candidates[0] : null)
    }
    function windowForOutput(outputName) { return windowForScreen(outputName) }

    function rememberFocusedWindow() {
        const focused = focusedWindow
        if (!focused || focused.screenId === null || focused.screenId === undefined)
            return
        const next = Object.assign({}, lastFocusedWindowByScreen)
        next[String(focused.screenId)] = focused.id
        lastFocusedWindowByScreen = next
    }

    function requireCapability(capability, action) {
        if (connected && capabilities[capability] === true) return true
        const reason = !connected ? backendName + " backend is disconnected"
            : backendName + " does not support " + action
        actionFailed(action, reason)
        return false
    }
    function refreshAll() { backend.refresh() }
    function refreshWorkspaces() { backend.refresh() }
    function refreshWindows() { backend.refresh() }
    function switchWorkspace(id, screenId) {
        return requireCapability("workspaces", "switchWorkspace")
            && backend.switchWorkspace(id, screenId)
    }
    function focusWindow(id) {
        return requireCapability("focusWindow", "focusWindow")
            && backend.focusWindow(id)
    }
    function focusScreen(id) {
        return requireCapability("screens", "focusScreen")
            && backend.focusScreen(id)
    }
    function moveWindowToWorkspace(windowId, workspaceId) {
        return requireCapability("moveWindowToWorkspace", "moveWindowToWorkspace")
            && backend.moveWindowToWorkspace(windowId, workspaceId)
    }
    function moveWindowToScreen(windowId, screenId) {
        return requireCapability("moveWindowToScreen", "moveWindowToScreen")
            && backend.moveWindowToScreen(windowId, screenId)
    }
    function closeWindow(id) {
        return requireCapability("closeWindow", "closeWindow")
            && backend.closeWindow(id)
    }

    function viewTag(index, screenId) {
        const workspace = workspaceAt(index, screenId)
        return workspace ? switchWorkspace(workspace.id, screenId) : false
    }
    function toggleViewTag(index, screenId) { return viewTag(index, screenId) }
    function sendToTag(index) {
        const workspace = workspaceAt(index, "")
        if (!workspace) return false
        if (!connected) return requireCapability("moveWindowToWorkspace",
            "moveWindowToWorkspace")
        return backend.sendFocusedWindowToWorkspace(workspace.id)
    }
    function cycleTag(direction, visibleCount, screenId) {
        const count = Math.max(1, Math.round(Number(visibleCount) || tagCount))
        const current = focusedWorkspaceForScreen(screenId) ?? focusedWorkspace
        const index = current ? Number(current.index) : 0
        const step = direction > 0 ? 1 : -1
        return viewTag((index + step + count) % count, screenId)
    }
    function setLayout(index) {
        if (!requireCapability("layouts", "setLayout")) return false
        const layout = layouts[index]
        if (!layout) return false
        const command = layout.command === "scrolling-tile"
                && focusedWindow?.column_layout === "tabbed"
            ? "stacked" : layout.command
        return backend.setLayout(command)
    }
    function cycleLayout(direction) {
        if (!requireCapability("layouts", "cycleLayout")) return false
        let index = workspaceLayoutCommands.indexOf(workspaceLayout)
        if (index < 0) index = 0
        const next = (index + direction + workspaceLayoutCommands.length)
            % workspaceLayoutCommands.length
        return backend.setLayout(workspaceLayoutCommands[next])
    }
    function setGaps(value, persist) {
        const next = Math.min(40, Math.max(0, Math.round(value)))
        gaps = next
        if (capabilities.gaps === true) backend.setGaps(next)
        if (persist !== false)
            ShellState.updateSection("windowManager", { gap: next })
    }
    function persistGaps(value) {
        gaps = Math.min(40, Math.max(0, Math.round(value)))
        ShellState.updateSection("windowManager", { gap: gaps })
    }
    function setDecorationsEnabled(enabled) {
        decorationsEnabled = enabled === true
        ShellState.updateSection("windowManager", {
            decorations: decorationsEnabled
        })
        if (capabilities.decorationStyling === true)
            backend.setDecorationsEnabled(decorationsEnabled)
    }
    function toggleScratchpad(register) {
        return requireCapability("scratchpad", "toggleScratchpad")
            && backend.toggleScratchpad(register)
    }
    function addReminder(minutes, message) {
        if (!connected) return false
        return backend.addReminder(minutes, message)
    }
    function reloadWindowManager() {
        return requireCapability("reload", "reloadWindowManager")
            && backend.reloadWindowManager()
    }
    function quitWindowManager() {
        return requireCapability("sessionControl", "quitWindowManager")
            && backend.quitWindowManager()
    }
    function showKeybindings() {
        return requireCapability("keybindings", "showKeybindings")
            && backend.showKeybindings()
    }

    function showNotice(message, persistent, screenId) {
        const requested = String(screenId ?? "")
        root.uiEvent({
            change: "ui-notice",
            text: String(message ?? ""),
            persistent: persistent === true,
            output: requested !== "" ? requested : String(focusedScreen?.id ?? "")
        })
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
        if (picomBusy) return
        picomStatus.running = false
        picomStatus.running = true
    }
    function setPicomEnabled(enabled) {
        if (picomBusy) return
        picomEnabled = enabled === true
        picomBusy = true
        picomControl.command = [ShellState.scriptsDir + "/theme/picom-control",
            picomEnabled ? "enable" : "disable", msgPath]
        picomControl.running = true
    }

    function loadWindowManagerState() {
        const saved = Number(ShellState.state.windowManager.gap)
        if (!isNaN(saved)) gaps = Math.min(40, Math.max(0, Math.round(saved)))
        decorationsEnabled = ShellState.state.windowManager.decorations === true
        if (connected && capabilities.gaps === true) backend.setGaps(gaps)
        if (connected && capabilities.decorationStyling === true)
            backend.setDecorationsEnabled(decorationsEnabled)
    }

    function detectWindowManager() {
        if (!ShellState.ready || requestedBackend !== "auto") return
        detectionQuery.running = false
        detectionQuery.running = true
    }

    function acceptDetection(text) {
        try {
            const value = JSON.parse(String(text ?? ""))
            detectedWmName = String(value.name ?? "")
            detectedWmIdentity = String(value.identity ?? "unknown")
        } catch (error) {
            detectedWmName = ""
            detectedWmIdentity = "unknown"
        }
        detectionComplete = true
    }

    function configureDetection() {
        const automatic = ShellState.ready && requestedBackend === "auto"
        if (automatic && !detectionComplete) detectWindowManager()
        identityMonitor.running = automatic
        if (!automatic) identityRestart.stop()
    }

    SkarwmBackend {
        id: skarwmBackend
        active: ShellState.ready && root.selectedBackendName === "skarwm"
    }
    MockWindowManagerBackend {
        id: mockBackend
        active: ShellState.ready && root.selectedBackendName === "mock"
    }
    EwmhBackend {
        id: ewmhBackend
        active: ShellState.ready && root.selectedBackendName === "ewmh"
    }
    BspwmBackend {
        id: bspwmBackend
        active: ShellState.ready && root.selectedBackendName === "bspwm"
    }
    HerbstluftwmBackend {
        id: herbstluftwmBackend
        active: ShellState.ready && root.selectedBackendName === "herbstluftwm"
    }
    I3Backend {
        id: i3Backend
        active: ShellState.ready && root.selectedBackendName === "i3"
    }
    SpectrwmBackend {
        id: spectrwmBackend
        active: ShellState.ready && root.selectedBackendName === "spectrwm"
    }
    DwmBackend {
        id: dwmBackend
        active: ShellState.ready && root.selectedBackendName === "dwm"
    }
    WindowManagerBackend {
        id: unavailableBackend
        name: root.selectedBackendName
        active: ShellState.ready && root.selectedBackendName !== "skarwm"
            && root.selectedBackendName !== "mock"
            && root.selectedBackendName !== "bspwm"
            && root.selectedBackendName !== "herbstluftwm"
            && root.selectedBackendName !== "i3"
            && root.selectedBackendName !== "spectrwm"
            && root.selectedBackendName !== "dwm"
            && root.selectedBackendName !== "ewmh"
    }

    Connections {
        target: root.backend
        function onChanged() { root.rememberFocusedWindow() }
        function onActionFailed(action, reason) {
            root.actionFailed(action, reason)
        }
        function onOverviewCommand(action) { root.overviewCommand(action) }
        function onUiEvent(event) { root.uiEvent(event) }
        function onPhysicalOutputConnected() { root.physicalOutputConnected() }
        function onPhysicalOutputDisconnected() { root.physicalOutputDisconnected() }
        function onConnectedChanged() {
            if (root.connected) root.loadWindowManagerState()
        }
    }
    Connections {
        target: ShellState
        function onStateChanged() { root.loadWindowManagerState() }
        function onReadyChanged() {
            if (ShellState.ready) {
                root.configureDetection()
                root.loadWindowManagerState()
            }
        }
    }

    onRequestedBackendChanged: configureDetection()
    Component.onCompleted: if (ShellState.ready) {
        configureDetection()
        loadWindowManagerState()
    }

    Process {
        id: detectionQuery
        command: [ShellState.scriptsDir + "/wm/ewmh-provider", "detect"]
        running: false
        stdout: StdioCollector { id: detectionOutput }
        onExited: exitCode => {
            if (exitCode === 0) root.acceptDetection(detectionOutput.text)
            else root.acceptDetection("{}")
        }
    }
    Process {
        id: identityMonitor
        command: [ShellState.scriptsDir + "/wm/ewmh-provider", "monitor-identity"]
        running: false
        stdout: SplitParser {
            onRead: line => { if (line !== "") detectionDebounce.restart() }
        }
        onExited: {
            if (ShellState.ready && root.requestedBackend === "auto")
                identityRestart.restart()
        }
    }
    Timer {
        id: detectionDebounce
        interval: 100
        onTriggered: root.detectWindowManager()
    }
    Timer {
        id: identityRestart
        interval: 2000
        onTriggered: {
            root.detectWindowManager()
            identityMonitor.running = true
        }
    }

    Process {
        id: picomStatus
        command: [ShellState.scriptsDir + "/theme/picom-control", "status", root.msgPath]
        running: true
        stdout: StdioCollector { id: picomStatusOutput }
        onExited: exitCode => {
            if (exitCode === 0) root.acceptPicomStatus(picomStatusOutput.text)
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
}
