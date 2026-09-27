import QtQuick
import "../.."

// Active transport/VPN indicator. Bluetooth has its own neighbouring module.
BarModule {
    id: root

    icon: HotspotService.active ? "󰀂" : Sys.netIcon
    iconColor: HotspotService.active ? Theme.blue
        : Sys.vpnOn ? Theme.green : Sys.online ? Theme.cyan : Theme.red

    onClicked: mouse => {
        if (mouse.button === Qt.RightButton) {
            popup.visible = false
            hotspotPopup.visible = !hotspotPopup.visible
        } else if (mouse.button === Qt.MiddleButton) {
            NetworkService.openSettings()
        } else {
            hotspotPopup.visible = false
            popup.visible = !popup.visible
        }
    }

    NetworkPopup {
        id: popup
        anchorItem: root
    }

    HotspotPopup {
        id: hotspotPopup
        anchorItem: root
    }
}
