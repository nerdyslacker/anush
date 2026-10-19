import QtQuick
import "../.."
import Quickshell
import Quickshell.Io

// Battery status is kept separate from CPU/RAM/disk. Left click opens the
// power controls, middle click toggles keep-awake, and right click opens tlpui.
BarModule {
    id: root

    property bool tlpuiAvailable: false

    visible: BarVisibility.enabled("battery") && Sys.hasBattery
    leadingIcon: Sys.keepAwake ? "󰅶" : ""
    leadingIconColor: Theme.blue
    icon: Sys.batteryCharging ? "󰂄"
        : Sys.battery < 15 ? "󰁺"
        : Sys.battery < 40 ? "󰁼"
        : Sys.battery < 80 ? "󰁾"
        : "󰁹"
    iconColor: Sys.batteryCharging ? Theme.green
        : Sys.battery < 15 ? Theme.red
        : Sys.battery < 40 ? Theme.yellow
        : Theme.green
    label: ShellState.state.desktop.showBatteryPercentage === false
        ? "" : Math.round(Sys.battery) + "%"
    labelColor: !Sys.batteryCharging && Sys.battery < 15
        ? Theme.red : Theme.fg

    onClicked: mouse => {
        if (mouse.button === Qt.LeftButton)
            popup.visible = !popup.visible
        else if (mouse.button === Qt.MiddleButton)
            Sys.setKeepAwake(!Sys.keepAwake)
        else if (mouse.button === Qt.RightButton && tlpuiAvailable)
            Quickshell.execDetached(["tlpui"])
    }

    Process {
        command: ["sh", "-c", "command -v tlpui 2>/dev/null"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: root.tlpuiAvailable = text.trim() !== ""
        }
    }

    BatteryPopup {
        id: popup
        anchorItem: root
    }
}
