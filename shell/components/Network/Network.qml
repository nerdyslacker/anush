import QtQuick
import "../.."
import Quickshell

// Active transport/VPN indicator. Bluetooth has its own neighbouring module.
BarModule {
    id: root

    icon: Sys.netIcon
    iconColor: Sys.vpnOn ? Theme.green : Sys.online ? Theme.cyan : Theme.red

    onClicked: mouse => {
        if (mouse.button === Qt.RightButton)
            NetworkService.openSettings()
        else
            popup.visible = !popup.visible
    }

    NetworkPopup {
        id: popup
        anchorItem: root
    }
}
