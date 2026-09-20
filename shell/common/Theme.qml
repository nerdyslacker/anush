pragma Singleton
import QtQuick
import ".."
import Quickshell

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
    property string defaultAccentName: "brightYellow"
    property string presetId: "srcery-dark"
    property string mode: "dark"
    readonly property bool light: mode === "light"
    // A single persisted appearance value feeds every non-circular surface.
    // Keep the tiers integral so borders and clipping stay pixel-aligned.
    property int cornerRadius: 0
    readonly property int radiusSmall: Math.round(cornerRadius * 0.5)
    readonly property int radiusMedium: cornerRadius
    readonly property int radiusLarge: Math.round(cornerRadius * 1.5)
    readonly property int surfaceGap: 8

    // Do not expose the bar until the persisted appearance has been applied.
    // A timed fallback here used to reveal the default palette when state
    // migration or disk I/O took longer than one second at login.
    property bool _appearanceLoaded: false
    readonly property bool barStateReady:
        ShellState.ready && _appearanceLoaded

    property color black: "#121110"
    property color red: "#EF2F27"
    property color green: "#519F50"
    property color yellow: "#FBB829"
    property color blue: "#2C78BF"
    property color magenta: "#E02C6D"
    property color cyan: "#0AAEB3"
    property color white: "#C5B088"

    property color brightBlack: "#917E6B"
    property color brightRed: "#F75341"
    property color brightGreen: "#98BC37"
    property color brightYellow: "#FED06E"
    property color brightBlue: "#68A8E4"
    property color brightMagenta: "#FF5C8F"
    property color brightCyan: "#2BE4D0"

    property color brightWhite: "#FCE8C3"

    property color darkGreen: "#294229"
    property color darkRed: "#4F2321"
    property color darkBlue: "#1E5181"
    property color dimGreen: "#2E5C2E"
    property color orange: "#FF5F00"
    property color brightOrange: "#FF8700"
    property color teal: "#008080"
    property color gray1: "#1C1B19"
    property color gray2: "#262522"
    property color gray3: "#312F2C"
    property color gray4: "#3B3935"
    property color gray5: "#45433E"
    property color gray6: "#504D47"
    property color hardBlack: "#0E0D0C"

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
        "brightOrange", "brightRed", "brightGreen", "brightYellow",
        "brightBlue", "brightMagenta", "brightCyan"
    ]
    property string accentName: "orange"
    // Classic deliberately separates its selected fill from its hard active
    // border, matching the raised controls of classic desktop interfaces.
    readonly property color accent: !wallpaperThemeEnabled && presetId === "classic"
        ? "#546364" : accentColor(accentName)
    readonly property color activeBackground: !wallpaperThemeEnabled
            && presetId === "classic"
        ? "#546364" : accent
    readonly property color activeBorder: !wallpaperThemeEnabled
            && presetId === "classic"
        ? "#152526" : accent
    readonly property color selbg: activeBackground
    readonly property color accentForeground: !wallpaperThemeEnabled
            && presetId === "classic"
        ? "#DFDCDB" : light ? "#FCE8C3" : hardBlack
    readonly property color selfg: accentForeground

    readonly property var themePresets: [
        { id: "srcery-dark", name: "Srcery Dark", mode: "dark",
            colors: ["#121110", "#262522", "#FF5F00"] },
        { id: "srcery-light", name: "Srcery Light", mode: "light",
            colors: ["#FCE8C3", "#EED7AE", "#B23F00"] },
        { id: "catppuccin-dark", name: "Catppuccin Mocha", mode: "dark",
            colors: ["#1E1E2E", "#313244", "#CBA6F7"] },
        { id: "catppuccin-light", name: "Catppuccin Latte", mode: "light",
            colors: ["#EFF1F5", "#CCD0DA", "#8839EF"] },
        { id: "gruvbox-dark", name: "Gruvbox Dark", mode: "dark",
            colors: ["#282828", "#3C3836", "#D79921"] },
        { id: "gruvbox-light", name: "Gruvbox Light", mode: "light",
            colors: ["#FBF1C7", "#EBDBB2", "#B57614"] },
        { id: "everforest-dark", name: "Everforest Dark", mode: "dark",
            colors: ["#2D353B", "#3D484D", "#A7C080"] },
        { id: "everforest-light", name: "Everforest Light", mode: "light",
            colors: ["#FDF6E3", "#EFEBD4", "#8DA101"] },
        { id: "classic", name: "Classic", mode: "light",
            colors: ["#C9C8C6", "#DFDCDB", "#546364"] }
    ]

    // Bar controls stay visually identical to their appearance on a fully
    // opaque bar even when the panel background itself is translucent.
    function barSurface(opacity) {
        if (!wallpaperThemeEnabled && presetId === "classic")
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
        const selected = !wallpaperThemeEnabled && presetId === "classic"
            ? accent : accentColor(name)
        Quickshell.execDetached([
            root.scriptsDir + "/apply-accent",
            selected.toString(),
            Wm.msgPath
        ])
        Quickshell.execDetached([
            root.scriptsDir + "/apply-icon-theme",
            selected.toString()
        ])
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

    function persistThemeMode(value) {
        const next = value === "light" ? "light" : "dark"
        const family = String(presetId).split("-")[0]
        const paired = family === "classic" ? "srcery-" + next
            : family + "-" + next
        if (presetForId(paired))
            presetId = paired
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
        } else if (!wallpaperThemeEnabled && presetId.startsWith("srcery-")) {
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
            if (presetId.startsWith("srcery-")) {
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
        brightOrange = p.primary
        teal = p.teal
        brightRed = Qt.lighter(red, 1.12)
        brightGreen = Qt.lighter(green, 1.12)
        brightYellow = Qt.lighter(yellow, 1.12)
        brightBlue = Qt.lighter(blue, 1.12)
        brightMagenta = Qt.lighter(magenta, 1.12)
        brightCyan = Qt.lighter(cyan, 1.12)
        hardBlack = p.shadow
        darkRed = Qt.darker(red, 1.8)
        darkGreen = Qt.darker(green, 1.8)
        dimGreen = Qt.darker(green, 1.45)
        darkBlue = Qt.darker(blue, 1.8)
    }

    function applyPresetPalette() {
        if (presetId.startsWith("srcery-")) {
            applySrceryPalette()
            return
        }
        switch (presetId) {
        case "catppuccin-dark":
            applySemanticPalette({ background: "#1E1E2E", surfaceSubtle: "#181825",
                surface: "#313244", surfaceVariant: "#45475A", pressed: "#585B70",
                outline: "#6C7086", disabled: "#7F849C", foreground: "#CDD6F4",
                foregroundMuted: "#A6ADC8", red: "#F38BA8", green: "#A6E3A1",
                yellow: "#F9E2AF", blue: "#89B4FA", magenta: "#CBA6F7",
                cyan: "#89DCEB", primary: "#FAB387", teal: "#94E2D5", shadow: "#11111B" })
            break
        case "catppuccin-light":
            applySemanticPalette({ background: "#EFF1F5", surfaceSubtle: "#E6E9EF",
                surface: "#DCE0E8", surfaceVariant: "#CCD0DA", pressed: "#BCC0CC",
                outline: "#9CA0B0", disabled: "#ACB0BE", foreground: "#4C4F69",
                foregroundMuted: "#6C6F85", red: "#D20F39", green: "#40A02B",
                yellow: "#DF8E1D", blue: "#1E66F5", magenta: "#8839EF",
                cyan: "#04A5E5", primary: "#FE640B", teal: "#179299", shadow: "#7C7F93" })
            break
        case "gruvbox-dark":
            applySemanticPalette({ background: "#282828", surfaceSubtle: "#1D2021",
                surface: "#3C3836", surfaceVariant: "#504945", pressed: "#665C54",
                outline: "#7C6F64", disabled: "#928374", foreground: "#EBDBB2",
                foregroundMuted: "#A89984", red: "#CC241D", green: "#98971A",
                yellow: "#D79921", blue: "#458588", magenta: "#B16286",
                cyan: "#689D6A", primary: "#D65D0E", teal: "#8EC07C", shadow: "#1D2021" })
            break
        case "gruvbox-light":
            applySemanticPalette({ background: "#FBF1C7", surfaceSubtle: "#F9F5D7",
                surface: "#EBDBB2", surfaceVariant: "#D5C4A1", pressed: "#BDAE93",
                outline: "#A89984", disabled: "#928374", foreground: "#3C3836",
                foregroundMuted: "#665C54", red: "#9D0006", green: "#79740E",
                yellow: "#B57614", blue: "#076678", magenta: "#8F3F71",
                cyan: "#427B58", primary: "#AF3A03", teal: "#427B58", shadow: "#7C6F64" })
            break
        case "everforest-dark":
            applySemanticPalette({ background: "#2D353B", surfaceSubtle: "#232A2E",
                surface: "#343F44", surfaceVariant: "#3D484D", pressed: "#475258",
                outline: "#56635F", disabled: "#7A8478", foreground: "#D3C6AA",
                foregroundMuted: "#9DA9A0", red: "#E67E80", green: "#A7C080",
                yellow: "#DBBC7F", blue: "#7FBBB3", magenta: "#D699B6",
                cyan: "#83C092", primary: "#E69875", teal: "#83C092", shadow: "#1E2326" })
            break
        case "everforest-light":
            applySemanticPalette({ background: "#FDF6E3", surfaceSubtle: "#F4F0D9",
                surface: "#EFEBD4", surfaceVariant: "#E6E2CC", pressed: "#D8D3BA",
                outline: "#B9C0AB", disabled: "#939F91", foreground: "#5C6A72",
                foregroundMuted: "#829181", red: "#F85552", green: "#8DA101",
                yellow: "#DFA000", blue: "#3A94C5", magenta: "#DF69BA",
                cyan: "#35A77C", primary: "#F57D26", teal: "#35A77C", shadow: "#A6B0A0" })
            break
        case "classic":
            applySemanticPalette({ background: "#C9C8C6", surfaceSubtle: "#D2D0CE",
                surface: "#DFDCDB", surfaceVariant: "#E8E5E4", pressed: "#B8B5B2",
                outline: "#7A7774", disabled: "#A4A09D", foreground: "#152526",
                foregroundMuted: "#546364", red: "#8B1E1E", green: "#27613B",
                yellow: "#8A6500", blue: "#000080", magenta: "#800080",
                cyan: "#007C7C", primary: "#152526", teal: "#008080", shadow: "#6B6967" })
            break
        default:
            presetId = mode === "light" ? "srcery-light" : "srcery-dark"
            applySrceryPalette()
        }
    }

    function applySrceryPalette() {
        if (light) {
            // Srcery light keeps the canonical warm cream/ink endpoints and
            // darkens its hue families enough for readable text and icons.
            black = "#FCE8C3"
            red = "#B7241F"
            green = "#356B35"
            yellow = "#7A5700"
            blue = "#245F96"
            magenta = "#A51E50"
            cyan = "#067176"
            white = "#504D47"
            brightBlack = "#66594C"
            brightRed = "#C03027"
            brightGreen = "#527000"
            brightYellow = "#7A5700"
            brightBlue = "#3068A3"
            brightMagenta = "#B62D5C"
            brightCyan = "#077276"
            brightWhite = "#121110"
            orange = "#B23F00"
            brightOrange = "#B54700"
            teal = "#006A6A"
            gray1 = "#F6DFB7"
            gray2 = "#EED7AE"
            gray3 = "#E3CAA0"
            gray4 = "#D5B98E"
            gray5 = "#A68F73"
            gray6 = "#776858"
        } else {
            black = "#121110"
            red = "#EF2F27"
            green = "#519F50"
            yellow = "#FBB829"
            blue = "#2C78BF"
            magenta = "#E02C6D"
            cyan = "#0AAEB3"
            white = "#C5B088"
            brightBlack = "#917E6B"
            brightRed = "#F75341"
            brightGreen = "#98BC37"
            brightYellow = "#FED06E"
            brightBlue = "#68A8E4"
            brightMagenta = "#FF5C8F"
            brightCyan = "#2BE4D0"
            brightWhite = "#FCE8C3"
            orange = "#FF5F00"
            brightOrange = "#FF8700"
            teal = "#008080"
            gray1 = "#1C1B19"
            gray2 = "#262522"
            gray3 = "#312F2C"
            gray4 = "#3B3935"
            gray5 = "#45433E"
            gray6 = "#504D47"
        }
        darkGreen = "#294229"
        darkRed = "#4F2321"
        darkBlue = "#1E5181"
        dimGreen = "#2E5C2E"
        hardBlack = "#0E0D0C"
    }

    function applyWallpaperPalette(data) {
        const colors = data?.semantic
        const ansi = data?.ansi
        if (!colors || !Array.isArray(ansi) || ansi.length < 16)
            return
        if (light) {
            black = colors.background
            hardBlack = "#0E0D0C"
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
        const bar = ShellState.state.bar
        const theme = ShellState.state.theme
        barHeight = Math.min(80, Math.max(28, Number(bar.height) || 34))
        barUserScale = Math.min(2, Math.max(0.7, Number(bar.scale) || 1))
        barBackgroundOpacity = Math.min(1, Math.max(0,
            Number(bar.backgroundOpacity)))
        defaultAccentName = accentNames.indexOf(theme.defaultAccent) >= 0
            ? theme.defaultAccent : "brightYellow"
        accentName = accentNames.indexOf(theme.accent) >= 0
            ? theme.accent : "orange"
        mode = theme.mode === "light" ? "light" : "dark"
        const savedPreset = String(theme.preset ?? "")
        presetId = presetForId(savedPreset) ? savedPreset
            : mode === "light" ? "srcery-light" : "srcery-dark"
        mode = presetForId(presetId).mode
        wallpaperThemeEnabled = theme.wallpaperEnabled === true
        cornerRadius = Math.max(0, Math.round(Number(theme.cornerRadius) || 0))
        applyActivePalette()
        Quickshell.execDetached([
            root.scriptsDir + "/apply-icon-theme",
            accent.toString()
        ])
        _appearanceLoaded = true
    }

    Connections {
        target: ShellState
        function onStateChanged() { root.loadState() }
        function onReadyChanged() { if (ShellState.ready) root.loadState() }
    }

    Component.onCompleted: if (ShellState.ready) loadState()
}
