pragma ComponentBehavior: Bound

import QtQuick
import "../.."
import Quickshell.Io

// Launcher-specific appearance editor. Bare values use the desktop icon
// theme; paths containing a slash are resolved relative to Theme.configDir.
Popout {
    id: root

    readonly property var presets: [
        { spec: "glyph:󰀻", glyph: "󰀻", label: "Start" },
        { spec: "glyph:󰕰", glyph: "󰕰", label: "Grid" },
        { spec: "glyph:󰀻", glyph: "󰀻", label: "Apps" },
        { spec: "glyph:󰍉", glyph: "󰍉", label: "Search" },
        { spec: "glyph:󰌽", glyph: "󰌽", label: "Distro" },
        { spec: "glyph:󰏖", glyph: "󰏖", label: "Generic" }
    ]
    readonly property string resolvedDraft: LauncherState.resolveIcon(iconInput.text)
    readonly property bool glyphDraft: iconInput.text.trim().startsWith("glyph:")
    readonly property string draftGlyph: glyphDraft
        ? iconInput.text.trim().slice(6) : LauncherState.defaultGlyph
    readonly property bool customRequested: iconInput.text.trim() !== ""
    readonly property bool previewReady: previewImage.status === Image.Ready
    property var distroLogos: []
    readonly property var filteredDistroLogos: {
        const query = distroSearch.text.trim().toLowerCase()
        if (query === "")
            return distroLogos
        return distroLogos.filter(item => item.name.toLowerCase().indexOf(query) >= 0)
    }
    property bool browsing: false
    signal browseRequested()

    FileView {
        path: Theme.shellDir + "/../assets/distro-logos.json"
        onLoaded: {
            try {
                const values = JSON.parse(text())
                root.distroLogos = Object.keys(values).sort().map(name => ({
                    name: name,
                    glyph: String(values[name])
                }))
            } catch (error) {
                console.warn("distro logos:", error)
                root.distroLogos = []
            }
        }
        onLoadFailed: console.warn("Could not load distro logo catalog")
    }

    cardWidth: 390
    cardHeight: content.implicitHeight + 2 * cardPadding
    closeOnOutside: false
    grabFocus: !browsing

    function toggle() {
        if (visible) {
            visible = false
        } else {
            iconInput.text = LauncherState.icon
            showAtAnchor()
            Qt.callLater(() => iconInput.forceActiveFocus())
        }
    }

    function portableFileSpec(url) {
        const source = String(url ?? "")
        let path = source.startsWith("file://")
            ? decodeURIComponent(source.slice(7)) : source
        const configRoot = String(Theme.configDir).replace(/\/$/, "")
        if (path.startsWith(configRoot + "/"))
            return path.slice(configRoot.length + 1)
        return source
    }

    function acceptFile(url) {
        iconInput.text = portableFileSpec(url)
    }

    function restoreEditorFocus() {
        if (visible)
            Qt.callLater(() => iconInput.forceActiveFocus())
    }

    component ActionButton: Rectangle {
        id: button
        required property string label
        property bool primary: false
        signal activated()

        height: 34
        radius: Theme.radiusSmall
        color: primary ? Theme.accent
            : buttonMouse.containsMouse ? Theme.gray3 : Theme.gray2
        border.width: 1
        border.color: primary ? Theme.brightOrange : Theme.gray5

        Text {
            anchors.centerIn: parent
            text: button.label
            color: button.primary ? Theme.selfg : Theme.fg
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSize
            font.bold: button.primary
        }
        MouseArea {
            id: buttonMouse
            anchors.fill: parent
            hoverEnabled: true
            onClicked: button.activated()
        }
    }

    Column {
        id: content
        anchors.left: parent.left
        anchors.right: parent.right
        spacing: 10

        Text {
            text: "Launcher icon"
            color: Theme.fg
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSize + 2
            font.bold: true
        }

        Row {
            width: parent.width
            height: 62
            spacing: 12

            Rectangle {
                width: 62
                height: 62
                radius: Theme.radiusMedium
                color: Theme.gray2
                border.width: 1
                border.color: root.customRequested && !root.glyphDraft
                        && !root.previewReady
                    ? Theme.red : Theme.gray5

                Image {
                    id: previewImage
                    anchors.centerIn: parent
                    width: 36
                    height: 36
                    source: root.resolvedDraft
                    visible: root.customRequested && !root.glyphDraft
                        && status === Image.Ready
                    fillMode: Image.PreserveAspectFit
                    asynchronous: true
                }

                Text {
                    anchors.centerIn: parent
                    visible: !root.customRequested
                        || root.glyphDraft || previewImage.status !== Image.Ready
                    text: root.draftGlyph
                    color: Theme.accent
                    font.family: Theme.iconFontFamily
                    font.pixelSize: 30
                }
            }

            Column {
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width - 74
                spacing: 4
                Text {
                    width: parent.width
                    text: root.customRequested
                        ? (root.glyphDraft ? "Distro logo preview"
                            : root.previewReady ? "Custom icon preview"
                            : "Icon unavailable — default will be used")
                        : "Built-in anush icon"
                    color: root.customRequested && !root.glyphDraft
                            && !root.previewReady
                        ? Theme.brightRed : Theme.fg
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSize
                    wrapMode: Text.Wrap
                }
                Text {
                    width: parent.width
                    text: "Use an icon-theme name or choose an SVG/PNG image."
                    color: Theme.brightBlack
                    font.family: Theme.fontFamily
                    font.pixelSize: Math.max(9, Theme.fontSize - 2)
                    wrapMode: Text.Wrap
                }
            }
        }

        Text {
            text: "Built-in"
            color: Theme.brightBlack
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSize - 1
        }

        Grid {
            id: presetGrid
            width: parent.width
            columns: 3
            spacing: 6

            Repeater {
                model: root.presets

                Rectangle {
                    id: preset
                    required property var modelData
                    width: (presetGrid.width - presetGrid.spacing * 2) / 3
                    height: 45
                    radius: Theme.radiusSmall
                    color: iconInput.text === modelData.spec
                        ? Theme.activeBackground
                        : presetMouse.containsMouse ? Theme.gray3 : Theme.gray2
                    border.width: 1
                    border.color: iconInput.text === modelData.spec
                        ? Theme.activeBorder : Theme.gray5

                    Row {
                        anchors.centerIn: parent
                        spacing: 7
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: preset.modelData.glyph
                            color: iconInput.text === preset.modelData.spec
                                ? Theme.selfg : Theme.accent
                            font.family: Theme.iconFontFamily
                            font.pixelSize: Theme.iconSize
                        }
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: preset.modelData.label
                            color: iconInput.text === preset.modelData.spec
                                ? Theme.selfg : Theme.fg
                            font.family: Theme.fontFamily
                            font.pixelSize: Math.max(9, Theme.fontSize - 1)
                        }
                    }

                    MouseArea {
                        id: presetMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        onClicked: iconInput.text = preset.modelData.spec
                    }
                }
            }
        }

        Text {
            text: "Distro logo"
            color: Theme.brightBlack
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSize - 1
        }

        Rectangle {
            width: parent.width
            height: 32
            radius: Theme.radiusSmall
            color: Theme.gray2
            border.width: 1
            border.color: distroSearch.activeFocus ? Theme.accent : Theme.gray5

            TextInput {
                id: distroSearch
                anchors.fill: parent
                anchors.leftMargin: 9
                anchors.rightMargin: 9
                verticalAlignment: TextInput.AlignVCenter
                color: Theme.fg
                selectionColor: Theme.selbg
                selectedTextColor: Theme.selfg
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSize
                clip: true

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: distroSearch.text === ""
                    text: "Search distributions…"
                    color: Theme.brightBlack
                    font: distroSearch.font
                }
            }
        }

        GridView {
            id: distroGrid
            width: parent.width
            height: 142
            clip: true
            cellWidth: width / 3
            cellHeight: 45
            model: root.filteredDistroLogos
            boundsBehavior: Flickable.StopAtBounds

            delegate: Rectangle {
                id: distroTile
                required property var modelData
                readonly property string iconSpec: "glyph:" + modelData.glyph
                width: distroGrid.cellWidth - 5
                height: distroGrid.cellHeight - 5
                radius: Theme.radiusSmall
                color: iconInput.text === iconSpec
                    ? Theme.activeBackground
                    : distroMouse.containsMouse ? Theme.gray3 : Theme.gray2
                border.width: 1
                border.color: iconInput.text === iconSpec
                    ? Theme.activeBorder : Theme.gray5

                Row {
                    anchors.fill: parent
                    anchors.leftMargin: 7
                    anchors.rightMargin: 7
                    spacing: 6

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: distroTile.modelData.glyph
                        color: iconInput.text === distroTile.iconSpec
                            ? Theme.selfg : Theme.accent
                        font.family: Theme.iconFontFamily
                        font.pixelSize: Theme.iconSize
                    }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width - Theme.iconSize - parent.spacing
                        text: distroTile.modelData.name
                        elide: Text.ElideRight
                        color: iconInput.text === distroTile.iconSpec
                            ? Theme.selfg : Theme.fg
                        font.family: Theme.fontFamily
                        font.pixelSize: Math.max(8, Theme.fontSize - 2)
                    }
                }

                MouseArea {
                    id: distroMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    onClicked: iconInput.text = distroTile.iconSpec
                }
            }

            Text {
                anchors.centerIn: parent
                visible: distroGrid.count === 0
                text: root.distroLogos.length === 0
                    ? "No distro logo catalog found" : "No matching distributions"
                color: Theme.foregroundMuted
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSize - 1
            }
        }

        Text {
            text: "Custom name or path"
            color: Theme.brightBlack
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSize - 1
        }

        Row {
            width: parent.width
            height: 36
            spacing: 7

            Rectangle {
                width: parent.width - browseButton.width - parent.spacing
                height: parent.height
                radius: Theme.radiusSmall
                color: Theme.gray2
                border.width: 1
                border.color: iconInput.activeFocus ? Theme.accent : Theme.gray5

                TextInput {
                    id: iconInput
                    anchors.fill: parent
                    anchors.leftMargin: 9
                    anchors.rightMargin: 9
                    verticalAlignment: TextInput.AlignVCenter
                    color: Theme.fg
                    selectionColor: Theme.selbg
                    selectedTextColor: Theme.selfg
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSize
                    clip: true

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        visible: iconInput.text === ""
                        text: "e.g. start-here or icons/anush.svg"
                        color: Theme.brightBlack
                        font: iconInput.font
                    }
                }
            }

            ActionButton {
                id: browseButton
                width: 76
                label: "Browse…"
                onActivated: root.browseRequested()
            }
        }

        Row {
            width: parent.width
            height: 34
            spacing: 7

            ActionButton {
                width: (parent.width - parent.spacing * 2) / 3
                label: "Reset"
                onActivated: iconInput.text = ""
            }
            ActionButton {
                width: (parent.width - parent.spacing * 2) / 3
                label: "Cancel"
                onActivated: root.visible = false
            }
            ActionButton {
                width: (parent.width - parent.spacing * 2) / 3
                label: "Apply"
                primary: true
                onActivated: {
                    LauncherState.setIcon(iconInput.text)
                    root.visible = false
                }
            }
        }
    }

}
