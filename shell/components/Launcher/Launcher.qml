import QtQuick
import QtQuick.Dialogs
import "../.."

// Left click opens the application launcher; right click edits its icon.
BarModule {
    id: root
    property bool restoreIconEditor: false

    icon: LauncherState.defaultGlyph
    iconSource: LauncherState.resolveIcon(LauncherState.icon)
    iconColor: Theme.accent
    onClicked: mouse => {
        if (mouse.button === Qt.LeftButton) {
            iconPicker.visible = false
            applications.toggle()
        } else if (mouse.button === Qt.RightButton) {
            applications.visible = false
            iconPicker.toggle()
        }
    }

    ApplicationLauncher {
        id: applications
        anchorItem: root
    }

    LauncherIconPicker {
        id: iconPicker
        anchorItem: root
        browsing: iconFileDialog.visible
        onBrowseRequested: {
            root.restoreIconEditor = iconPicker.visible
            iconPicker.visible = false
            iconFileDialog.open()
        }
    }

    FileDialog {
        id: iconFileDialog
        title: "Choose launcher icon"
        modality: Qt.ApplicationModal
        nameFilters: [
            "Images (*.svg *.svgz *.png *.webp *.jpg *.jpeg)",
            "All files (*)"
        ]
        onAccepted: iconPicker.acceptFile(selectedFile)
        onVisibleChanged: if (!visible && root.restoreIconEditor) {
            root.restoreIconEditor = false
            iconPicker.showAtAnchor()
            iconPicker.restoreEditorFocus()
        }
    }
}
