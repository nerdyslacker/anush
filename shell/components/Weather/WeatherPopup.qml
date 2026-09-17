import QtQuick
import "../.."

import Quickshell.Io
// Three-day forecast under the weather indicator — the calendar idiom:
// click the number, get the picture. Data comes from the same wttr.in
// fetch the bar module already makes; no extra requests.
Popout {
    id: root

    property string condition: ""
    property string feels: ""
    property string wind: ""
    property string place: ""
    property var days: []   // {label, glyph, hi, lo, rain}
    property bool loading: false
    property bool unavailable: false

    cardWidth: 300
    cardHeight: 168

    // Scriptable with: qs -p <quickshell-dir> ipc call weather toggle
    IpcHandler {
        target: "weather"
        function toggle(): void { root.visible = !root.visible }
    }

    Text {
        anchors.centerIn: parent
        visible: root.days.length === 0
        horizontalAlignment: Text.AlignHCenter
        text: root.loading ? "Loading weather…"
            : root.unavailable ? "Weather unavailable\nClick the bar widget to retry"
            : "No forecast data"
        color: root.unavailable ? Theme.red : Theme.brightBlack
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontSize
    }

    // where this forecast is for — also the tell when a VPN exit node is
    // fooling wttr.in's IP geolocation
    Row {
        id: placeLine
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        visible: root.days.length > 0 && root.place !== ""
        spacing: 5
        Text {
            text: "󰍎"
            color: Qt.alpha(Theme.fg, 0.5)
            font.family: Theme.iconFontFamily
            font.pixelSize: Theme.iconSizeSmall
        }
        Text {
            width: parent.width - x
            text: root.place
            color: Qt.alpha(Theme.fg, 0.5)
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSize - 2
            elide: Text.ElideRight
        }
    }

    // current condition · feels like · wind
    Row {
        id: header
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: placeLine.visible ? placeLine.bottom : parent.top
        anchors.topMargin: placeLine.visible ? 4 : 0
        visible: root.days.length > 0
        spacing: 6
        Text {
            width: parent.width - windLine.width - (windLine.visible ? parent.spacing : 0)
            text: root.condition
                + (root.feels !== "" ? "  ·  feels " + root.feels + "°" : "")
            color: Theme.fg
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSize
            font.bold: true
            elide: Text.ElideRight
        }
        Row {
            id: windLine
            visible: root.wind !== ""
            spacing: 4
            Text {
                text: "󰖝"
                color: Theme.fg
                font.family: Theme.iconFontFamily
                font.pixelSize: Theme.iconSizeSmall
            }
            Text {
                text: root.wind
                color: Theme.fg
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSize
                font.bold: true
            }
        }
    }

    Row {
        visible: root.days.length > 0
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: header.bottom
        anchors.topMargin: 12
        anchors.bottom: parent.bottom

        Repeater {
            model: root.days

            Column {
                id: day
                required property var modelData
                width: parent.width / Math.max(root.days.length, 1)
                spacing: 5

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: day.modelData.label
                    color: Qt.alpha(Theme.fg, 0.55)
                    font.family: Theme.fontFamily
                    font.pixelSize: 11
                }
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: day.modelData.glyph
                    color: Theme.yellow
                    font.family: Theme.iconFontFamily
                    font.pixelSize: Theme.iconSizeLarge
                }
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: day.modelData.hi + "° / " + day.modelData.lo + "°"
                    color: Theme.fg
                    font.family: Theme.fontFamily
                    font.pixelSize: 12
                }
                Row {
                    anchors.horizontalCenter: parent.horizontalCenter
                    visible: day.modelData.rain >= 30
                    spacing: 4
                    Text {
                        text: "󰖌"
                        color: Theme.cyan
                        font.family: Theme.iconFontFamily
                        font.pixelSize: Theme.iconSizeSmall
                    }
                    Text {
                        text: day.modelData.rain + "%"
                        color: Theme.cyan
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSize - 2
                    }
                }
            }
        }
    }
}
