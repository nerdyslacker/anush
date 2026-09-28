pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls as Controls
import "../.."

Popout {
    id: root
    cardWidth: 430
    cardHeight: 620
    property string selectedId: ""
    property string page: "devices"
    property string addressQuery: ""
    property string confirmUnpairId: ""
    property string replyNotificationId: ""
    property string detailsTab: "notifications"
    readonly property var selectedDevice: PhoneService.deviceById(selectedId)
        ?? PhoneService.primaryDevice
    readonly property var tailscaleMatches:
        PhoneService.matchingTailscalePeers(addressQuery)
    signal shareFileRequested(string deviceId)

    function reloadNotifications() {
        if (visible && page === "devices" && PhoneService.backend === "kdeconnect"
                && selectedDevice?.paired === true
                && selectedDevice?.reachable === true)
            PhoneService.loadNotifications(String(selectedDevice.id))
    }

    onSelectedIdChanged: {
        replyNotificationId = ""
        reloadNotifications()
    }

    onVisibleChanged: {
        if (visible) {
            PopupCoordinator.requestOpen("phone", root)
            PhoneService.refresh()
            PhoneService.loadDiscovery()
            if (selectedId === "" && PhoneService.primaryDevice)
                selectedId = String(PhoneService.primaryDevice.id)
            Qt.callLater(reloadNotifications)
        } else {
            page = "devices"
            addressQuery = ""
            confirmUnpairId = ""
            replyNotificationId = ""
            detailsTab = "notifications"
            PhoneService.clearSms()
        }
    }
    Connections {
        target: PopupCoordinator
        function onOpening(name, owner) {
            if (owner !== root) root.visible = false
        }
    }
    Connections {
        target: ShellActions
        function onPhoneRequested(action) {
            if (!ShellActions.ownsFocusedOutput(root.anchorItem)) return
            if (action === "toggle") root.visible = !root.visible
            else if (action === "open") root.visible = true
            else if (action === "close") root.visible = false
        }
    }
    Connections {
        target: PhoneService
        function onDevicesChanged() {
            if (!PhoneService.deviceById(root.selectedId)
                    && PhoneService.primaryDevice)
                root.selectedId = String(PhoneService.primaryDevice.id)
        }
    }

    component SmallButton: Rectangle {
        id: button
        required property string buttonText
        property color accentColor: Theme.accent
        property bool filled: false
        signal activated()
        implicitWidth: label.implicitWidth + 22
        height: 28
        radius: Theme.radiusSmall
        color: filled ? (mouse.containsMouse
            ? Qt.lighter(accentColor, 1.12) : accentColor)
            : mouse.containsMouse ? Qt.alpha(accentColor, 0.24)
            : Qt.alpha(accentColor, 0.12)
        border.width: 1
        border.color: accentColor
        opacity: enabled ? 1 : 0.45
        Text {
            id: label
            anchors.centerIn: parent
            text: button.buttonText
            color: button.filled ? Theme.selfg : button.accentColor
            font.family: Theme.fontFamily
            font.pixelSize: 11
            font.bold: true
        }
        MouseArea {
            id: mouse
            anchors.fill: parent
            enabled: button.enabled
            hoverEnabled: true
            onClicked: button.activated()
        }
    }

    component SwitchPill: Rectangle {
        id: pill
        required property bool checked
        signal toggled()
        width: 38
        height: 20
        radius: Math.min(height / 2, Theme.radiusSmall)
        color: checked ? Theme.accent : Qt.alpha(Theme.fg, 0.16)
        opacity: enabled ? 1 : 0.45
        Rectangle {
            x: pill.checked ? parent.width - width - 3 : 3
            anchors.verticalCenter: parent.verticalCenter
            width: 14; height: 14
            radius: Math.min(width / 2, Theme.radiusSmall)
            color: pill.checked ? Theme.bg : Qt.alpha(Theme.fg, 0.7)
            Behavior on x { NumberAnimation { duration: 140 } }
        }
        MouseArea {
            anchors.fill: parent
            enabled: pill.enabled
            onClicked: pill.toggled()
        }
    }

    component InputBox: Rectangle {
        id: box
        property alias text: editor.text
        property string placeholder: ""
        signal accepted()
        function focusEditor() { editor.forceActiveFocus() }
        height: 32
        radius: Theme.radiusSmall
        color: Theme.gray2
        border.width: 1
        border.color: editor.activeFocus ? Theme.activeBorder : Theme.gray5
        TextInput {
            id: editor
            anchors.fill: parent
            anchors.leftMargin: 9; anchors.rightMargin: 9
            verticalAlignment: TextInput.AlignVCenter
            color: Theme.fg
            selectionColor: Theme.selbg
            selectedTextColor: Theme.selfg
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSize
            clip: true
            onAccepted: box.accepted()
            Text {
                visible: editor.text === ""
                anchors.verticalCenter: parent.verticalCenter
                text: box.placeholder
                color: Theme.disabled
                font: editor.font
            }
        }
    }

    component ShortcutButton: Rectangle {
        id: shortcut
        required property string buttonText
        required property string glyph
        property color accentColor: Theme.accent
        signal activated()
        height: 54
        radius: Theme.radiusSmall
        color: shortcutMouse.containsMouse
            ? Qt.alpha(accentColor, 0.2) : Theme.gray2
        border.width: 1
        border.color: Theme.gray5
        opacity: enabled ? 1 : 0.35
        Column {
            anchors.centerIn: parent
            spacing: 3
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: shortcut.glyph
                color: shortcut.accentColor
                font.family: Theme.iconFontFamily
                font.pixelSize: Theme.iconSize
            }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: shortcut.buttonText
                color: Theme.fg
                font.family: Theme.fontFamily
                font.pixelSize: 9
            }
        }
        MouseArea {
            id: shortcutMouse
            anchors.fill: parent
            enabled: shortcut.enabled
            hoverEnabled: true
            onClicked: shortcut.activated()
        }
    }

    component TabButton: Rectangle {
        id: tab
        required property string buttonText
        required property bool selected
        signal activated()
        height: 30
        radius: Theme.radiusSmall
        color: selected ? Qt.alpha(Theme.accent, 0.2)
            : tabMouse.containsMouse ? Theme.gray3 : Theme.gray2
        border.width: 1
        border.color: selected ? Theme.accent : Theme.gray5
        Text {
            anchors.centerIn: parent
            text: tab.buttonText
            color: tab.selected ? Theme.accent : Theme.disabled
            font.family: Theme.fontFamily
            font.pixelSize: 11
            font.bold: tab.selected
        }
        MouseArea {
            id: tabMouse
            anchors.fill: parent
            hoverEnabled: true
            onClicked: tab.activated()
        }
    }

    Column {
        visible: root.page === "devices"
        anchors.fill: parent
        spacing: 8
        focus: visible
        Keys.onEscapePressed: root.visible = false

        Row {
            width: parent.width
            height: 30
            spacing: 8
            Text {
                width: parent.width - serviceSwitch.width - 8
                anchors.verticalCenter: parent.verticalCenter
                text: PhoneService.backend === "kdeconnect" ? "KDE Connect"
                    : PhoneService.backend === "valent" ? "Valent" : "Phone connect"
                color: Theme.fg
                elide: Text.ElideRight
                font.family: Theme.fontFamily
                font.pixelSize: 16
                font.bold: true
            }
            SwitchPill {
                id: serviceSwitch
                anchors.verticalCenter: parent.verticalCenter
                checked: PhoneService.running
                enabled: PhoneService.installed && !PhoneService.busy
                onToggled: PhoneService.toggleBackend()
            }
        }

        Text {
            visible: PhoneService.error !== "" || PhoneService.status !== ""
            width: parent.width
            text: PhoneService.error !== "" ? PhoneService.error : PhoneService.status
            color: PhoneService.error !== "" ? Theme.red : Theme.disabled
            elide: Text.ElideRight
            font.family: Theme.fontFamily
            font.pixelSize: 10
        }

        Rectangle {
            visible: !PhoneService.running
            width: parent.width; height: 62
            radius: Theme.radiusMedium
            color: Theme.gray2
            Text {
                anchors.centerIn: parent
                text: PhoneService.installed
                    ? "Turn on KDE Connect or Valent to view devices"
                    : "Install kdeconnect or valent"
                color: Theme.disabled
                font.family: Theme.fontFamily
                font.pixelSize: 11
            }
        }

        Flickable {
            id: panelScroll
            visible: PhoneService.running
            width: parent.width
            height: parent.height - y
            contentWidth: width
            contentHeight: panelContent.implicitHeight
            clip: true
            boundsBehavior: Flickable.StopAtBounds

            Column {
                id: panelContent
                width: panelScroll.width - 14
                spacing: 8

                Row {
                    width: parent.width; height: 28
                    spacing: 7
                    Text {
                        width: parent.width - manager.width - refresh.width
                            - parent.spacing * 2
                        anchors.verticalCenter: parent.verticalCenter
                        text: PhoneService.devices.length + " device"
                            + (PhoneService.devices.length === 1 ? "" : "s")
                        color: Theme.accent
                        font.family: Theme.fontFamily
                        font.pixelSize: 12
                        font.bold: true
                    }
                    SmallButton {
                        id: manager
                        anchors.verticalCenter: parent.verticalCenter
                        buttonText: "Manager"
                        enabled: PhoneService.installed && !PhoneService.busy
                        onActivated: PhoneService.openManager()
                    }
                    SmallButton {
                        id: refresh
                        anchors.verticalCenter: parent.verticalCenter
                        buttonText: "Refresh"
                        enabled: !PhoneService.busy
                        onActivated: {
                            PhoneService.refresh()
                            PhoneService.loadDiscovery()
                            root.reloadNotifications()
                        }
                    }
                }

                Repeater {
                    model: PhoneService.devices
                    Rectangle {
                        id: deviceRow
                        required property var modelData
                        readonly property bool selected:
                            String(root.selectedDevice?.id ?? "")
                                === String(modelData.id)
                        width: panelContent.width; height: 48
                        radius: Theme.radiusSmall
                        color: selected ? Qt.alpha(Theme.accent, 0.16)
                            : rowMouse.containsMouse ? Theme.gray3 : Theme.gray2
                        border.width: 1
                        border.color: selected ? Theme.accent : Theme.gray5
                        Text {
                            id: deviceIcon
                            anchors.left: parent.left; anchors.leftMargin: 10
                            anchors.verticalCenter: parent.verticalCenter
                            text: deviceRow.modelData.type === "tablet" ? "󰓶"
                                : deviceRow.modelData.type === "laptop" ? "󰌢" : "󰏲"
                            color: deviceRow.modelData.paired
                                && deviceRow.modelData.reachable
                                ? Theme.accent : Theme.disabled
                            font.family: Theme.iconFontFamily
                            font.pixelSize: Theme.iconSize
                        }
                        Column {
                            anchors.left: deviceIcon.right; anchors.leftMargin: 8
                            anchors.right: batteryText.left; anchors.rightMargin: 8
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 2
                            Text {
                                width: parent.width
                                text: deviceRow.modelData.name
                                color: Theme.fg
                                elide: Text.ElideRight
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontSize
                                font.bold: deviceRow.selected
                            }
                            Text {
                                width: parent.width
                                text: deviceRow.modelData.pairRequestedByPeer
                                    ? "pairing request" : deviceRow.modelData.paired
                                    ? (deviceRow.modelData.reachable
                                        ? "connected" : "paired · offline")
                                    : deviceRow.modelData.reachable
                                    ? "ready to pair" : "unavailable"
                                color: deviceRow.modelData.pairRequestedByPeer
                                    ? Theme.brightOrange
                                    : deviceRow.modelData.reachable
                                    ? Theme.green : Theme.disabled
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontSize - 2
                            }
                        }
                        Text {
                            id: batteryText
                            anchors.right: parent.right; anchors.rightMargin: 10
                            anchors.verticalCenter: parent.verticalCenter
                            text: Number(deviceRow.modelData.battery) >= 0
                                ? (deviceRow.modelData.charging ? "󰂄 " : "")
                                    + Math.round(Number(deviceRow.modelData.battery)) + "%" : ""
                            color: Number(deviceRow.modelData.battery) <= 15
                                ? Theme.red : Theme.cyan
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSize - 1
                        }
                        MouseArea {
                            id: rowMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            onClicked: {
                                root.selectedId = String(deviceRow.modelData.id)
                                root.confirmUnpairId = ""
                            }
                        }
                    }
                }

                Text {
                    visible: PhoneService.devices.length === 0
                    width: parent.width
                    topPadding: 16; bottomPadding: 16
                    horizontalAlignment: Text.AlignHCenter
                    text: "No devices found · keep KDE Connect open on the phone"
                    color: Theme.disabled
                    font.family: Theme.fontFamily
                    font.pixelSize: 11
                }

                Text {
                    visible: root.selectedDevice?.verificationKey !== ""
                    width: parent.width
                    text: "Verify " + root.selectedDevice?.verificationKey
                        + " on both devices"
                    horizontalAlignment: Text.AlignHCenter
                    color: Theme.brightOrange
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSize
                    font.bold: true
                }

                Row {
                    visible: root.selectedDevice !== null
                        && (root.selectedDevice?.paired !== true
                            || root.selectedDevice?.pairRequestedByPeer === true)
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: 7
                    SmallButton {
                        visible: root.selectedDevice?.pairRequestedByPeer === true
                        buttonText: "Accept"; filled: true; accentColor: Theme.green
                        enabled: !PhoneService.busy
                        onActivated: PhoneService.accept(root.selectedDevice.id)
                    }
                    SmallButton {
                        visible: root.selectedDevice?.pairRequestedByPeer === true
                        buttonText: "Reject"; accentColor: Theme.red
                        enabled: !PhoneService.busy
                        onActivated: PhoneService.reject(root.selectedDevice.id)
                    }
                    SmallButton {
                        visible: root.selectedDevice?.paired !== true
                            && root.selectedDevice?.pairRequestedByPeer !== true
                        buttonText: root.selectedDevice?.pairRequested ? "Pairing…" : "Pair"
                        filled: true; accentColor: Theme.green
                        enabled: !PhoneService.busy && root.selectedDevice?.reachable
                        onActivated: PhoneService.pair(root.selectedDevice.id)
                    }
                }

                Row {
                    visible: root.selectedDevice?.paired === true
                    width: parent.width
                    spacing: 5
                    ShortcutButton {
                        width: (parent.width - parent.spacing * 5) / 6
                        buttonText: "Clipboard"; glyph: "󰅌"
                        enabled: !PhoneService.busy && root.selectedDevice?.reachable
                            && PhoneService.hasPlugin(root.selectedDevice, "clipboard")
                        onActivated: PhoneService.sendClipboard(root.selectedDevice.id)
                    }
                    ShortcutButton {
                        width: (parent.width - parent.spacing * 5) / 6
                        buttonText: "Send"; glyph: "󰈔"
                        enabled: !PhoneService.busy && root.selectedDevice?.reachable
                            && PhoneService.hasPlugin(root.selectedDevice, "share")
                        onActivated: root.shareFileRequested(String(root.selectedDevice.id))
                    }
                    ShortcutButton {
                        width: (parent.width - parent.spacing * 5) / 6
                        buttonText: "Browse"; glyph: "󰉋"
                        enabled: !PhoneService.busy && root.selectedDevice?.reachable
                            && PhoneService.hasPlugin(root.selectedDevice, "sftp")
                        onActivated: PhoneService.browse(root.selectedDevice.id)
                    }
                    ShortcutButton {
                        width: (parent.width - parent.spacing * 5) / 6
                        buttonText: "Ring"; glyph: "󰂞"
                        enabled: !PhoneService.busy && root.selectedDevice?.reachable
                            && PhoneService.hasPlugin(root.selectedDevice, "findmyphone")
                        onActivated: PhoneService.ring(root.selectedDevice.id)
                    }
                    ShortcutButton {
                        width: (parent.width - parent.spacing * 5) / 6
                        buttonText: "Ping"; glyph: "󰑐"
                        enabled: !PhoneService.busy && root.selectedDevice?.reachable
                            && PhoneService.hasPlugin(root.selectedDevice, "ping")
                        onActivated: PhoneService.ping(root.selectedDevice.id)
                    }
                    ShortcutButton {
                        width: (parent.width - parent.spacing * 5) / 6
                        buttonText: "Messages"; glyph: "󰍡"
                        enabled: !PhoneService.busy && root.selectedDevice?.reachable
                            && PhoneService.hasPlugin(root.selectedDevice, "sms")
                        onActivated: {
                            if (PhoneService.backend === "valent")
                                PhoneService.openSmsApp(root.selectedDevice.id)
                            else root.page = "sms"
                        }
                    }
                }

                SmallButton {
                    visible: root.selectedDevice?.paired === true
                    anchors.right: parent.right
                    buttonText: root.confirmUnpairId
                        === String(root.selectedDevice?.id ?? "")
                        ? "Confirm unpair" : "Unpair"
                    accentColor: Theme.red
                    enabled: !PhoneService.busy
                    onActivated: {
                        const id = String(root.selectedDevice.id)
                        if (root.confirmUnpairId === id) {
                            root.confirmUnpairId = ""
                            PhoneService.unpair(id)
                        } else {
                            root.confirmUnpairId = id
                            unpairReset.restart()
                        }
                    }
                }

                Row {
                    visible: PhoneService.backend === "kdeconnect"
                    width: parent.width
                    height: 30
                    spacing: 7
                    TabButton {
                        width: (parent.width - parent.spacing) / 2
                        buttonText: "Notifications"
                        selected: root.detailsTab === "notifications"
                        onActivated: {
                            root.detailsTab = "notifications"
                            root.reloadNotifications()
                        }
                    }
                    TabButton {
                        width: (parent.width - parent.spacing) / 2
                        buttonText: "Discovery"
                        selected: root.detailsTab === "discovery"
                        onActivated: {
                            root.detailsTab = "discovery"
                            PhoneService.loadDiscovery()
                        }
                    }
                }

                Rectangle {
                    visible: PhoneService.backend === "kdeconnect"
                        && root.detailsTab === "notifications"
                        && root.selectedDevice?.paired === true
                    width: parent.width; height: 1
                    color: Qt.alpha(Theme.fg, 0.1)
                }
                Row {
                    visible: PhoneService.backend === "kdeconnect"
                        && root.detailsTab === "notifications"
                        && root.selectedDevice?.paired === true
                    width: parent.width; height: 28
                    Text {
                        width: parent.width
                        anchors.verticalCenter: parent.verticalCenter
                        text: "Notifications · " + PhoneService.notifications.length
                        color: Theme.accent
                        font.family: Theme.fontFamily
                        font.pixelSize: 12
                        font.bold: true
                    }
                }
                Text {
                    visible: PhoneService.backend === "kdeconnect"
                        && root.detailsTab === "notifications"
                        && root.selectedDevice?.paired === true
                        && PhoneService.notifications.length === 0
                    width: parent.width
                    text: root.selectedDevice?.reachable
                        ? "No phone notifications" : "Device is offline"
                    color: Theme.disabled
                    horizontalAlignment: Text.AlignHCenter
                    font.family: Theme.fontFamily
                    font.pixelSize: 11
                }
                Repeater {
                    model: PhoneService.backend === "kdeconnect"
                        && root.detailsTab === "notifications"
                        && root.selectedDevice?.paired === true
                        ? PhoneService.notifications : []
                    Rectangle {
                        id: notificationRow
                        required property var modelData
                        readonly property bool replying: root.replyNotificationId
                            === String(modelData.id)
                        width: panelContent.width
                        height: replying ? 100 : 62
                        radius: Theme.radiusSmall
                        color: Theme.gray2
                        border.width: 1
                        border.color: Theme.gray5
                        clip: true
                        Behavior on height {
                            NumberAnimation { duration: 140; easing.type: Easing.OutCubic }
                        }
                        onReplyingChanged: if (replying)
                            Qt.callLater(() => notificationReply.focusEditor())
                        Column {
                            anchors.left: parent.left; anchors.leftMargin: 9
                            anchors.right: noteActions.left; anchors.rightMargin: 7
                            anchors.top: parent.top; anchors.topMargin: 7
                            spacing: 2
                            Text {
                                width: parent.width
                                text: String(notificationRow.modelData.app ?? "").toUpperCase()
                                color: Theme.disabled
                                elide: Text.ElideRight
                                maximumLineCount: 1
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontSize - 3
                                font.bold: true
                            }
                            Text {
                                width: parent.width
                                text: notificationRow.modelData.title || "Notification"
                                color: Theme.fg
                                elide: Text.ElideRight
                                maximumLineCount: 1
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontSize - 1
                                font.bold: true
                            }
                            Text {
                                width: parent.width
                                text: notificationRow.modelData.text || ""
                                color: Theme.disabled
                                elide: Text.ElideRight
                                maximumLineCount: 1
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontSize - 2
                            }
                        }
                        Row {
                            id: noteActions
                            anchors.right: parent.right; anchors.rightMargin: 5
                            anchors.top: parent.top; anchors.topMargin: 16
                            spacing: 5
                            SmallButton {
                                visible: String(notificationRow.modelData.replyId ?? "") !== ""
                                buttonText: notificationRow.replying ? "Cancel" : "Reply"
                                onActivated: root.replyNotificationId
                                    = notificationRow.replying ? ""
                                    : String(notificationRow.modelData.id)
                            }
                            SmallButton {
                                visible: notificationRow.modelData.dismissable === true
                                buttonText: "Dismiss"
                                accentColor: Theme.red
                                enabled: !PhoneService.busy
                                onActivated: PhoneService.dismissNotification(
                                    root.selectedDevice.id,
                                    String(notificationRow.modelData.id))
                            }
                        }
                        Row {
                            visible: notificationRow.replying
                            anchors.left: parent.left; anchors.leftMargin: 7
                            anchors.right: parent.right; anchors.rightMargin: 7
                            anchors.bottom: parent.bottom; anchors.bottomMargin: 6
                            height: 30
                            spacing: 6
                            InputBox {
                                id: notificationReply
                                width: parent.width - replySend.width - parent.spacing
                                height: 30
                                placeholder: "Reply to notification"
                                onAccepted: replySend.activated()
                            }
                            SmallButton {
                                id: replySend
                                anchors.verticalCenter: parent.verticalCenter
                                buttonText: "Send"
                                filled: true
                                enabled: !PhoneService.busy
                                    && notificationReply.text.trim() !== ""
                                onActivated: {
                                    if (PhoneService.replyNotification(
                                            root.selectedDevice.id,
                                            String(notificationRow.modelData.id),
                                            String(notificationRow.modelData.replyId),
                                            notificationReply.text.trim())) {
                                        notificationReply.text = ""
                                        root.replyNotificationId = ""
                                    }
                                }
                            }
                        }
                    }
                }

                Rectangle {
                    visible: PhoneService.backend === "kdeconnect"
                        && root.detailsTab === "discovery"
                    width: parent.width; height: 1
                    color: Qt.alpha(Theme.fg, 0.1)
                }
                Row {
                    visible: PhoneService.backend === "kdeconnect"
                        && root.detailsTab === "discovery"
                    width: parent.width
                    height: 28
                    spacing: 7
                    Text {
                        width: parent.width - discoverButton.width - parent.spacing
                        anchors.verticalCenter: parent.verticalCenter
                        text: "Discovery"
                        color: Theme.accent
                        font.family: Theme.fontFamily
                        font.pixelSize: 12
                        font.bold: true
                    }
                    SmallButton {
                        id: discoverButton
                        anchors.verticalCenter: parent.verticalCenter
                        buttonText: "Discover"
                        enabled: !PhoneService.busy
                        onActivated: PhoneService.discover()
                    }
                }
                Rectangle {
                    visible: PhoneService.backend === "kdeconnect"
                        && root.detailsTab === "discovery"
                    width: parent.width; height: 54
                    radius: Theme.radiusSmall
                    color: Theme.gray2
                    border.width: 1; border.color: Theme.gray5
                    Column {
                        anchors.fill: parent; anchors.margins: 8; spacing: 4
                        Text {
                            text: "This computer · LAN  "
                                + (PhoneService.localLanAddress || "unavailable")
                            color: Theme.fg
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSize - 1
                        }
                        Text {
                            text: "Tailscale  " + (PhoneService.tailscaleRunning
                                ? (PhoneService.localTailscaleAddress || "connected")
                                : PhoneService.tailscaleInstalled ? "not connected" : "not installed")
                            color: PhoneService.tailscaleRunning ? Theme.green : Theme.disabled
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSize - 2
                        }
                    }
                }

                Row {
                    visible: PhoneService.backend === "kdeconnect"
                        && root.detailsTab === "discovery"
                    width: parent.width; spacing: 7
                    InputBox {
                        id: addressInput
                        width: parent.width - addAddress.width - parent.spacing
                        placeholder: "IP address or Tailscale machine name"
                        onTextChanged: root.addressQuery = text
                        onAccepted: if (text.trim() !== "") PhoneService.addAddress(text)
                    }
                    SmallButton {
                        id: addAddress
                        anchors.verticalCenter: parent.verticalCenter
                        buttonText: "Add"; filled: true
                        enabled: !PhoneService.busy && addressInput.text.trim() !== ""
                        onActivated: PhoneService.addAddress(addressInput.text)
                    }
                }

                Text {
                    visible: PhoneService.backend === "kdeconnect"
                        && root.detailsTab === "discovery"
                        && root.tailscaleMatches.length > 0
                    text: "TAILSCALE PEERS"
                    color: Theme.accent
                    font.family: Theme.fontFamily
                    font.pixelSize: 10
                    font.bold: true
                }
                Repeater {
                    model: PhoneService.backend === "kdeconnect"
                        && root.detailsTab === "discovery"
                        ? root.tailscaleMatches : []
                    Rectangle {
                        id: peerRow
                        required property var modelData
                        width: panelContent.width; height: 38
                        radius: Theme.radiusSmall
                        color: peerMouse.containsMouse ? Theme.gray3 : Theme.gray2
                        border.width: 1; border.color: Theme.gray5
                        Text {
                            anchors.left: parent.left; anchors.leftMargin: 9
                            anchors.right: peerAdd.left; anchors.rightMargin: 8
                            anchors.verticalCenter: parent.verticalCenter
                            text: peerRow.modelData.name + " · " + peerRow.modelData.address
                            color: peerRow.modelData.online ? Theme.fg : Theme.disabled
                            elide: Text.ElideRight
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSize - 1
                        }
                        SmallButton {
                            id: peerAdd
                            anchors.right: parent.right; anchors.rightMargin: 5
                            anchors.verticalCenter: parent.verticalCenter
                            buttonText: PhoneService.customAddresses.indexOf(
                                String(peerRow.modelData.address)) >= 0 ? "Saved" : "Add"
                            enabled: !PhoneService.busy
                                && PhoneService.customAddresses.indexOf(
                                    String(peerRow.modelData.address)) < 0
                            onActivated: PhoneService.addAddress(
                                String(peerRow.modelData.address))
                        }
                        MouseArea {
                            id: peerMouse
                            anchors.left: parent.left; anchors.right: peerAdd.left
                            anchors.top: parent.top; anchors.bottom: parent.bottom
                            hoverEnabled: true
                            onClicked: addressInput.text = String(peerRow.modelData.name)
                        }
                    }
                }

                Text {
                    visible: PhoneService.backend === "kdeconnect"
                        && root.detailsTab === "discovery"
                        && PhoneService.customAddresses.length > 0
                    text: "SAVED ADDRESSES"
                    color: Theme.accent
                    font.family: Theme.fontFamily
                    font.pixelSize: 10
                    font.bold: true
                }
                Repeater {
                    model: PhoneService.backend === "kdeconnect"
                        && root.detailsTab === "discovery"
                        ? PhoneService.customAddresses : []
                    Rectangle {
                        id: savedRow
                        required property var modelData
                        width: panelContent.width; height: 36
                        radius: Theme.radiusSmall
                        color: Theme.gray2
                        border.width: 1; border.color: Theme.gray5
                        Text {
                            anchors.left: parent.left; anchors.leftMargin: 9
                            anchors.verticalCenter: parent.verticalCenter
                            text: String(savedRow.modelData)
                            color: Theme.fg
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSize - 1
                        }
                        SmallButton {
                            anchors.right: parent.right; anchors.rightMargin: 5
                            anchors.verticalCenter: parent.verticalCenter
                            buttonText: "Remove"; accentColor: Theme.red
                            enabled: !PhoneService.busy
                            onActivated: PhoneService.removeAddress(String(savedRow.modelData))
                        }
                    }
                }
            }

            Controls.ScrollBar.vertical: Controls.ScrollBar {
                id: panelScrollBar
                width: 8
                policy: Controls.ScrollBar.AsNeeded
                interactive: true
                background: Rectangle {
                    color: Theme.gray2
                    border.width: 1; border.color: Theme.gray5
                    radius: Math.min(width / 2, Theme.radiusSmall)
                }
                contentItem: Rectangle {
                    implicitWidth: 6; implicitHeight: 28
                    color: panelScrollBar.pressed ? Theme.brightOrange
                        : panelScrollBar.hovered ? Theme.orange : Theme.gray6
                    radius: Math.min(width / 2, Theme.radiusSmall)
                    Behavior on color { ColorAnimation { duration: 100 } }
                }
            }
        }
    }

    PhoneSms {
        visible: root.page === "sms"
        anchors.fill: parent
        device: root.selectedDevice
        onBackRequested: root.page = "devices"
    }
    Timer {
        id: unpairReset
        interval: 5000
        onTriggered: root.confirmUnpairId = ""
    }
}
