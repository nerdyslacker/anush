import QtQuick
import "../.."

// Left click opens the application launcher; right click edits its icon.
BarModule {
    id: root

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
    }
}
