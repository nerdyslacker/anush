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
    readonly property string configDir: {
        const configured = String(Quickshell.env("ANUSH_CONFIG_DIR") ?? "")
        return configured !== "" ? configured : ShellState.shellDir + "/../config"
    }
    readonly property string stateDir: ShellState.stateDir
    readonly property string scriptsDir: ShellState.scriptsDir

    property int barHeight: 34
    property real barUserScale: 1.0
    property real barBackgroundOpacity: 1.0
    property bool wallpaperThemeEnabled: false
    property string defaultAccentName: "yellow"
    property string presetId: "srcery-dark"
    property string mode: "dark"
    property var themePresets: []
    property bool presetsReady: false
    property string applicationThemeStatus: ""
    readonly property var activePreset: presetForId(presetId)
    readonly property bool matugenThemeGenerated:
        wallpaperThemeEnabled
        && ShellState.state.theme.palette?.generator === "matugen"
    readonly property bool applicationThemeApplying: applicationThemeProcess.running
    readonly property bool light: mode === "light"
    // A single persisted appearance value feeds every non-circular surface.
    // Keep the tiers integral so borders and clipping stay pixel-aligned.
    property int cornerRadius: 0
    readonly property int radiusSmall: Math.round(cornerRadius * 0.5)
    readonly property int radiusMedium: cornerRadius
    readonly property int radiusLarge: Math.round(cornerRadius * 1.5)
    readonly property int surfaceGap: 8

    // Preset files load asynchronously. Never make a helper failure hide the
    // panel; the bootstrap palette is replaced as soon as loading completes.
    readonly property bool barStateReady: ShellState.ready

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
        "orange", "red", "green", "yellow", "blue", "magenta", "cyan"
    ]
    property string accentName: "orange"
    readonly property color accent: !wallpaperThemeEnabled
            && activePreset?.accentOverride
        ? activePreset.accentOverride : mutedAccentColor(accentName)
    readonly property color activeBackground: !wallpaperThemeEnabled
            && activePreset?.activeBackground
        ? activePreset.activeBackground : accent
    readonly property color activeBorder: !wallpaperThemeEnabled
            && activePreset?.activeBorder
        ? activePreset.activeBorder : accent
    readonly property color selbg: activeBackground
    readonly property color accentForeground: !wallpaperThemeEnabled
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

    readonly property string fontFamily: "JetBrainsMono Nerd Font"
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

    function mutedAccentColor(name) {
        const base = accentColor(normalizedAccentName(name, "orange"))
        const neutral = foregroundMuted
        const neutralAmount = 0.20
        const baseAmount = 1.0 - neutralAmount
        return Qt.rgba(
            base.r * baseAmount + neutral.r * neutralAmount,
            base.g * baseAmount + neutral.g * neutralAmount,
            base.b * baseAmount + neutral.b * neutralAmount,
            1.0)
    }

    function setAccent(name) {
        if (accentNames.indexOf(name) < 0)
            return
        accentName = name
        ShellState.updateSection("theme", { accent: name })
        if (!wallpaperThemeEnabled) {
            defaultAccentName = name
            ShellState.updateSection("theme", { defaultAccent: name })
        }
        applyExternalAccent(name)
    }

    function applyExternalAccent(name) {
        const selected = !wallpaperThemeEnabled && activePreset?.accentOverride
            ? accent : mutedAccentColor(name)
        Quickshell.execDetached([
            root.scriptsDir + "/apply-accent",
            selected.toString(),
            Wm.msgPath
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

    function persistCornerRadius(value) {
        cornerRadius = Math.max(0, Math.round(Number(value) || 0))
        ShellState.updateSection("theme", { cornerRadius: cornerRadius })
        Quickshell.execDetached([
            root.scriptsDir + "/apply-corner-radius",
            String(cornerRadius),
            Wm.msgPath
        ])
    }

    function applyApplicationTheme(toolkit) {
        const target = String(toolkit)
        if (!matugenThemeGenerated || ["gtk", "qt", "all"].indexOf(target) < 0)
            return
        applicationThemeProcess.running = false
        applicationThemeProcess.command = [
            root.scriptsDir + "/apply-application-theme", target
        ]
        applicationThemeStatus = "Applying " + target.toUpperCase() + " theme…"
        applicationThemeProcess.running = true
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
            Quickshell.execDetached([
                root.scriptsDir + "/generate-wallpaper-theme",
                String(palette.image), next,
                "--wm-msg", Wm.msgPath
            ])
        } else if (!wallpaperThemeEnabled
                && activePreset?.generatorDefault === true) {
            Quickshell.execDetached([
                root.scriptsDir + "/generate-wallpaper-theme",
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
        applyPresetPalette()
        ShellState.updateSection("theme", {
            preset: presetId,
            mode: mode,
            wallpaperEnabled: false
        })
        applyExternalAccent(accentName)
    }

    function persistWallpaperThemeEnabled(enabled, wallpaperPath) {
        if (enabled && !wallpaperThemeEnabled) {
            defaultAccentName = accentName
            ShellState.updateSection("theme", { defaultAccent: accentName })
        }
        wallpaperThemeEnabled = enabled
        ShellState.updateSection("theme", { wallpaperEnabled: enabled })
        if (enabled) {
            const image = String(wallpaperPath ?? "")
            if (image !== "") {
                Quickshell.execDetached([
                    root.scriptsDir + "/generate-wallpaper-theme",
                    image, mode,
                    "--wm-msg", Wm.msgPath
                ])
            } else {
                loadState()
            }
        } else {
            applyPresetPalette()
            accentName = defaultAccentName
            ShellState.updateSection("theme", { accent: accentName })
            if (activePreset?.generatorDefault === true) {
                Quickshell.execDetached([
                    root.scriptsDir + "/generate-wallpaper-theme",
                    "--default", mode, accent.toString(),
                    "--wm-msg", Wm.msgPath
                ])
            } else {
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

    function applyWallpaperPalette(data) {
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
        // Keep the user's accent slot selected; its color now comes from the
        // generated palette and is propagated to external components too.
        applyExternalAccent(accentName)
    }

    function applyActivePalette() {
        const palette = ShellState.state.theme.palette
        if (wallpaperThemeEnabled && palette
                && String(palette.mode ?? "dark") === mode)
            applyWallpaperPalette(palette)
        else
            applyPresetPalette()
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
        applyActivePalette()
        AppearanceService.ensureThemes(accent.toString())
    }

    Process {
        id: presetLoader
        running: true
        command: [root.scriptsDir + "/load-theme-presets",
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

    Connections {
        target: ShellState
        function onStateChanged() { if (root.presetsReady) root.loadState() }
        function onReadyChanged() {
            if (ShellState.ready && root.presetsReady) root.loadState()
        }
    }
}
