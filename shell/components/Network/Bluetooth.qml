import QtQuick
import "../.."
import Quickshell

// Dedicated Bluetooth status item. Left click opens quick controls; right
// click opens the full pairing/settings application.
BarModule {
    id: root

    visible: BluetoothService.available
    icon: BluetoothService.connected ? "󰂱"
        : BluetoothService.enabled ? "󰂯" : "󰂲"
    iconColor: BluetoothService.connected ? Theme.green
        : BluetoothService.enabled ? Theme.cyan : Theme.disabled

    onClicked: mouse => {
        if (mouse.button === Qt.RightButton)
            BluetoothService.openSettings()
        else
            popup.visible = !popup.visible
    }

    BluetoothPopup {
        id: popup
        anchorItem: root
    }
}
