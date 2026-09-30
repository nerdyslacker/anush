import QtQuick
import "../.."

// Current XKB group. Pick a configured layout with left click and edit the
// setxkbmap layout/variant/group shortcut configuration with right click.
BarModule {
    id: root

    icon: "󰌌"
    iconColor: KeyboardState.switcherAvailable ? Theme.cyan : Theme.brightBlack
    label: KeyboardState.currentLayout.toUpperCase()
    tooltip: KeyboardState.layoutName(KeyboardState.currentLayout)
        + (KeyboardState.specVariant(KeyboardState.currentSpec) !== ""
            ? " (" + KeyboardState.specVariant(KeyboardState.currentSpec) + ")"
            : "")

    onClicked: mouse => {
        if (mouse.button === Qt.RightButton) {
            picker.visible = false
            settings.openSettings()
        } else if (mouse.button === Qt.MiddleButton) {
            picker.visible = false
            settings.visible = false
            KeyboardState.advanceGroup()
        } else {
            settings.visible = false
            picker.visible = !picker.visible
        }
    }

    KeyboardLayoutPicker {
        id: picker
        anchorItem: root
    }

    KeyboardLayoutSettings {
        id: settings
        anchorItem: root
    }
}
