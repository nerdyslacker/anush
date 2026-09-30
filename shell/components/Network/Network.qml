import QtQuick
import "../.."

// Active transport/VPN indicator. Bluetooth has its own neighbouring module.
BarModule {
    id: root

    readonly property string networkIcon: NetworkService.vpnOn ? "󰦝"
        : NetworkService.primaryType.indexOf("wireless") !== -1 ? "󰤨"
        : NetworkService.primaryType.indexOf("ethernet") !== -1 ? "󰈀" : "󰤭"

    icon: HotspotService.active ? "󰀂" : networkIcon
    iconColor: HotspotService.active ? Theme.blue
        : NetworkService.vpnOn ? Theme.green
        : NetworkService.online ? Theme.cyan : Theme.red

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
