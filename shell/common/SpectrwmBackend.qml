import QtQuick
import ".."

EwmhBackend {
    name: "spectrwm"
    profile: "spectrwm"
    layouts: [
        { name: "Vertical", glyph: "󰙀", command: "vertical" },
        { name: "Horizontal", glyph: "󱥣", command: "horizontal" },
        { name: "Max", glyph: "󰍹", command: "max" },
        { name: "Floating", glyph: "󰕰", command: "floating" }
    ]
}
