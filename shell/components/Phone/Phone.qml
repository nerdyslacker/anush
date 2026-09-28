import QtQuick
import QtQuick.Dialogs
import "../.."

// Unified KDE Connect / Valent status. Right click opens the backend's full
// application; middle click refreshes discovery immediately.
BarModule {
    id: root

    readonly property var device: PhoneService.primaryDevice
    property string shareTargetId: ""
    property bool restorePopup: false
    visible: PhoneService.installed || PhoneService.checking
    icon: device?.type === "tablet" ? "󰓶"
        : device?.type === "laptop" ? "󰌢" : ""
    iconColor: device?.paired && device?.reachable ? Theme.success
        : device?.pairRequestedByPeer ? Theme.warning
        : PhoneService.available ? Theme.cyan : Theme.disabled
    label: device?.paired && device?.reachable && Number(device?.battery) >= 0
        ? Math.round(Number(device.battery)) + "%" : ""
    progress: device?.paired && device?.reachable && Number(device?.battery) >= 0
        ? Number(device.battery) / 100 : -1

    Component.onCompleted: PhoneService.initialize()

    onClicked: mouse => {
        if (mouse.button === Qt.RightButton)
            PhoneService.openManager()
        else if (mouse.button === Qt.MiddleButton) {
            if (PhoneService.backend === "kdeconnect") PhoneService.discover()
            else PhoneService.refresh()
        }
        else
            popup.visible = !popup.visible
    }

    PhonePopup {
        id: popup
        anchorItem: root
        onShareFileRequested: deviceId => {
            root.shareTargetId = deviceId
            root.restorePopup = popup.visible
            popup.visible = false
            fileDialog.open()
        }
    }

    FileDialog {
        id: fileDialog
        title: "Share files with phone"
        modality: Qt.ApplicationModal
        fileMode: FileDialog.OpenFiles
        nameFilters: ["All files (*)"]
        onAccepted: PhoneService.shareFiles(root.shareTargetId,
            Array.from(selectedFiles, file => file.toString()))
        onVisibleChanged: if (!visible && root.restorePopup) {
            root.restorePopup = false
            popup.showAtAnchor()
        }
    }
}
