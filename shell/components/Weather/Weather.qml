import QtQuick
import "../.."
import Quickshell.Io

// Weather: condition glyph + temperature from wttr.in (no API key),
// refreshed every 30 minutes. Click for the 3-day forecast card — same
// fetch, no extra requests. Fetch failures leave a visible status module so
// weather settings and manual retry remain reachable.
//
// An empty location lets wttr.in locate by IP. Empty units use the locale.
BarModule {
    id: root

    visible: BarVisibility.enabled("weather")

    property string temp: ""
    property int code: 113
    property bool fetchFailed: false
    readonly property bool hasWeather: temp !== ""
    readonly property string requestUrl: "https://wttr.in/"
        + encodeURIComponent(location) + "?format=j1"

    property string unitsOverride: ""
    property string location: ""
    readonly property bool useF: unitsOverride === "f" ? true
                               : unitsOverride === "c" ? false
                               : Qt.locale().measurementSystem !== Locale.MetricSystem

    function loadSettings() {
        const nextUnits = String(ShellState.state.weather.units ?? "").toLowerCase()
        const nextLocation = String(ShellState.state.weather.location ?? "")
        const changed = location !== nextLocation
        unitsOverride = nextUnits === "c" || nextUnits === "f" ? nextUnits : ""
        location = nextLocation
        if (changed && fetch.running !== undefined) {
            fetch.running = false
            fetch.running = true
        }
    }

    Connections {
        target: ShellState
        function onStateChanged() { root.loadSettings() }
        function onReadyChanged() { if (ShellState.ready) root.loadSettings() }
    }

    Component.onCompleted: if (ShellState.ready) loadSettings()

    property var lastJson: null
    onUseFChanged: if (lastJson) parse(lastJson)

    // WWO condition codes → a handful of glyph buckets
    function glyphFor(c) {
        if ([200, 386, 389, 392, 395].indexOf(c) !== -1) return "󰖓"
        if ([179, 182, 185, 227, 230, 317, 320, 323, 326, 329, 332, 335,
             338, 350, 368, 371, 374, 377].indexOf(c) !== -1) return "󰖘"
        if ([143, 248, 260].indexOf(c) !== -1) return "󰖑"
        if (c === 113) return "󰖙"
        if (c === 116) return "󰖕"
        if (c === 119 || c === 122) return "󰖐"
        return "󰖗"  // everything else in WWO's table is some kind of rain
    }

    icon: hasWeather ? glyphFor(code) : "󰖐"
    iconColor: fetchFailed && !hasWeather ? Theme.red
        : hasWeather ? Theme.yellow : Theme.brightBlack
    label: hasWeather ? temp + "°" : fetch.running ? "…" : "!"

    onClicked: mouse => {
        if (mouse.button === Qt.RightButton) {
            forecast.visible = false
            settings.openSettings()
        } else {
            settings.visible = false
            if (!root.hasWeather && !fetch.running) {
                fetch.running = false
                fetch.running = true
            }
            forecast.visible = !forecast.visible
        }
    }

    WeatherPopup {
        id: forecast
        anchorItem: root
        loading: fetch.running && !root.hasWeather
        unavailable: root.fetchFailed && !root.hasWeather
    }

    WeatherSettings {
        id: settings
        anchorItem: root
    }

    property string _buf: ""
    Process {
        id: fetch
        // Verify TLS normally. If wttr.in specifically fails certificate
        // validation (curl 60), retry the same HTTPS URL without validation;
        // the response is parsed as data and never executed.
        command: ["sh", "-c",
            "curl -sfL -m 10 --proto '=https' \"$1\"; " +
            "status=$?; if [ \"$status\" -eq 60 ]; then " +
            "exec curl -skfL -m 10 --proto '=https' \"$1\"; fi; " +
            "exit \"$status\"",
            "weather-fetch", root.requestUrl]
        running: true
        stdout: SplitParser {
            onRead: line => root._buf += line
        }
        onRunningChanged: {
            if (running) {
                root._buf = ""
                if (!root.hasWeather)
                    root.fetchFailed = false
            } else {
                try {
                    root.parse(JSON.parse(root._buf))
                } catch (e) {
                    root.fetchFailed = true
                    retry.restart() // network hiccup — try again soon
                }
            }
        }
    }

    function parse(j) {
        if (!j?.current_condition?.length)
            throw new Error("weather response has no current condition")
        lastJson = j
        const f = useF
        const c = j.current_condition[0]
        temp = f ? c.temp_F : c.temp_C
        code = parseInt(c.weatherCode) || 113
        forecast.condition = c.weatherDesc?.[0]?.value ?? ""
        const a = j.nearest_area?.[0]
        forecast.place = a ? [a.areaName?.[0]?.value,
                              a.region?.[0]?.value || a.country?.[0]?.value]
                              .filter(Boolean).join(", ") : ""
        forecast.feels = (f ? c.FeelsLikeF : c.FeelsLikeC) ?? ""
        forecast.wind = f ? (c.windspeedMiles ? c.windspeedMiles + "mph" : "")
                          : (c.windspeedKmph ? c.windspeedKmph + "km/h" : "")

        const days = []
        const names = ["today", "tomorrow"]
        for (let i = 0; i < Math.min(3, (j.weather ?? []).length); i++) {
            const d = j.weather[i]
            const noon = d.hourly?.[4] ?? d.hourly?.[0] ?? {}
            let rain = 0
            for (const h of d.hourly ?? [])
                rain = Math.max(rain, parseInt(h.chanceofrain) || 0)
            days.push({
                label: names[i] ?? new Date(d.date + "T12:00").toLocaleDateString(Qt.locale(), "ddd"),
                glyph: glyphFor(parseInt(noon.weatherCode) || 113),
                hi: (f ? d.maxtempF : d.maxtempC) ?? "?",
                lo: (f ? d.mintempF : d.mintempC) ?? "?",
                rain: rain
            })
        }
        forecast.days = days
        fetchFailed = false
    }

    Timer {
        interval: 30 * 60 * 1000
        repeat: true
        running: true
        onTriggered: { fetch.running = false; fetch.running = true }
    }
    Timer {
        id: retry
        interval: 3 * 60 * 1000
        onTriggered: { fetch.running = false; fetch.running = true }
    }
}
