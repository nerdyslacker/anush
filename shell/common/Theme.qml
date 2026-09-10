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

    // Bar controls stay visually identical to their appearance on a fully
    // opaque bar even when the panel background itself is translucent.
    function barSurface(opacity) {
        return Qt.tint(root.bg, Qt.alpha(root.fg, opacity))
    }
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

    readonly property color bg: black
    readonly property color altbg: gray2
    readonly property color fg: brightWhite
    readonly property color border: gray4
    readonly property color primary: orange
    readonly property color secondary: brightBlue
    readonly property color alert: red
    readonly property color disabled: gray6

    readonly property var accentNames: [
        "orange", "red", "green", "yellow", "blue", "magenta", "cyan",
        "brightOrange", "brightRed", "brightGreen", "brightYellow",
        "brightBlue", "brightMagenta", "brightCyan"
    ]
    property string accentName: "orange"
    readonly property color accent: accentColor(accentName)
    readonly property color selbg: accent
    readonly property color selfg: hardBlack

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
                    image
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
                "--default", accent.toString()
            ])
        }
    }

    function applySrceryPalette() {
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
        darkGreen = "#294229"
        darkRed = "#4F2321"
        darkBlue = "#1E5181"
        dimGreen = "#2E5C2E"
        orange = "#FF5F00"
        brightOrange = "#FF8700"
        teal = "#008080"
        gray1 = "#1C1B19"
        gray2 = "#262522"
        gray3 = "#312F2C"
        gray4 = "#3B3935"
        gray5 = "#45433E"
        gray6 = "#504D47"
        hardBlack = "#0E0D0C"
    }

    function applyWallpaperPalette(data) {
        const colors = data?.semantic
        const ansi = data?.ansi
        if (!colors || !Array.isArray(ansi) || ansi.length < 16)
            return
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
        darkRed = Qt.darker(colors.alert, 1.8)
        darkGreen = Qt.darker(ansi[2], 1.8)
        dimGreen = Qt.darker(ansi[2], 1.45)
        darkBlue = Qt.darker(colors.secondary, 1.8)
        teal = ansi[6]
        // Keep the user's accent slot selected; its color now comes from the
        // generated palette and is propagated to external components too.
        applyExternalAccent(accentName)
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
        wallpaperThemeEnabled = theme.wallpaperEnabled === true
        if (wallpaperThemeEnabled && theme.palette)
            applyWallpaperPalette(theme.palette)
        else
            applySrceryPalette()
        _barStateLoads = 2
    }

    Connections {
        target: ShellState
        function onStateChanged() { root.loadState() }
        function onReadyChanged() { if (ShellState.ready) root.loadState() }
    }

    Component.onCompleted: if (ShellState.ready) loadState()
}
