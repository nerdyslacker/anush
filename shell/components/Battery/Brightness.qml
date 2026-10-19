import QtQuick
import "../.."

// Display brightness is independent from the general command menu. Each
// connected XRandR output gets its own control in the popup; middle click
// toggles the same night-light control exposed there.
BarModule {
    id: root

    icon: "󰃠"
    iconColor: Theme.yellow
    onClicked: mouse => {
        if (mouse.button === Qt.LeftButton)
            popup.visible = !popup.visible
        else if (mouse.button === Qt.MiddleButton)
            popup.setNightLight(!ShellState.state.desktop.nightLight)
    }

    BrightnessPopup {
        id: popup
        anchorItem: root
    }
}
