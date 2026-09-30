pragma Singleton

import QtQuick
import "../.."
import Quickshell
import Quickshell.Io

// Shared XKB state for every bar instance. Configuration is applied with
// setxkbmap; xkb-switch supplies the active group that setxkbmap cannot query.
Singleton {
    id: root

    property string layoutsCsv: "us"
    property string variantsCsv: ""
    property string optionsCsv: ""
    property string currentSpec: ""
    property bool switcherAvailable: false
    property bool configLoaded: false
    property bool currentSpecInitialized: false
    property bool queryAdoptsConfiguration: false
    property bool shortcutKeycodesReady: false
    property bool shortcutLatched: false
    property bool managedNoticePending: false
    property int rawShortcutEvent: 0
    property int applyVerificationAttempts: 0
    readonly property int maximumGroups: 4
    readonly property int maximumApplyVerificationAttempts: 2
    property string configurationError: ""
    property var pendingApplyCommand: []
    property bool pendingNextGroup: false
    property var shortcutKeycodes: ({})
    property var availableLayouts: []
    property string rulesListPath: "/usr/share/X11/xkb/rules/evdev.lst"

    readonly property var layouts: splitCsv(layoutsCsv).filter(value => value !== "")
    readonly property var variants: splitCsv(variantsCsv)
    readonly property string currentLayout: {
        const value = currentSpec.replace(/\([^)]*\)$/, "")
        return value !== "" ? value : (layouts.length > 0 ? layouts[0] : "?")
    }
    readonly property string groupOption: {
        for (const option of splitCsv(optionsCsv)) {
            if (option.startsWith("grp:"))
                return option
        }
        return ""
    }
    readonly property bool usesManagedShortcut:
        groupOption === "grp:alt_shift_toggle"
            || groupOption === "grp:ctrl_shift_toggle"
            || groupOption === "grp:win_space_toggle"
    readonly property string appliedGroupOption:
        usesManagedShortcut && shortcutKeycodesReady ? "" : groupOption

    function splitCsv(value) {
        return String(value ?? "").split(",").map(part => part.trim())
    }

    function groupSpec(index) {
        const layout = layouts[index] ?? ""
        const variant = variants[index] ?? ""
        return variant === "" ? layout : layout + "(" + variant + ")"
    }

    function layoutName(code) {
        for (const layout of availableLayouts) {
            if (layout.code === code)
                return layout.name
        }
        return String(code).toUpperCase()
    }

    function specLayout(spec) {
        return String(spec ?? "").replace(/\([^)]*\)$/, "")
    }

    function specVariant(spec) {
        const match = String(spec ?? "").match(/\(([^)]*)\)$/)
        return match ? match[1] : ""
    }

    function notifyLayout(spec) {
        const layoutCode = specLayout(spec)
        const variantCode = specVariant(spec)
        const variantLabel = variantCode === "" ? "Default" : variantCode
        Wm.showNotice("Keyboard: " + layoutName(layoutCode)
            + " · " + variantLabel, false)
    }

    function updateCurrentSpec(value, shouldNotify) {
        const spec = String(value ?? "").trim()
        if (spec === "")
            return
        const changed = currentSpec !== spec
        const wasInitialized = currentSpecInitialized
        currentSpec = spec
        currentSpecInitialized = true
        if (shouldNotify && wasInitialized && changed)
            notifyLayout(spec)
    }

    function parseShortcutKeycodes(contents) {
        const keycodes = ({})
        for (const line of contents.split("\n")) {
            const match = line.match(/^\s*keycode\s+(\d+)\s*=\s*(.*)$/)
            if (!match)
                continue
            const code = Number(match[1])
            for (const symbol of match[2].trim().split(/\s+/)) {
                if (symbol !== "NoSymbol" && keycodes[symbol] === undefined)
                    keycodes[symbol] = code
            }
        }
        shortcutKeycodes = keycodes
        const ready = keycodes.Shift_L !== undefined
            && keycodes.Alt_L !== undefined
            && keycodes.Control_L !== undefined
            && keycodes.Super_L !== undefined
            && keycodes.space !== undefined
        const becameReady = ready && !shortcutKeycodesReady
        shortcutKeycodesReady = ready
        if (becameReady && configLoaded && usesManagedShortcut)
            applyCurrentConfiguration(true)
    }

    function keyPressed(symbols) {
        for (const symbol of symbols) {
            const code = shortcutKeycodes[symbol]
            if (code !== undefined && pressedShortcutKeys[code] === true)
                return true
        }
        return false
    }

    property var pressedShortcutKeys: ({})

    function handleRawShortcutKey(code, pressed) {
        if (!usesManagedShortcut || !shortcutKeycodesReady)
            return
        if (pressed && pressedShortcutKeys[code] === true)
            return

        pressedShortcutKeys[code] = pressed
        const shift = keyPressed(["Shift_L", "Shift_R"])
        const alt = keyPressed(["Alt_L", "Alt_R"])
        const control = keyPressed(["Control_L", "Control_R"])
        const superKey = keyPressed(["Super_L", "Super_R"])
        const space = keyPressed(["space"])
        let active = false
        if (groupOption === "grp:alt_shift_toggle")
            active = alt && shift
        else if (groupOption === "grp:ctrl_shift_toggle")
            active = control && shift
        else if (groupOption === "grp:win_space_toggle")
            active = superKey && space

        if (active && !shortcutLatched) {
            shortcutLatched = true
            advanceGroup()
        } else if (!active) {
            shortcutLatched = false
        }
    }

    function parseRawShortcutLine(line) {
        if (line.indexOf("EVENT type 13 (RawKeyPress)") !== -1) {
            rawShortcutEvent = 1
            return
        }
        if (line.indexOf("EVENT type 14 (RawKeyRelease)") !== -1) {
            rawShortcutEvent = -1
            return
        }
        if (line.startsWith("EVENT type ")) {
            rawShortcutEvent = 0
            return
        }
        if (rawShortcutEvent === 0)
            return
        const match = line.match(/^\s*detail:\s*(\d+)\s*$/)
        if (!match)
            return
        const event = rawShortcutEvent
        rawShortcutEvent = 0
        handleRawShortcutKey(Number(match[1]), event === 1)
    }

    function advanceGroup() {
        if (!switcherAvailable)
            return
        managedNoticeRelease.stop()
        managedNoticePending = true
        if (nextGroupProcess.running) {
            pendingNextGroup = true
            return
        }
        nextGroupProcess.running = true
    }

    function parseLayoutCatalogue(contents) {
        const result = []
        const layoutsByCode = ({})
        let section = ""
        for (const line of contents.split("\n")) {
            const heading = line.match(/^!\s+(layout|variant)\s*$/)
            if (heading) {
                section = heading[1]
                continue
            }
            if (line.startsWith("!")) {
                section = ""
                continue
            }
            if (section === "layout") {
                const match = line.match(/^\s+(\S+)\s+(.+?)\s*$/)
                if (!match)
                    continue
                const layout = { code: match[1], name: match[2], variants: [] }
                result.push(layout)
                layoutsByCode[layout.code] = layout
            } else if (section === "variant") {
                const match = line.match(/^\s+(\S+)\s+(\S+):\s+(.+?)\s*$/)
                if (!match || !layoutsByCode[match[2]])
                    continue
                layoutsByCode[match[2]].variants.push({
                    code: match[1], name: match[3]
                })
            }
        }
        availableLayouts = result
    }

    function variantsFor(code) {
        for (const layout of availableLayouts) {
            if (layout.code === code)
                return layout.variants ?? []
        }
        return []
    }

    function normalizeGroups(layoutText, variantText) {
        const rawLayouts = splitCsv(layoutText)
        const rawVariants = splitCsv(variantText)
        const layouts = []
        const variants = []
        for (let index = 0; index < rawLayouts.length; ++index) {
            if (rawLayouts[index] === "")
                continue
            layouts.push(rawLayouts[index])
            variants.push(String(rawVariants[index] ?? ""))
        }

        // Configurations written before multi-variant validation may contain
        // Default plus named variants for the same layout and exceed XKB's
        // four-group ceiling. Prefer the explicitly selected named variants.
        while (layouts.length > maximumGroups) {
            let redundantDefault = -1
            for (let index = 0; index < layouts.length; ++index) {
                if (variants[index] !== "")
                    continue
                const code = layouts[index]
                for (let other = 0; other < layouts.length; ++other) {
                    if (layouts[other] === code && variants[other] !== "") {
                        redundantDefault = index
                        break
                    }
                }
                if (redundantDefault !== -1)
                    break
            }
            if (redundantDefault === -1)
                break
            layouts.splice(redundantDefault, 1)
            variants.splice(redundantDefault, 1)
        }
        return { layouts: layouts, variants: variants }
    }

    function normalizedVariants(layoutText, variantText) {
        const layoutCount = splitCsv(layoutText).filter(value => value !== "").length
        const result = splitCsv(variantText).slice(0, layoutCount)
        while (result.length < layoutCount)
            result.push("")
        return result.join(",")
    }

    function refreshConfiguration(adoptConfiguration) {
        queryAdoptsConfiguration = adoptConfiguration === true
        if (!queryProcess.running)
            queryProcess.running = true
    }

    function refreshCurrent() {
        if (switcherAvailable && !currentProcess.running)
            currentProcess.running = true
    }

    function applyCurrentConfiguration(resetVerification) {
        if (layouts.length === 0)
            return

        if (resetVerification !== false)
            applyVerificationAttempts = 0

        const command = ["setxkbmap", "-layout", layoutsCsv,
                         "-variant", variantsCsv, "-option", "", "-synch"]
        for (const option of splitCsv(optionsCsv)) {
            if (option !== "" && (!option.startsWith("grp:")
                    || option === appliedGroupOption))
                command.push("-option", option)
        }
        pendingApplyCommand = command
        if (applyProcess.running)
            applyProcess.running = false
        else
            startPendingConfiguration()
    }

    function startPendingConfiguration() {
        if (pendingApplyCommand.length === 0 || applyProcess.running)
            return
        const command = pendingApplyCommand
        pendingApplyCommand = []
        applyProcess.command = command
        applyProcess.running = true
    }

    function saveConfiguration(layoutText, variantText, selectedGroupOption) {
        const cleanLayouts = splitCsv(layoutText).filter(value => value !== "")
        if (cleanLayouts.length === 0) {
            configurationError = "Add at least one layout."
            return false
        }
        if (cleanLayouts.length > maximumGroups) {
            configurationError = "XKB supports at most " + maximumGroups
                + " switchable layout/variant entries."
            return false
        }

        configurationError = ""

        layoutsCsv = cleanLayouts.join(",")
        variantsCsv = splitCsv(variantText).slice(0, cleanLayouts.length).join(",")

        const options = splitCsv(optionsCsv).filter(option =>
            option !== "" && !option.startsWith("grp:"))
        const group = String(selectedGroupOption ?? "").trim()
        if (group !== "")
            options.push(group)
        optionsCsv = options.join(",")

        ShellState.updateSection("keyboard", { layout: {
            layouts: layoutsCsv, variants: variantsCsv, options: optionsCsv
        }})
        applyCurrentConfiguration(true)
        return true
    }

    function switchTo(index) {
        if (index < 0 || index >= layouts.length || !switcherAvailable)
            return
        switchProcess.command = ["xkb-switch", "-s", groupSpec(index)]
        switchProcess.running = true
    }

    function loadState() {
        const saved = ShellState.state.keyboard.layout
        const configuredLayouts = String(saved.layouts ?? "").trim()
        if (configuredLayouts !== "") {
            const normalized = root.normalizeGroups(configuredLayouts,
                String(saved.variants ?? ""))
            root.layoutsCsv = normalized.layouts.join(",")
            root.variantsCsv = normalized.variants.join(",")
            root.optionsCsv = String(saved.options ?? "")
            root.configurationError = normalized.layouts.length > root.maximumGroups
                ? "XKB supports at most " + root.maximumGroups
                    + " switchable layout/variant entries."
                : ""
            if (root.layoutsCsv !== configuredLayouts
                    || root.variantsCsv !== String(saved.variants ?? "")) {
                Qt.callLater(() => ShellState.updateSection("keyboard", {
                    layout: { layouts: root.layoutsCsv,
                        variants: root.variantsCsv, options: root.optionsCsv }
                }))
            }
            if (!root.configLoaded) {
                root.configLoaded = true
                if (normalized.layouts.length <= root.maximumGroups)
                    root.applyCurrentConfiguration(true)
            }
        } else if (!root.configLoaded) {
            root.configLoaded = true
            root.refreshConfiguration(true)
        }
    }

    Connections {
        target: ShellState
        function onStateChanged() { root.loadState() }
        function onReadyChanged() { if (ShellState.ready) root.loadState() }
    }

    Component.onCompleted: if (ShellState.ready) loadState()

    FileView {
        path: root.rulesListPath
        onLoaded: root.parseLayoutCatalogue(text())
        onLoadFailed: {
            if (root.rulesListPath.endsWith("/evdev.lst"))
                root.rulesListPath = "/usr/share/X11/xkb/rules/base.lst"
            else
                root.availableLayouts = []
        }
    }

    Process {
        id: queryProcess
        command: ["setxkbmap", "-query"]
        stdout: StdioCollector {
            onStreamFinished: {
                const values = ({})
                for (const line of text.split("\n")) {
                    const match = line.match(/^\s*(layout|variant|options):\s*(.*)$/)
                    if (match)
                        values[match[1]] = match[2].trim()
                }
                const actualLayouts = values.layout ?? ""
                const actualVariants = root.normalizedVariants(actualLayouts,
                    values.variant ?? "")
                let actualGroupOption = ""
                for (const option of root.splitCsv(values.options ?? "")) {
                    if (option.startsWith("grp:")) {
                        actualGroupOption = option
                        break
                    }
                }
                if (root.queryAdoptsConfiguration) {
                    if (actualLayouts !== "")
                        root.layoutsCsv = actualLayouts
                    root.variantsCsv = values.variant ?? ""
                    root.optionsCsv = values.options ?? ""
                } else if (actualLayouts !== root.layoutsCsv
                        || actualVariants !== root.normalizedVariants(
                            root.layoutsCsv, root.variantsCsv)
                        || actualGroupOption !== root.appliedGroupOption) {
                    if (root.applyVerificationAttempts
                            < root.maximumApplyVerificationAttempts) {
                        root.applyVerificationAttempts++
                        applyRetry.restart()
                    } else {
                        root.configurationError = "The saved keyboard layout "
                            + "or switching shortcut could not be activated. "
                            + "Another keyboard "
                            + "configuration service may be overriding it."
                    }
                } else {
                    root.configurationError = ""
                }
            }
        }
        onRunningChanged: if (!running) root.refreshCurrent()
    }

    Process {
        id: applyProcess
        stderr: StdioCollector { id: applyError; waitForEnd: true }
        onExited: exitCode => {
            if (root.pendingApplyCommand.length > 0) {
                Qt.callLater(() => root.startPendingConfiguration())
                return
            }
            root.configurationError = exitCode === 0 ? ""
                : applyError.text.trim() || "Could not apply keyboard configuration."
            if (exitCode === 0)
                applyVerificationDelay.restart()
            currentRefreshDelay.restart()
        }
    }

    Process {
        id: switcherProbe
        command: ["sh", "-c", "command -v xkb-switch 2>/dev/null"]
        running: BarVisibility.enabled("keyboard")
        stdout: StdioCollector {
            onStreamFinished: {
                root.switcherAvailable = text.trim() !== ""
                if (root.switcherAvailable)
                    root.refreshCurrent()
            }
        }
    }

    Process {
        id: shortcutKeycodeProbe
        command: ["xmodmap", "-pke"]
        running: BarVisibility.enabled("keyboard")
            && root.usesManagedShortcut && !root.shortcutKeycodesReady
        stdout: StdioCollector {
            onStreamFinished: root.parseShortcutKeycodes(text)
        }
    }

    Process {
        id: currentProcess
        command: ["xkb-switch", "-p"]
        stdout: StdioCollector {
            onStreamFinished: {
                const value = text.trim()
                if (value !== "")
                    root.updateCurrentSpec(value, false)
            }
        }
        onExited: exitCode => {
            if (exitCode !== 0) root.switcherAvailable = false
        }
    }

    // xkb-switch exposes the XKB group-change event stream directly. Keep one
    // sleeping subscriber instead of spawning a query every 750 ms.
    Process {
        id: groupMonitor
        command: ["xkb-switch", "-W"]
        running: BarVisibility.enabled("keyboard")
            && root.switcherAvailable && !monitorRestart.running
        stdout: SplitParser {
            onRead: line => {
                const value = line.trim()
                if (value !== "")
                    root.updateCurrentSpec(value, !root.managedNoticePending)
            }
        }
        onExited: if (BarVisibility.enabled("keyboard")
                && root.switcherAvailable) monitorRestart.restart()
    }

    Process {
        id: switchProcess
        onRunningChanged: if (!running) currentRefreshDelay.restart()
    }

    // Modifier-only XKB group options can behave like two-way toggles with
    // four groups. Observe only the master keyboard and advance the numeric
    // XKB group explicitly so duplicate layouts with different variants are
    // never collapsed or skipped.
    Process {
        id: shortcutMonitor
        command: ["xinput", "test-xi2", "--root", "Virtual core keyboard"]
        running: BarVisibility.enabled("keyboard")
            && root.usesManagedShortcut && root.shortcutKeycodesReady
            && root.switcherAvailable && !shortcutMonitorRestart.running
        stdout: SplitParser {
            onRead: line => root.parseRawShortcutLine(line)
        }
        onExited: {
            root.pressedShortcutKeys = ({})
            root.shortcutLatched = false
            if (BarVisibility.enabled("keyboard")
                    && root.usesManagedShortcut
                    && root.shortcutKeycodesReady
                    && root.switcherAvailable)
                shortcutMonitorRestart.restart()
        }
    }

    Process {
        id: nextGroupProcess
        command: ["xkb-switch", "-n"]
        onExited: {
            if (root.pendingNextGroup) {
                root.pendingNextGroup = false
                Qt.callLater(() => root.advanceGroup())
            } else {
                managedGroupQueryDelay.restart()
            }
        }
    }

    Process {
        id: managedGroupQuery
        command: ["xkb-switch", "-p"]
        stdout: StdioCollector {
            onStreamFinished: {
                const value = text.trim()
                if (value === "")
                    return
                root.updateCurrentSpec(value, false)
                root.notifyLayout(value)
            }
        }
        onExited: managedNoticeRelease.restart()
    }

    Timer {
        id: currentRefreshDelay
        interval: 100
        onTriggered: root.refreshCurrent()
    }

    Timer {
        id: managedGroupQueryDelay
        interval: 60
        onTriggered: {
            if (!managedGroupQuery.running)
                managedGroupQuery.running = true
        }
    }

    Timer {
        id: managedNoticeRelease
        interval: 120
        onTriggered: root.managedNoticePending = false
    }

    Timer {
        id: applyVerificationDelay
        interval: 120
        onTriggered: root.refreshConfiguration(false)
    }

    Timer {
        id: applyRetry
        interval: 150
        onTriggered: root.applyCurrentConfiguration(false)
    }

    Timer { id: monitorRestart; interval: 3000 }
    Timer { id: shortcutMonitorRestart; interval: 3000 }
}
