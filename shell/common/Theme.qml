pragma Singleton
import QtQuick
import ".."
import Quickshell
import Quickshell.Io

// Canonical Srcery palette from SRCERY.md. Semantic colors used by the
// modules below are aliases of this palette, so every component stays in
// the same theme without depending on another desktop configuration.
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
    property string mode: "dark"
    readonly property bool light: mode === "light"
    // A single persisted appearance value feeds every non-circular surface.
    // Keep the tiers integral so borders and clipping stay pixel-aligned.
    property int cornerRadius: 0
    readonly property int radiusSmall: Math.round(cornerRadius * 0.5)
    readonly property int radiusMedium: cornerRadius
    readonly property int radiusLarge: Math.round(cornerRadius * 1.5)

    property int _barStateLoads: 0
    readonly property bool barStateReady: _barStateLoads >= 2
    Timer {
        running: !root.barStateReady
        interval: 1000
        onTriggered: root._barStateLoads = 2
    }

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
    readonly property color accent: accentColor(accentName)
    readonly property color selbg: accent
    readonly property color accentForeground: light ? "#FCE8C3" : hardBlack
    readonly property color selfg: accentForeground

    // Bar controls stay visually identical to their appearance on a fully
    // opaque bar even when the panel background itself is translucent.
    function barSurface(opacity) {
        return Qt.tint(root.background, Qt.alpha(root.foreground, opacity))
    }

    readonly property string fontFamily: "JetBrainsMono Nerd Font"

    readonly property real barScale: barUserScale
    readonly property int fontSize: Math.round(12 * barScale)
    readonly property int moduleHeight: Math.round(28 * barScale)
    readonly property int iconSize: Math.round(moduleHeight * 0.61)
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
        const selected = accentColor(name)
        Quickshell.execDetached([
            root.scriptsDir + "/apply-accent",
            selected.toString(),
            Wm.msgPath
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
        mode = next
        applyActivePalette()
        ShellState.updateSection("theme", { mode: next })

        const palette = ShellState.state.theme.palette
        if (wallpaperThemeEnabled && palette?.image) {
            Quickshell.execDetached([
                root.scriptsDir + "/generate-wallpaper-theme",
                String(palette.image), next,
                "--wm-msg", Wm.msgPath
            ])
        } else if (!wallpaperThemeEnabled) {
            Quickshell.execDetached([
                root.scriptsDir + "/generate-wallpaper-theme",
                "--default", next, accent.toString(),
                "--wm-msg", Wm.msgPath
            ])
        }
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
            applySrceryPalette()
            accentName = defaultAccentName
            ShellState.updateSection("theme", { accent: accentName })
            Quickshell.execDetached([
                root.scriptsDir + "/generate-wallpaper-theme",
                "--default", mode, accent.toString(),
                "--wm-msg", Wm.msgPath
            ])
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
            applySrceryPalette()
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
        wallpaperThemeEnabled = theme.wallpaperEnabled === true
        cornerRadius = Math.max(0, Math.round(Number(theme.cornerRadius) || 0))
        applyActivePalette()
        _barStateLoads = 2
    }

    Connections {
        target: ShellState
        function onStateChanged() { root.loadState() }
        function onReadyChanged() { if (ShellState.ready) root.loadState() }
    }

    Component.onCompleted: if (ShellState.ready) loadState()
}
