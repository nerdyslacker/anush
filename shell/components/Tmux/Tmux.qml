import QtQuick
import "../.."

// tmux session count and manager. Middle click refreshes the count.
BarModule {
    id: root

    visible: TmuxService.available
    icon: ""
    iconColor: Theme.cyan
    label: TmuxService.sessions.length > 0
        ? String(TmuxService.sessions.length) : ""

    Component.onCompleted: TmuxService.initialize()

    onClicked: mouse => {
        if (mouse.button === Qt.MiddleButton) {
            TmuxService.refresh()
        } else if (mouse.button === Qt.LeftButton) {
            popup.visible = !popup.visible
        }
    }

    TmuxPopup {
        id: popup
        anchorItem: root
    }
}
