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
    readonly property real galleryHeight: 103 * 4
    readonly property real themeOptionHeight: 30
    cardHeight: titleHeight + 7 + directoryOptionHeight + 9 + galleryHeight
        + 8 + themeOptionHeight + 2 * cardPadding

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
        cellWidth: 176
        cellHeight: 103
        cacheBuffer: 4000
        model: root.wallpapers
        boundsBehavior: Flickable.StopAtBounds
        ScrollBar.vertical: ScrollBar {
            policy: grid.contentHeight > grid.height
                ? ScrollBar.AlwaysOn : ScrollBar.AlwaysOff
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

    Row {
        id: themeOption
        anchors.left: parent.left
        anchors.top: grid.bottom
        anchors.topMargin: 8
        height: root.themeOptionHeight
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
}
