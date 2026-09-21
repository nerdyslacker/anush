pragma ComponentBehavior: Bound

import QtQuick
import "../.."
import QtQuick.Controls
import Quickshell
import Quickshell.Io

// Thumbnail picker for a configurable local directory. Wallpaper-driven
// palette generation is optional; disabled mode leaves the theme unchanged.
Popout {
    id: root

    cardWidth: 176 * 3 + 2 * cardPadding
    readonly property real titleHeight: 20
    readonly property real directoryOptionHeight: 38
    readonly property real themeOptionHeight: 88
    readonly property real fixedContentHeight: titleHeight + 7
        + directoryOptionHeight + 9 + 8 + themeOptionHeight + 2 * cardPadding
    readonly property real popupScreenHeight: screenHeightForAnchor()
    // Preserve the controls at the bottom on short laptop panels. The gallery
    // gives up rows first and remains navigable through its scrollbar.
    readonly property real galleryHeight: Math.max(103, Math.min(103 * 4,
        popupScreenHeight - fixedContentHeight - 2 * screenMargin))
    cardHeight: fixedContentHeight + galleryHeight

    property var wallpapers: []
    property var _found: []
    property bool randomPending: false
    property string selectedPath: ""
    property bool browsing: false
    readonly property string defaultDirectory: Theme.configDir + "/wallpaper"
    readonly property string wallpaperDirectory: {
        const saved = String(ShellState.state.wallpaper?.directory ?? "").trim()
        return saved !== "" ? saved : defaultDirectory
    }
    readonly property bool customDirectory:
        wallpaperDirectory !== defaultDirectory
    signal directoryBrowseRequested()

    closeOnOutside: !browsing

    function screenHeightForAnchor() {
        if (Quickshell.screens.length === 0)
            return 720
        if (!anchorItem)
            return Quickshell.screens[0].height
        const center = anchorItem.mapToGlobal(
            anchorItem.width / 2, anchorItem.height / 2)
        for (const screen of Quickshell.screens) {
            if (center.x >= screen.x && center.x < screen.x + screen.width
                    && center.y >= screen.y
                    && center.y < screen.y + screen.height)
                return screen.height
        }
        return Quickshell.screens[0].height
    }

    function directoryUrl() {
        return "file://" + wallpaperDirectory
    }

    function pathFromUrl(url) {
        const value = String(url ?? "")
        return value.startsWith("file://")
            ? decodeURIComponent(value.slice(7)) : value
    }

    function acceptDirectory(url) {
        let path = pathFromUrl(url)
        if (path.length > 1)
            path = path.replace(/\/$/, "")
        if (path === "") return
        ShellState.updateSection("wallpaper", { directory: path })
        selectedPath = ""
        Qt.callLater(() => scan())
    }

    function resetDirectory() {
        ShellState.updateSection("wallpaper", { directory: "" })
        selectedPath = ""
        Qt.callLater(() => scan())
    }

    function scan() {
        lister.running = false
        lister.running = true
    }

    function toggle() {
        visible = !visible
        if (visible)
            scan()
    }

    function applyRandom() {
        randomPending = true
        scan()
    }

    function apply(path) {
        if (path === "")
            return
        Quickshell.execDetached([
            Theme.scriptsDir + "/wallpaper-theme",
            path,
            Theme.wallpaperThemeEnabled ? "true" : "false",
            Theme.mode,
            Wm.msgPath
        ])
        visible = false
    }

    Connections {
        target: ShellActions
        function onWallpaperRequested(action, path) {
            if (!ShellActions.ownsFocusedOutput(root.anchorItem)) return
            if (action === "toggle") root.toggle()
            else if (action === "random") root.applyRandom()
            else if (action === "set") root.apply(path)
        }
    }

    Connections {
        target: Theme
        function onWallpaperPresetStatusChanged() {
            if (Theme.wallpaperPresetStatus.startsWith("Saved"))
                presetName.text = ""
        }
    }

    Process {
        id: lister
        command: ["find", root.wallpaperDirectory, "-maxdepth", "1",
            "-type", "f", "-print"]
        stdout: SplitParser {
            onRead: line => {
                const path = line.trim()
                if (/\.(png|jpe?g|webp)$/i.test(path))
                    root._found.push(path)
            }
        }
        onRunningChanged: {
            if (running) {
                root._found = []
            } else {
                root.wallpapers = root._found.sort((a, b) =>
                    a.localeCompare(b))
                if (root.wallpapers.indexOf(root.selectedPath) < 0)
                    root.selectedPath = ""
                if (root.randomPending) {
                    root.randomPending = false
                    if (root.wallpapers.length > 0)
                        root.apply(root.wallpapers[
                            Math.floor(Math.random() * root.wallpapers.length)])
                }
            }
        }
    }

    component SettingSwitch: Rectangle {
        id: control
        property bool checked: false
        signal toggled()

        width: 34
        height: 18
        radius: Math.min(height / 2, Theme.radiusSmall)
        color: checked ? Theme.accent : Qt.alpha(Theme.fg, 0.15)
        Behavior on color { ColorAnimation { duration: 150 } }

        Rectangle {
            x: control.checked ? parent.width - width - 2 : 2
            anchors.verticalCenter: parent.verticalCenter
            width: 14
            height: 14
            radius: Math.min(width / 2, Theme.radiusSmall)
            color: control.checked ? Theme.bg : Qt.alpha(Theme.fg, 0.7)
            Behavior on x {
                NumberAnimation { duration: 150; easing.type: Easing.OutCubic }
            }
        }

        MouseArea {
            anchors.fill: parent
            onClicked: control.toggled()
        }
    }

    component DirectoryButton: Rectangle {
        id: button
        required property string buttonText
        signal activated()

        implicitWidth: label.implicitWidth + 18
        height: 28
        radius: Theme.radiusSmall
        color: buttonMouse.containsMouse ? Theme.gray3 : Theme.gray2
        border.width: 1
        border.color: Theme.gray5
        opacity: enabled ? 1 : 0.45

        Text {
            id: label
            anchors.centerIn: parent
            text: button.buttonText
            color: Theme.fg
            font.family: Theme.fontFamily
            font.pixelSize: Math.max(9, Theme.fontSize - 1)
        }

        MouseArea {
            id: buttonMouse
            anchors.fill: parent
            hoverEnabled: true
            enabled: button.enabled
            onClicked: button.activated()
        }
    }

    Text {
        id: heading
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        height: root.titleHeight
        text: "Wallpapers"
        color: Theme.fg
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontSize + 1
        font.bold: true
        verticalAlignment: Text.AlignVCenter
    }

    Row {
        id: directoryOption
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: heading.bottom
        anchors.topMargin: 7
        height: root.directoryOptionHeight
        spacing: 7

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: "󰉋"
            color: Theme.accent
            font.family: Theme.iconFontFamily
            font.pixelSize: Theme.iconSize
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width - x - changeDirectory.width - parent.spacing
                - (resetDirectory.visible
                    ? resetDirectory.width + parent.spacing : 0)
            text: root.wallpaperDirectory
            elide: Text.ElideMiddle
            color: Theme.foregroundMuted
            font.family: Theme.fontFamily
            font.pixelSize: Math.max(9, Theme.fontSize - 2)
        }

        DirectoryButton {
            id: changeDirectory
            anchors.verticalCenter: parent.verticalCenter
            buttonText: "Change…"
            onActivated: root.directoryBrowseRequested()
        }

        DirectoryButton {
            id: resetDirectory
            anchors.verticalCenter: parent.verticalCenter
            visible: root.customDirectory
            buttonText: "Reset"
            onActivated: root.resetDirectory()
        }
    }

    Rectangle {
        id: titleSeparator
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: directoryOption.bottom
        height: 1
        color: Theme.gray5
    }

    GridView {
        id: grid
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: titleSeparator.bottom
        anchors.topMargin: 8
        height: root.galleryHeight
        visible: root.wallpapers.length > 0
        clip: true
        cellWidth: (width - 8) / 3
        cellHeight: 103
        cacheBuffer: 4000
        model: root.wallpapers
        boundsBehavior: Flickable.StopAtBounds
        ScrollBar.vertical: ScrollBar {
            id: wallpaperScrollbar
            width: 8
            policy: ScrollBar.AsNeeded
            interactive: true

            background: Rectangle {
                color: Theme.gray2
                border.width: 1
                border.color: Theme.gray5
                radius: Math.min(width / 2, Theme.radiusSmall)
            }

            contentItem: Rectangle {
                implicitWidth: 6
                implicitHeight: 28
                color: wallpaperScrollbar.pressed ? Theme.brightOrange
                    : wallpaperScrollbar.hovered ? Theme.orange : Theme.gray6
                radius: Math.min(width / 2, Theme.radiusSmall)

                Behavior on color { ColorAnimation { duration: 100 } }
            }
        }

        delegate: Item {
            id: cell
            required property string modelData
            width: grid.cellWidth
            height: grid.cellHeight

            Rectangle {
                anchors.fill: parent
                anchors.margins: 4
                radius: Theme.radiusMedium
                color: Theme.gray1
                border.width: cell.modelData === root.selectedPath
                    ? 3 : mouse.containsMouse ? 2 : 1
                border.color: cell.modelData === root.selectedPath
                    ? Theme.orange : mouse.containsMouse
                    ? Theme.brightOrange : Theme.gray4

                Image {
                    anchors.fill: parent
                    anchors.margins: 2
                    source: "file://" + cell.modelData
                    sourceSize.width: 340
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    clip: true
                }

                MouseArea {
                    id: mouse
                    anchors.fill: parent
                    hoverEnabled: true
                    onClicked: {
                        root.selectedPath = cell.modelData
                        root.apply(cell.modelData)
                    }
                }
            }
        }
    }

    Text {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.verticalCenter: grid.verticalCenter
        visible: root.wallpapers.length === 0
        text: "No wallpapers found in the selected directory"
        color: Theme.brightBlack
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontSize
    }

    Column {
        id: themeOption
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: grid.bottom
        anchors.topMargin: 8
        height: root.themeOptionHeight
        spacing: 6

        Row {
            width: parent.width
            height: 24
            spacing: 9

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: "Generate theme based on wallpaper"
                color: Theme.wallpaperThemeEnabled
                    ? Theme.accent : Theme.brightBlack
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSize - 1
                font.bold: Theme.wallpaperThemeEnabled
            }

            SettingSwitch {
                anchors.verticalCenter: parent.verticalCenter
                checked: Theme.wallpaperThemeEnabled
                onToggled: Theme.persistWallpaperThemeEnabled(
                    !Theme.wallpaperThemeEnabled, root.selectedPath)
            }
        }

        Row {
            width: parent.width
            height: 32
            spacing: 7

            Rectangle {
                width: parent.width - savePresetButton.width - parent.spacing
                height: parent.height
                radius: Theme.radiusSmall
                color: Theme.gray2
                border.width: 1
                border.color: Theme.themePresetNameExists(presetName.text)
                    ? Theme.error : presetName.activeFocus
                    ? Theme.accent : Theme.gray5

                TextInput {
                    id: presetName
                    anchors.fill: parent
                    anchors.leftMargin: 9
                    anchors.rightMargin: 9
                    verticalAlignment: TextInput.AlignVCenter
                    color: Theme.fg
                    selectionColor: Theme.selbg
                    selectedTextColor: Theme.selfg
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSize - 1
                    maximumLength: 64
                    clip: true
                    onAccepted: if (savePresetButton.enabled)
                        Theme.saveWallpaperPreset(text)

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        visible: presetName.text.length === 0
                        text: Theme.wallpaperPresetStatus !== ""
                            ? Theme.wallpaperPresetStatus
                            : "Preset name"
                        color: Theme.foregroundMuted
                        font: presetName.font
                        elide: Text.ElideRight
                        width: parent.width
                    }
                }
            }

            DirectoryButton {
                id: savePresetButton
                height: parent.height
                buttonText: Theme.wallpaperPresetSaving ? "Saving…" : "Save preset"
                enabled: !Theme.wallpaperPresetSaving
                    && Theme.wallpaperThemeEnabled
                    && !!ShellState.state.theme.palette?.semantic
                    && presetName.text.trim() !== ""
                    && !Theme.themePresetNameExists(presetName.text)
                onActivated: Theme.saveWallpaperPreset(presetName.text)
            }
        }

        Text {
            width: parent.width
            height: 14
            visible: Theme.themePresetNameExists(presetName.text)
                || Theme.wallpaperPresetStatus !== ""
            text: Theme.themePresetNameExists(presetName.text)
                ? "A theme preset with this name already exists."
                : Theme.wallpaperPresetStatus
            color: Theme.themePresetNameExists(presetName.text)
                ? Theme.error : Theme.foregroundMuted
            font.family: Theme.fontFamily
            font.pixelSize: Math.max(8, Theme.fontSize - 2)
            elide: Text.ElideRight
        }
    }
}
