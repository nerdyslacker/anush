import QtQuick
import QtQuick.Dialogs
import "../.."

// Workspace layout. Left click opens desktop appearance controls,
// right click opens wallpapers, middle click applies a random wallpaper, and
// scrolling cycles Scrolling Tile, Dwindle, Monocle, and Floating modes.
BarModule {
    id: root
    property bool restoreWallpaperPicker: false
    readonly property var currentLayout: Wm.layoutIndex >= 0
        && Wm.layoutIndex < Wm.layouts.length ? Wm.layouts[Wm.layoutIndex] : null

    icon: currentLayout ? "" : "󰕮"
    compactIcon: icon
    iconColor: Theme.accent
    implicitWidth: Theme.moduleHeight
    tooltip: Wm.capabilities.layouts === true
        ? "Layouts and appearance" : "Desktop appearance"

    LayoutDiagram {
        parent: root
        anchors.centerIn: parent
        visible: root.currentLayout !== null
        width: Math.round(21 * Theme.barScale)
        height: Math.round(15 * Theme.barScale)
        layoutData: root.currentLayout
        masterColor: Theme.accent
        paneColor: Qt.alpha(Theme.fg, 0.48)
    }

    onClicked: mouse => {
        if (mouse.button === Qt.RightButton) {
            picker.visible = false
            wallpapers.toggle()
        } else if (mouse.button === Qt.MiddleButton) {
            picker.visible = false
            wallpapers.applyRandom()
        } else if (mouse.button === Qt.LeftButton) {
            wallpapers.visible = false
            picker.visible = !picker.visible
        }
    }
    onScrolled: direction => {
        if (Wm.capabilities.layouts === true)
            Wm.cycleLayout(direction)
    }

    LayoutPicker {
        id: picker
        anchorItem: root
    }

    WallpaperPicker {
        id: wallpapers
        anchorItem: root
        browsing: wallpaperFolderDialog.visible
        onDirectoryBrowseRequested: {
            root.restoreWallpaperPicker = wallpapers.visible
            wallpapers.visible = false
            wallpaperFolderDialog.currentFolder = wallpapers.directoryUrl()
            wallpaperFolderDialog.open()
        }
    }

    FolderDialog {
        id: wallpaperFolderDialog
        title: "Choose wallpaper directory"
        modality: Qt.ApplicationModal
        onAccepted: wallpapers.acceptDirectory(selectedFolder)
        onVisibleChanged: if (!visible && root.restoreWallpaperPicker) {
            root.restoreWallpaperPicker = false
            wallpapers.showAtAnchor()
        }
    }
}
