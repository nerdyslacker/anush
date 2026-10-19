pragma Singleton
import QtQuick
import ".."
import Quickshell
import Quickshell.Io

// Built-in palettes populate one semantic color API, so every component
// stays in the same theme without depending on another desktop configuration.
Singleton {
    id: root

    readonly property string shellDir: ShellState.shellDir
    readonly property string packageConfigDir: {
        const configured = String(Quickshell.env("ANUSH_PACKAGE_CONFIG_DIR") ?? "")
        return configured !== "" ? configured : ShellState.shellDir + "/../config"
    }
    readonly property string configDir: {
        const configured = String(Quickshell.env("ANUSH_CONFIG_DIR") ?? "")
        if (configured !== "")
            return configured
        const xdg = String(Quickshell.env("XDG_CONFIG_HOME") ?? "")
        return (xdg !== "" ? xdg : String(Quickshell.env("HOME") ?? "") + "/.config")
            + "/skarwm/anush"
    }
    readonly property string stateDir: ShellState.stateDir
    readonly property string scriptsDir: ShellState.scriptsDir

    property int barHeight: 34
    property real barUserScale: 1.0
    property real barBackgroundOpacity: 1.0
    property bool wallpaperThemeEnabled: false
    // Preset accentOverride values are defaults, not locks. Selecting an
    // accent explicitly disables the preset value until another preset is
    // selected, and the choice survives a shell restart.
    property bool usePresetAccent: true
    property string customAccent: "#6574A8"
    property string defaultAccentName: "yellow"
    property string presetId: "srcery-dark"
    property string mode: "dark"
    property var themePresets: []
    property bool presetsReady: false
    property bool initialThemeResolved: false
    property string applicationThemeStatus: ""
    property string wallpaperPresetStatus: ""
    property bool wallpaperPaletteRefreshAttempted: false
    property string externalAppearanceSignature: ""
    property int paletteRequestSerial: 0
    property var pendingPaletteCommand: []
    readonly property var activePreset: presetForId(presetId)
    readonly property bool matugenThemeGenerated:
        wallpaperThemeEnabled
        && ShellState.state.theme.palette?.generator === "matugen"
    readonly property bool applicationThemeApplying: applicationThemeProcess.running
    readonly property bool wallpaperPresetSaving: wallpaperPresetProcess.running
    readonly property bool light: mode === "light"
    // A single persisted appearance value feeds every non-circular surface.
    // Keep the tiers integral so borders and clipping stay pixel-aligned.
    property int cornerRadius: 0
    property bool cornerRadiusStateLoaded: false
    property int appliedCornerRadius: -1
    property string appliedCornerRadiusBackend: ""
    property bool appliedCornerRadiusWindowReady: false
    readonly property int radiusSmall: Math.round(cornerRadius * 0.5)
    readonly property int radiusMedium: cornerRadius
    readonly property int radiusLarge: Math.round(cornerRadius * 1.5)
    readonly property int surfaceGap: 8

    // Keep the persistent panel off-screen until its first real palette is
    // ready, so startup never paints a frame with the bootstrap colors.
    readonly property bool barStateReady: ShellState.ready
        && presetsReady && initialThemeResolved

    // Neutral bootstrap values are replaced when JSON loading completes.
    property color black: "#000000"
    property color red: "#FF0000"
    property color green: "#00AA00"
    property color yellow: "#AAAA00"
    property color blue: "#0000FF"
    property color magenta: "#AA00AA"
    property color cyan: "#00AAAA"
    property color white: "#CCCCCC"

    property color brightBlack: "#666666"
    property color brightRed: "#FF5555"
    property color brightGreen: "#55FF55"
    property color brightYellow: "#FFFF55"
    property color brightBlue: "#5555FF"
    property color brightMagenta: "#FF55FF"
    property color brightCyan: "#55FFFF"

    property color brightWhite: "#FFFFFF"

    property color darkGreen: "#005500"
    property color darkRed: "#550000"
    property color darkBlue: "#000055"
    property color dimGreen: "#008800"
    property color orange: "#FF8800"
    property color brightOrange: "#FFAA00"
    property color teal: "#008080"
    property color gray1: "#111111"
    property color gray2: "#222222"
    property color gray3: "#333333"
    property color gray4: "#444444"
    property color gray5: "#555555"
    property color gray6: "#666666"
    property color hardBlack: "#000000"

    // Semantic theme API. Palette sources populate the compatibility colors
    // above; shell components and future generators consume these roles.
    readonly property color background: black
    readonly property color surfaceSubtle: gray1
    readonly property color surface: gray2
    readonly property color surfaceVariant: gray3
    readonly property color hover: gray3
    readonly property color pressed: gray4
    readonly property color outline: gray5
    readonly property color disabled: gray6
    readonly property color foreground: brightWhite
    readonly property color foregroundMuted: brightBlack
    readonly property color primary: orange
    readonly property color secondary: brightBlue
    readonly property color error: red
    readonly property color warning: yellow
    readonly property color success: green
    readonly property color shadow: Qt.alpha(hardBlack, light ? 0.20 : 0.55)
    readonly property color overlay: Qt.alpha(hardBlack, light ? 0.30 : 0.45)

    // Short legacy names remain stable while components migrate to the roles.
    readonly property color bg: background
    readonly property color altbg: surface
    readonly property color fg: foreground
    readonly property color border: outline
    readonly property color alert: error

    readonly property var accentNames: [
        "orange", "red", "green", "yellow", "blue", "magenta", "cyan",
        "custom"
    ]
    property string accentName: "orange"
    readonly property color accent: wallpaperThemeEnabled ? primary
        : usePresetAccent && activePreset?.accentOverride
            ? activePreset.accentOverride : mutedAccentColor(accentName)
    readonly property color activeBackground: !wallpaperThemeEnabled
            && usePresetAccent
            && activePreset?.activeBackground
        ? activePreset.activeBackground : accent
    readonly property color activeBorder: !wallpaperThemeEnabled
            && usePresetAccent
            && activePreset?.activeBorder
        ? activePreset.activeBorder : accent
    readonly property color selbg: activeBackground
    readonly property color accentForeground: !wallpaperThemeEnabled
            && usePresetAccent
            && activePreset?.accentForeground
        ? activePreset.accentForeground
        : light ? (activePreset?.colors?.background ?? brightWhite) : hardBlack
    readonly property color selfg: accentForeground

    // Bar controls stay visually identical to their appearance on a fully
    // opaque bar even when the panel background itself is translucent.
    function barSurface(opacity) {
        if (!wallpaperThemeEnabled && activePreset?.solidBarSurfaces === true)
            return opacity >= 0.1 ? root.surfaceVariant : root.surface
        return Qt.tint(root.background, Qt.alpha(root.foreground, opacity))
    }

    readonly property string defaultFontFamily: "JetBrainsMono Nerd Font"
    property string fontFamily: defaultFontFamily
    // Patched text fonts scale individual icon sets differently. Prefer the
    // dedicated symbol font so bar glyphs retain consistent visual bounds.
    readonly property string iconFontFamily: "Symbols Nerd Font Mono"

    readonly property real barScale: barUserScale
    readonly property int fontSize: Math.round(12 * barScale)
    readonly property int moduleHeight: Math.round(28 * barScale)
    readonly property int iconSize: Math.round(moduleHeight * 0.61)
    readonly property int iconSizeSmall: Math.max(10, Math.round(13 * barScale))
    readonly property int iconSizeLarge: Math.max(iconSize, Math.round(22 * barScale))
    readonly property int effectiveBarHeight: Math.max(barHeight, moduleHeight)

    function accentColor(name) {
        switch (name) {
        case "custom": return customAccent
        case "red": return red
        case "green": return green
        case "yellow": return yellow
        case "blue": return blue
        case "magenta": return magenta
        case "cyan": return cyan
        case "brightOrange": return brightOrange
        case "brightRed": return brightRed
        case "brightGreen": return brightGreen
        case "brightYellow": return brightYellow
        case "brightBlue": return brightBlue
        case "brightMagenta": return brightMagenta
        case "brightCyan": return brightCyan
        default: return orange
        }
    }

    function normalizedAccentName(name, fallback) {
        let value = String(name ?? "")
        if (value.startsWith("bright") && value.length > 6)
            value = value.charAt(6).toLowerCase() + value.slice(7)
        return accentNames.indexOf(value) >= 0 ? value : fallback
    }

    function mutedColor(base) {
        const neutral = foregroundMuted
        const neutralAmount = 0.20
        const baseAmount = 1.0 - neutralAmount
        return Qt.rgba(
            base.r * baseAmount + neutral.r * neutralAmount,
            base.g * baseAmount + neutral.g * neutralAmount,
            base.b * baseAmount + neutral.b * neutralAmount,
            1.0)
    }

    function mutedAccentColor(name) {
        return mutedColor(accentColor(normalizedAccentName(name, "orange")))
    }

    function setAccent(name) {
        if (accentNames.indexOf(name) < 0)
            return
        accentName = name
        usePresetAccent = false
        ShellState.updateSection("theme", {
            accent: name,
            usePresetAccent: false
        })
        if (!wallpaperThemeEnabled) {
            defaultAccentName = name
            ShellState.updateSection("theme", { defaultAccent: name })
        }
        applyExternalAccent(name)
    }

    function normalizeCustomAccent(value) {
        const match = String(value ?? "").trim().match(/^#?([0-9a-fA-F]{6})$/)
        return match ? ("#" + match[1]).toUpperCase() : ""
    }

    function setCustomAccent(value) {
        const selected = normalizeCustomAccent(value)
        if (selected === "")
            return
        customAccent = selected
        accentName = "custom"
        usePresetAccent = false
        if (!wallpaperThemeEnabled)
            defaultAccentName = "custom"
        ShellState.updateSection("theme", {
            accent: "custom",
            customAccent: selected,
            defaultAccent: !wallpaperThemeEnabled ? "custom" : defaultAccentName,
            usePresetAccent: false
        })
        applyExternalAccent("custom")
    }

    function applyExternalAccent(name) {
        const selected = accent
        // Match bar modules while keeping focus legible: the focused
        // titlebar uses their hover surface and inactive windows use idle.
        const decorationBackground = barSurface(0.14)
        const decorationInactiveBackground = barSurface(0.07)
        Quickshell.execDetached([
            root.scriptsDir + "/theme/apply-accent",
            selected.toString(),
            Wm.msgPath,
            root.foreground.toString(),
            root.secondary.toString(),
            decorationBackground.toString(),
            decorationInactiveBackground.toString(),
            selected.toString(),
            selected.toString(),
            root.activeBorder.toString(),
            root.activeBorder.toString(),
            ShellState.state.windowManager.decorations === true
                ? "true" : "false",
            root.background.toString(),
            root.surface.toString(),
            root.disabled.toString(),
            root.outline.toString()
        ])
        AppearanceService.applyAccent(selected.toString())
    }

    function persistBarHeight(value) {
        barHeight = Math.min(80, Math.max(28, Math.round(value)))
        ShellState.updateSection("bar", { height: barHeight })
    }

    function persistBarScale(value) {
        barUserScale = Math.min(2, Math.max(0.7, value))
        ShellState.updateSection("bar", { scale: barUserScale })
    }

    function persistBarBackgroundOpacity(value) {
        barBackgroundOpacity = Math.min(1, Math.max(0, value))
        ShellState.updateSection("bar", { backgroundOpacity: barBackgroundOpacity })
    }

    function setFontFamily(value) {
        const selected = String(value ?? "").trim()
        if (selected === "") return
        fontFamily = selected
        ShellState.updateSection("theme", { fontFamily: selected })
    }

    function persistCornerRadius(value) {
        cornerRadius = Math.max(0, Math.round(Number(value) || 0))
        ShellState.updateSection("theme", { cornerRadius: cornerRadius })
        applyExternalCornerRadius()
    }

    function applyExternalCornerRadius() {
        if (!cornerRadiusStateLoaded)
            return
        const windowReady = Wm.connected
            && Wm.capabilities.windowRadius === true
        if (appliedCornerRadius === cornerRadius
                && appliedCornerRadiusBackend === Wm.backendName
                && appliedCornerRadiusWindowReady === windowReady)
            return
        appliedCornerRadius = cornerRadius
        appliedCornerRadiusBackend = Wm.backendName
        appliedCornerRadiusWindowReady = windowReady
        Quickshell.execDetached([
            root.scriptsDir + "/theme/apply-corner-radius",
            String(cornerRadius),
            Wm.msgPath,
            windowReady ? "true" : "false"
        ])
    }

    function applyApplicationTheme(toolkit) {
        const target = String(toolkit)
        if (!matugenThemeGenerated || ["gtk", "qt", "all"].indexOf(target) < 0)
            return
        applicationThemeProcess.running = false
        applicationThemeProcess.command = [
            root.scriptsDir + "/theme/apply-application-theme", target
        ]
        applicationThemeStatus = "Applying " + target.toUpperCase() + " theme…"
        applicationThemeProcess.running = true
    }

    function runPaletteCommand(command) {
        paletteRequestSerial += 1
        const token = String(Date.now()) + "-" + String(paletteRequestSerial)
        const requested = command.slice()
        requested.push("--request-file", root.stateDir + "/theme-request")
        requested.push("--request-token", token)
        pendingPaletteCommand = requested
        if (paletteProcess.running) {
            paletteProcess.running = false
            return
        }
        startPendingPaletteCommand()
    }

    function startPendingPaletteCommand() {
        if (paletteProcess.running || pendingPaletteCommand.length === 0)
            return
        const requested = pendingPaletteCommand
        pendingPaletteCommand = []
        paletteProcess.command = requested
        paletteProcess.running = true
    }

    function cancelPaletteCommand() {
        paletteRequestSerial += 1
        const token = String(Date.now()) + "-" + String(paletteRequestSerial)
        pendingPaletteCommand = []
        if (paletteProcess.running)
            paletteProcess.running = false
        Quickshell.execDetached([
            root.scriptsDir + "/theme/generate-wallpaper-theme", "--cancel",
            "--request-file", root.stateDir + "/theme-request",
            "--request-token", token
        ])
    }

    function applyWallpaper(path) {
        runPaletteCommand([
            root.scriptsDir + "/theme/wallpaper-theme",
            String(path), wallpaperThemeEnabled ? "true" : "false",
            mode, Wm.msgPath
        ])
    }

    function saveWallpaperPreset(name) {
        const title = String(name ?? "").trim()
        const palette = ShellState.state.theme.palette
        if (title === "" || themePresetNameExists(title)
                || !wallpaperThemeEnabled || !palette?.semantic)
            return
        wallpaperPresetProcess.running = false
        wallpaperPresetProcess.command = [
            root.scriptsDir + "/theme/save-wallpaper-preset",
            ShellState.filePath,
            root.configDir + "/themes/presets",
            title
        ]
        wallpaperPresetStatus = "Saving preset…"
        wallpaperPresetProcess.running = true
    }

    function themePresetNameExists(name) {
        const wanted = String(name ?? "").trim().toLocaleLowerCase()
        if (wanted === "")
            return false
        return themePresets.some(preset =>
            String(preset?.name ?? "").trim().toLocaleLowerCase() === wanted)
    }

    function persistThemeMode(value) {
        const next = value === "light" ? "light" : "dark"
        const paired = presetForId(String(activePreset?.pair ?? ""))
        if (paired && paired.mode === next)
            presetId = paired.id
        mode = next
        applyActivePalette()
        ShellState.updateSection("theme", { mode: next, preset: presetId })

        const palette = ShellState.state.theme.palette
        if (wallpaperThemeEnabled && palette?.image) {
            runPaletteCommand([
                root.scriptsDir + "/theme/generate-wallpaper-theme",
                String(palette.image), next,
                "--wm-msg", Wm.msgPath
            ])
        } else if (!wallpaperThemeEnabled
                && activePreset?.generatorDefault === true) {
            runPaletteCommand([
                root.scriptsDir + "/theme/generate-wallpaper-theme",
                "--default", next, accent.toString(),
                "--wm-msg", Wm.msgPath
            ])
        } else if (!wallpaperThemeEnabled)
            applyExternalAccent(accentName)
    }

    function presetForId(id) {
        for (let i = 0; i < themePresets.length; ++i) {
            if (themePresets[i].id === id)
                return themePresets[i]
        }
        return null
    }

    function setThemePreset(id) {
        const preset = presetForId(String(id))
        if (!preset)
            return
        presetId = preset.id
        mode = preset.mode
        wallpaperThemeEnabled = false
        cancelPaletteCommand()
        initialThemeResolved = true
        usePresetAccent = true
        applyPresetPalette()
        ShellState.updateSection("theme", {
            preset: presetId,
            mode: mode,
            wallpaperEnabled: false,
            usePresetAccent: true
        })
        applyExternalAccent(accentName)
    }

    function persistWallpaperThemeEnabled(enabled, wallpaperPath) {
        if (enabled && !wallpaperThemeEnabled) {
            defaultAccentName = accentName
            ShellState.updateSection("theme", { defaultAccent: accentName })
        }
        wallpaperThemeEnabled = enabled
        // Enabling below starts generation explicitly; mark that attempt so
        // the state-change handler does not launch a duplicate process.
        wallpaperPaletteRefreshAttempted = enabled
        ShellState.updateSection("theme", { wallpaperEnabled: enabled })
        if (enabled) {
            const image = String(wallpaperPath ?? "")
            if (image !== "") {
                runPaletteCommand([
                    root.scriptsDir + "/theme/generate-wallpaper-theme",
                    image, mode,
                    "--wm-msg", Wm.msgPath
                ])
            } else {
                loadState()
            }
        } else {
            initialThemeResolved = true
            applyPresetPalette()
            accentName = defaultAccentName
            usePresetAccent = true
            ShellState.updateSection("theme", {
                accent: accentName,
                usePresetAccent: true
            })
            if (activePreset?.generatorDefault === true) {
                runPaletteCommand([
                    root.scriptsDir + "/theme/generate-wallpaper-theme",
                    "--default", mode, accent.toString(),
                    "--wm-msg", Wm.msgPath
                ])
            } else {
                cancelPaletteCommand()
                applyExternalAccent(accentName)
            }
        }
    }

    function applySemanticPalette(p) {
        black = p.background
        gray1 = p.surfaceSubtle
        gray2 = p.surface
        gray3 = p.surfaceVariant
        gray4 = p.pressed
        gray5 = p.outline
        gray6 = p.disabled
        brightWhite = p.foreground
        white = p.foregroundMuted
        brightBlack = p.foregroundMuted
        red = p.red
        green = p.green
        yellow = p.yellow
        blue = p.blue
        magenta = p.magenta
        cyan = p.cyan
        orange = p.primary
        brightOrange = p.brightOrange ?? p.primary
        teal = p.teal
        brightRed = p.brightRed ?? red
        brightGreen = p.brightGreen ?? green
        brightYellow = p.brightYellow ?? yellow
        brightBlue = p.brightBlue ?? blue
        brightMagenta = p.brightMagenta ?? magenta
        brightCyan = p.brightCyan ?? cyan
        white = p.white ?? p.foregroundMuted
        hardBlack = p.shadow
        darkRed = p.darkRed ?? Qt.darker(red, 1.8)
        darkGreen = p.darkGreen ?? Qt.darker(green, 1.8)
        dimGreen = p.dimGreen ?? Qt.darker(green, 1.45)
        darkBlue = p.darkBlue ?? Qt.darker(blue, 1.8)
    }

    function applyPresetPalette() {
        let preset = activePreset
        if (!preset && themePresets.length > 0) {
            preset = themePresets[0]
            presetId = preset.id
            mode = preset.mode
        }
        if (!preset || !preset.colors)
            return
        const p = Object.assign({}, preset.colors, {
            primary: preset.colors.orange
        })
        applySemanticPalette(p)
    }

    function applyWallpaperPalette(data, propagateExternal) {
        const colors = data?.semantic
        const ansi = data?.ansi
        if (!colors || !Array.isArray(ansi) || ansi.length < 16)
            return
        if (light) {
            black = colors.background
            hardBlack = Qt.darker(colors.foreground, 2.5)
            gray1 = Qt.tint(colors.background, Qt.alpha(colors.foreground, 0.025))
            gray2 = colors["background-alt"]
            gray3 = Qt.tint(colors["background-alt"], Qt.alpha(colors.foreground, 0.05))
            gray4 = Qt.tint(colors["background-alt"], Qt.alpha(colors.foreground, 0.13))
            gray5 = colors.border
            gray6 = colors.disabled
            brightBlack = ansi[8]
            white = ansi[7]
            brightWhite = colors.foreground
            red = colors.alert
            green = ansi[2]
            yellow = ansi[3]
            blue = ansi[4]
            magenta = ansi[5]
            cyan = ansi[6]
            brightRed = ansi[9]
            brightGreen = ansi[10]
            brightYellow = ansi[11]
            brightBlue = colors.secondary
            brightMagenta = ansi[13]
            brightCyan = ansi[14]
            orange = colors.primary
            brightOrange = colors.primary
            teal = ansi[6]
        } else {
            black = colors.background
            hardBlack = colors.background
            gray1 = Qt.tint(colors.background, Qt.alpha(colors.foreground, 0.035))
            gray2 = colors["background-alt"]
            gray3 = Qt.tint(colors["background-alt"], Qt.alpha(colors.foreground, 0.07))
            gray4 = colors.border
            gray5 = Qt.tint(colors.border, Qt.alpha(colors.foreground, 0.10))
            gray6 = colors.disabled
            brightBlack = ansi[8]
            white = ansi[7]
            brightWhite = colors.foreground
            red = colors.alert
            green = ansi[2]
            yellow = ansi[3]
            blue = ansi[4]
            magenta = ansi[5]
            cyan = ansi[6]
            brightRed = ansi[9]
            brightGreen = ansi[10]
            brightYellow = ansi[11]
            brightBlue = colors.secondary
            brightMagenta = ansi[13]
            brightCyan = ansi[14]
            orange = colors.primary
            brightOrange = colors.primary
            teal = ansi[6]
        }
        darkRed = Qt.darker(red, 1.8)
        darkGreen = Qt.darker(green, 1.8)
        dimGreen = Qt.darker(green, 1.45)
        darkBlue = Qt.darker(blue, 1.8)
        if (propagateExternal !== false)
            applyExternalAccent(accentName)
    }

    function applyActivePalette(propagateExternal) {
        const palette = ShellState.state.theme.palette
        if (wallpaperThemeEnabled && wallpaperPaletteUsable(palette))
            applyWallpaperPalette(palette, propagateExternal)
        else
            applyPresetPalette()
    }

    function wallpaperPaletteUsable(palette) {
        return palette && String(palette.mode ?? "dark") === mode
            && palette.semantic && Array.isArray(palette.ansi)
            && palette.ansi.length >= 16
    }

    function loadState() {
        if (!ShellState.ready || !presetsReady)
            return
        const bar = ShellState.state.bar
        const theme = ShellState.state.theme
        barHeight = Math.min(80, Math.max(28, Number(bar.height) || 34))
        barUserScale = Math.min(2, Math.max(0.7, Number(bar.scale) || 1))
        barBackgroundOpacity = Math.min(1, Math.max(0,
            Number(bar.backgroundOpacity)))
        defaultAccentName = normalizedAccentName(theme.defaultAccent, "yellow")
        accentName = normalizedAccentName(theme.accent, "orange")
        customAccent = normalizeCustomAccent(theme.customAccent) || "#6574A8"
        usePresetAccent = theme.usePresetAccent !== false
        fontFamily = String(theme.fontFamily ?? "").trim()
            || defaultFontFamily
        mode = theme.mode === "light" ? "light" : "dark"
        const savedPreset = String(theme.preset ?? "")
        let selected = presetForId(savedPreset)
        if (!selected)
            selected = themePresets.find(preset => preset.mode === mode)
                ?? (themePresets.length > 0 ? themePresets[0] : null)
        if (selected) {
            presetId = selected.id
            mode = selected.mode
        }
        wallpaperThemeEnabled = theme.wallpaperEnabled === true
        cornerRadius = Math.max(0, Math.round(Number(theme.cornerRadius) || 0))
        cornerRadiusStateLoaded = true
        applyExternalCornerRadius()
        const palette = theme.palette
        const appearanceSignature = JSON.stringify({
            preset: presetId,
            mode: mode,
            wallpaperEnabled: wallpaperThemeEnabled,
            // Generator/toolkit metadata may arrive after the visible palette.
            // Only visual roles should trigger another desktop-wide rewrite.
            palette: palette ? {
                image: palette.image,
                mode: palette.mode,
                semantic: palette.semantic,
                ansi: palette.ansi
            } : null,
            accent: accentName,
            customAccent: customAccent,
            usePresetAccent: usePresetAccent
        })
        const appearanceChanged = appearanceSignature
            !== externalAppearanceSignature
        externalAppearanceSignature = appearanceSignature
        applyActivePalette(false)
        if (!wallpaperThemeEnabled || wallpaperPaletteUsable(palette))
            initialThemeResolved = true
        if (appearanceChanged)
            applyExternalAccent(accentName)
        if (wallpaperThemeEnabled && !wallpaperPaletteRefreshAttempted
                && (!palette?.image || palette?.generator !== "matugen")) {
            wallpaperPaletteRefreshAttempted = true
            const image = palette?.image
                ? String(palette.image)
                : root.packageConfigDir + "/wallpaper/minimal.png"
            runPaletteCommand([
                root.scriptsDir + "/theme/generate-wallpaper-theme",
                image, mode,
                "--wm-msg", Wm.msgPath
            ])
        }
        AppearanceService.ensureThemes(accent.toString())
    }

    Process {
        id: presetLoader
        running: true
        command: [root.scriptsDir + "/theme/load-theme-presets",
            root.packageConfigDir + "/themes/presets",
            root.configDir + "/themes/presets"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const loaded = JSON.parse(text)
                    root.themePresets = Array.isArray(loaded) ? loaded : []
                    if (root.themePresets.length === 0)
                        console.warn("theme presets: no valid presets found")
                } catch (error) {
                    console.warn("theme presets:", error)
                    root.themePresets = []
                }
                root.presetsReady = true
                root.loadState()
            }
        }
    }

    Process {
        id: applicationThemeProcess
        stderr: StdioCollector { id: applicationThemeError }
        onRunningChanged: {
            if (!running && command.length > 0) {
                const detail = applicationThemeError.text.trim()
                root.applicationThemeStatus = detail !== ""
                    ? detail : "Application theme applied"
            }
        }
    }

    Process {
        id: paletteProcess
        stderr: StdioCollector { id: paletteError }
        onExited: exitCode => {
            if (root.pendingPaletteCommand.length > 0) {
                Qt.callLater(() => root.startPendingPaletteCommand())
            } else if (exitCode === 0) {
                ShellState.reloadEffective()
            } else if (root.wallpaperThemeEnabled) {
                // A failed first-time generator falls back to the selected
                // preset instead of leaving the panel hidden indefinitely.
                root.initialThemeResolved = true
                const detail = paletteError.text.trim()
                console.warn("wallpaper theme:", detail !== ""
                    ? detail : "generator exited with " + exitCode)
            }
        }
    }

    Process {
        id: wallpaperPresetProcess
        stdout: StdioCollector { id: wallpaperPresetOutput }
        stderr: StdioCollector { id: wallpaperPresetError }
        onExited: exitCode => {
            if (exitCode === 0) {
                try {
                    const result = JSON.parse(wallpaperPresetOutput.text)
                    root.wallpaperPresetStatus = "Saved “" + result.name + "”"
                } catch (error) {
                    root.wallpaperPresetStatus = "Wallpaper preset saved"
                }
                presetLoader.running = false
                presetLoader.running = true
            } else {
                const detail = wallpaperPresetError.text.trim()
                root.wallpaperPresetStatus = detail !== ""
                    ? detail : "Could not save wallpaper preset"
            }
        }
    }

    Connections {
        target: ShellState
        function onStateChanged() { if (root.presetsReady) root.loadState() }
        function onReadyChanged() {
            if (ShellState.ready && root.presetsReady) root.loadState()
        }
    }

    Connections {
        target: Wm
        function onCapabilitiesChanged() { root.applyExternalCornerRadius() }
        function onBackendNameChanged() { root.applyExternalCornerRadius() }
        function onConnectedChanged() {
            if (!Wm.connected) return
            root.applyExternalAccent(root.accentName)
            // A restarted WM has lost live-only settings even when its backend
            // name and advertised capabilities are unchanged.
            root.appliedCornerRadiusWindowReady = false
            root.applyExternalCornerRadius()
        }
    }
}
