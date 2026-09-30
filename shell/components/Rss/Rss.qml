import QtQuick
import "../.."

BarModule {
    id: root

    visible: BarVisibility.enabled("rss")
    icon: ""
    iconColor: RssService.error !== "" ? Theme.red
        : RssService.unreadCount > 0 ? Theme.orange : Theme.brightBlack
    label: RssService.unreadCount > 0 ? String(RssService.unreadCount) : ""
    tooltip: RssService.tooltip

    Component.onCompleted: RssService.initialize()

    onClicked: mouse => {
        if (mouse.button === Qt.MiddleButton) {
            RssService.refresh()
        } else if (mouse.button === Qt.RightButton) {
            popup.openSettings()
        } else {
            popup.visible = !popup.visible
        }
    }

    RssPopup {
        id: popup
        anchorItem: root
    }
}
