import QtQuick
import "../.."

BarModule {
    id: root

    visible: TailscaleService.installed
    label: ""
    labelColor: TailscaleService.running ? Theme.fg : Theme.foregroundMuted
    icon: ""
    compactIcon: "󰖂"
    compactIconColor: TailscaleService.running ? Theme.accent
        : TailscaleService.needsLogin ? Theme.warning : Theme.disabled

    Component.onCompleted: TailscaleService.initialize()

    TailscaleLogo {
        anchors.verticalCenter: parent.verticalCenter
        width: Theme.iconSize
        height: Theme.iconSize
        dotColor: TailscaleService.running ? Theme.accent
            : TailscaleService.needsLogin ? Theme.warning : Theme.disabled
        disconnected: !TailscaleService.running && !TailscaleService.needsLogin
        warning: TailscaleService.needsLogin
            || TailscaleService.visibleHealth.length > 0
            || TailscaleService.pendingFiles.length > 0
    }

    onClicked: mouse => {
        if (mouse.button === Qt.RightButton) TailscaleService.toggle()
        else if (mouse.button === Qt.MiddleButton) TailscaleService.refresh()
        else popup.visible = !popup.visible
    }

    TailscalePopup {
        id: popup
        anchorItem: root
    }
}
