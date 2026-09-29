pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls as Controls
import QtQuick.Dialogs
import "../.."

Popout {
    id: root

    cardWidth: 610
    cardHeight: 650
    suspendOutsideClose: sendDialog.visible
    property string tab: "connection"
    property string peerQuery: ""
    property string mullvadQuery: ""
    property bool offlineExpanded: false
    property var filePeer: null
    property var copyPeer: null
    property bool accountMenuOpen: false

    readonly property var tabs: TailscaleService.mullvadRegions.length > 0
        ? ["connection", "exitNodes", "mullvad", "machines"]
        : ["connection", "exitNodes", "machines"]
    readonly property var onlinePeers:
        TailscaleService.filteredPeers(peerQuery, true)
    readonly property var offlinePeers:
        TailscaleService.filteredPeers(peerQuery, false)
    readonly property var visibleMullvad: TailscaleService.mullvadRegions.filter(item => {
        const text = (item.City + " " + item.Country).toLowerCase()
        return text.indexOf(mullvadQuery.trim().toLowerCase()) >= 0
    })

    onVisibleChanged: {
        if (visible) {
            PopupCoordinator.requestOpen("tailscale", root)
            TailscaleService.refresh()
            if (tab === "exitNodes") TailscaleService.refreshSuggestion()
        } else {
            copyPeer = null
            accountMenuOpen = false
        }
    }

    Connections {
        target: PopupCoordinator
        function onOpening(name, owner) {
            if (owner !== root) root.visible = false
        }
    }

    function selectTab(name) {
        tab = name
        accountMenuOpen = false
        if (name === "exitNodes") TailscaleService.refreshSuggestion()
    }

    component SmallButton: Rectangle {
        id: button
        required property string label
        property string icon: ""
        property bool filled: false
        property color accentColor: Theme.accent
        signal activated()
        implicitWidth: content.implicitWidth + 18
        height: 28
        radius: Theme.radiusSmall
        color: filled ? accentColor : mouse.containsMouse
            ? Qt.alpha(accentColor, 0.22) : Theme.gray2
        border.width: 1
        border.color: accentColor
        opacity: enabled ? 1 : 0.42
        Row {
            id: content
            anchors.centerIn: parent
            spacing: 5
            Text {
                visible: button.icon !== ""
                text: button.icon
                color: button.filled ? Theme.selfg : button.accentColor
                font.family: Theme.iconFontFamily
                font.pixelSize: Theme.iconSizeSmall
            }
            Text {
                text: button.label
                color: button.filled ? Theme.selfg : button.accentColor
                font.family: Theme.fontFamily
                font.pixelSize: Math.max(9, Theme.fontSize - 2)
                font.bold: button.filled
            }
        }
        MouseArea {
            id: mouse
            anchors.fill: parent
            hoverEnabled: true
            enabled: button.enabled
            onClicked: button.activated()
        }
    }

    component ToggleSwitch: Rectangle {
        id: control
        required property bool checked
        signal toggled()
        width: 38
        height: 20
        radius: Math.min(height / 2, Theme.radiusSmall)
        color: checked ? Theme.accent : Qt.alpha(Theme.fg, 0.15)
        opacity: enabled ? 1 : 0.4
        Rectangle {
            x: control.checked ? parent.width - width - 3 : 3
            anchors.verticalCenter: parent.verticalCenter
            width: 14
            height: 14
            radius: Math.min(width / 2, Theme.radiusSmall)
            color: control.checked ? Theme.bg : Qt.alpha(Theme.fg, 0.7)
            Behavior on x { NumberAnimation { duration: 140 } }
        }
        MouseArea {
            anchors.fill: parent
            enabled: control.enabled
            onClicked: control.toggled()
        }
    }

    component SearchField: Rectangle {
        id: search
        property alias text: input.text
        property string placeholder: "Search"
        signal accepted()
        width: parent ? parent.width : 0
        height: 36
        radius: Theme.radiusSmall
        color: Theme.gray2
        border.width: 1
        border.color: input.activeFocus ? Theme.accent : Theme.gray5
        Text {
            anchors.left: parent.left
            anchors.leftMargin: 10
            anchors.verticalCenter: parent.verticalCenter
            text: "󰍉"
            color: Theme.foregroundMuted
            font.family: Theme.iconFontFamily
            font.pixelSize: Theme.iconSizeSmall
        }
        TextInput {
            id: input
            anchors.fill: parent
            anchors.leftMargin: 34
            anchors.rightMargin: 10
            verticalAlignment: TextInput.AlignVCenter
            color: Theme.fg
            selectionColor: Theme.selbg
            selectedTextColor: Theme.selfg
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSize
            clip: true
            onAccepted: search.accepted()
            Text {
                visible: input.text === ""
                anchors.verticalCenter: parent.verticalCenter
                text: search.placeholder
                color: Theme.foregroundMuted
                font: input.font
            }
        }
    }

    component SettingRow: Rectangle {
        id: setting
        required property string title
        required property string detail
        required property bool checked
        signal toggled()
        width: parent ? parent.width : 0
        height: 52
        radius: Theme.radiusMedium
        color: Theme.gray2
        border.width: 1
        border.color: Theme.gray5
        Column {
            anchors.left: parent.left
            anchors.leftMargin: 11
            anchors.right: toggle.left
            anchors.rightMargin: 10
            anchors.verticalCenter: parent.verticalCenter
            spacing: 1
            Text {
                width: parent.width
                text: setting.title
                color: Theme.fg
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSize
                elide: Text.ElideRight
            }
            Text {
                width: parent.width
                text: setting.detail
                color: Theme.foregroundMuted
                font.family: Theme.fontFamily
                font.pixelSize: Math.max(8, Theme.fontSize - 3)
                elide: Text.ElideRight
            }
        }
        ToggleSwitch {
            id: toggle
            anchors.right: parent.right
            anchors.rightMargin: 11
            anchors.verticalCenter: parent.verticalCenter
            checked: setting.checked
            enabled: setting.enabled
            onToggled: setting.toggled()
        }
    }

    component NodeRow: Rectangle {
        id: nodeRow
        required property var node
        property string subtitle: ""
        width: parent ? parent.width : 0
        height: 58
        radius: Theme.radiusMedium
        color: nodeMouse.containsMouse ? Theme.gray3 : Theme.gray2
        border.width: 1
        border.color: node.ExitNode ? Theme.activeBorder : Theme.gray5
        Rectangle {
            anchors.left: parent.left
            anchors.leftMargin: 10
            anchors.verticalCenter: parent.verticalCenter
            width: 8
            height: 8
            radius: 4
            color: node.ExitNode ? Theme.accent : Theme.foregroundMuted
        }
        Column {
            anchors.left: parent.left
            anchors.leftMargin: 30
            anchors.right: nodeToggle.left
            anchors.rightMargin: 10
            anchors.verticalCenter: parent.verticalCenter
            spacing: 2
            Text {
                width: parent.width
                text: node.DisplayName || node.HostName
                color: Theme.fg
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSize
                font.bold: node.ExitNode
                elide: Text.ElideRight
            }
            Text {
                width: parent.width
                text: nodeRow.subtitle || node.DNSName || node.HostName
                color: Theme.foregroundMuted
                font.family: Theme.fontFamily
                font.pixelSize: Math.max(8, Theme.fontSize - 3)
                elide: Text.ElideMiddle
            }
        }
        ToggleSwitch {
            id: nodeToggle
            anchors.right: parent.right
            anchors.rightMargin: 11
            anchors.verticalCenter: parent.verticalCenter
            checked: node.ExitNode === true
            enabled: !TailscaleService.busy
            onToggled: TailscaleService.setExitNode(nodeRow.node)
        }
        MouseArea {
            id: nodeMouse
            anchors.fill: parent
            anchors.rightMargin: 55
            hoverEnabled: true
            onClicked: TailscaleService.setExitNode(nodeRow.node)
        }
    }

    component PeerRow: Rectangle {
        id: peerRow
        required property var peer
        width: parent ? parent.width : 0
        height: 70
        radius: Theme.radiusMedium
        color: peerMouse.containsMouse ? Theme.gray3 : Theme.gray2
        border.width: 1
        border.color: peer.Online ? Qt.alpha(Theme.accent, 0.7) : Theme.gray5
        Text {
            id: osIcon
            anchors.left: parent.left
            anchors.leftMargin: 10
            anchors.verticalCenter: parent.verticalCenter
            text: TailscaleService.osIcon(peer.OS)
            color: peer.Online ? Theme.accent : Theme.foregroundMuted
            font.family: Theme.iconFontFamily
            font.pixelSize: Theme.iconSizeLarge
        }
        Column {
            anchors.left: osIcon.right
            anchors.leftMargin: 9
            anchors.right: actions.left
            anchors.rightMargin: 8
            anchors.verticalCenter: parent.verticalCenter
            spacing: 2
            Text {
                width: parent.width
                text: peer.HostName
                color: peer.Online ? Theme.fg : Theme.foregroundMuted
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSize
                font.bold: peer.Active
                elide: Text.ElideRight
            }
            Text {
                width: parent.width
                text: (peer.TailscaleIPs[0] || peer.DNSName)
                    + (peer.Online ? "  ↓ " + TailscaleService.fmtBytes(peer.RxBytes)
                        + "  ↑ " + TailscaleService.fmtBytes(peer.TxBytes)
                        : "  · seen " + TailscaleService.fmtLastSeen(peer.LastSeen))
                color: Theme.foregroundMuted
                font.family: Theme.fontFamily
                font.pixelSize: Math.max(8, Theme.fontSize - 3)
                elide: Text.ElideRight
            }
        }
        Row {
            id: actions
            anchors.right: parent.right
            anchors.rightMargin: 8
            anchors.verticalCenter: parent.verticalCenter
            spacing: 5
            Text {
                visible: peerRow.peer.ExitNodeOption === true
                anchors.verticalCenter: parent.verticalCenter
                text: "USE EXIT"
                color: peerRow.peer.ExitNode ? Theme.accent
                    : Theme.foregroundMuted
                font.family: Theme.fontFamily
                font.pixelSize: Math.max(7, Theme.fontSize - 4)
                font.bold: true
            }
            ToggleSwitch {
                visible: peerRow.peer.ExitNodeOption === true
                checked: peerRow.peer.ExitNode === true
                enabled: peerRow.peer.Online && !TailscaleService.busy
                onToggled: TailscaleService.setExitNode(peerRow.peer)
            }
            SmallButton {
                label: ""
                icon: "󰅌"
                implicitWidth: 30
                onActivated: root.copyPeer = peerRow.peer
            }
            SmallButton {
                label: ""
                icon: "󰆍"
                implicitWidth: 30
                enabled: peerRow.peer.Online
                onActivated: TailscaleService.ssh(peerRow.peer)
            }
            SmallButton {
                label: ""
                icon: "󰈔"
                implicitWidth: 30
                enabled: TailscaleService.canSend(peerRow.peer)
                onActivated: {
                    root.filePeer = peerRow.peer
                    sendDialog.open()
                }
            }
        }
        MouseArea {
            id: peerMouse
            anchors.fill: parent
            anchors.rightMargin: peerRow.peer.ExitNodeOption ? 215 : 116
            hoverEnabled: true
            onClicked: TailscaleService.copy(peerRow.peer.TailscaleIPs[0]
                || peerRow.peer.DNSName)
        }
    }

    FileDialog {
        id: sendDialog
        title: root.filePeer ? "Send to " + root.filePeer.HostName : "Send with Taildrop"
        fileMode: FileDialog.OpenFile
        onAccepted: TailscaleService.sendFile(root.filePeer, selectedFile)
    }

    Column {
        anchors.fill: parent
        spacing: 10

        Row {
            width: parent.width
            height: 31
            spacing: 8
            TailscaleLogo {
                anchors.verticalCenter: parent.verticalCenter
                width: 22
                height: 22
                dotColor: TailscaleService.running ? Theme.accent : Theme.foregroundMuted
                disconnected: !TailscaleService.running
                warning: TailscaleService.visibleHealth.length > 0
                    || TailscaleService.pendingFiles.length > 0
            }
            Text {
                width: parent.width - 30 - refresh.width - admin.width
                    - accountButton.width - 32
                anchors.verticalCenter: parent.verticalCenter
                text: "Tailscale"
                color: Theme.fg
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSize + 3
                font.bold: true
            }
            SmallButton {
                id: admin
                label: "Admin"
                icon: "󰖟"
                onActivated: {
                    root.accountMenuOpen = false
                    TailscaleService.openAdmin()
                }
            }
            SmallButton {
                id: accountButton
                label: "Accounts"
                icon: "󰀄"
                onActivated: {
                    root.copyPeer = null
                    root.accountMenuOpen = !root.accountMenuOpen
                }
            }
            SmallButton {
                id: refresh
                label: ""
                icon: "󰑐"
                implicitWidth: 30
                enabled: !TailscaleService.refreshing
                onActivated: TailscaleService.refresh()
            }
        }

        Row {
            width: parent.width
            height: 34
            spacing: 5
            Repeater {
                model: root.tabs
                Rectangle {
                    required property string modelData
                    width: (parent.width - (root.tabs.length - 1) * 5)
                        / root.tabs.length
                    height: 32
                    radius: Theme.radiusSmall
                    color: root.tab === modelData
                        ? Qt.alpha(Theme.accent, 0.22) : tabMouse.containsMouse
                        ? Theme.gray3 : Theme.gray2
                    border.width: 1
                    border.color: root.tab === modelData ? Theme.accent : Theme.gray5
                    Text {
                        anchors.centerIn: parent
                        text: modelData === "connection" ? "Connection"
                            : modelData === "exitNodes" ? "Exit nodes"
                            : modelData === "mullvad" ? "Mullvad" : "Machines"
                        color: root.tab === modelData ? Theme.accent : Theme.fg
                        font.family: Theme.fontFamily
                        font.pixelSize: Math.max(9, Theme.fontSize - 2)
                        font.bold: root.tab === modelData
                    }
                    MouseArea {
                        id: tabMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        onClicked: root.selectTab(modelData)
                    }
                }
            }
        }

        Text {
            visible: TailscaleService.error !== "" || TailscaleService.status !== ""
            width: parent.width
            text: TailscaleService.error || TailscaleService.status
            color: TailscaleService.error !== "" ? Theme.error : Theme.accent
            wrapMode: Text.Wrap
            font.family: Theme.fontFamily
            font.pixelSize: Math.max(9, Theme.fontSize - 2)
        }

        Item {
            width: parent.width
            height: parent.height - y

            Flickable {
                visible: root.tab === "connection"
                anchors.fill: parent
                contentWidth: width
                contentHeight: connectionColumn.implicitHeight
                clip: true
                boundsBehavior: Flickable.StopAtBounds

                Column {
                    id: connectionColumn
                    width: parent.width
                    spacing: 8

                    Rectangle {
                        width: parent.width
                        height: 100
                        radius: Theme.radiusMedium
                        color: Qt.alpha(TailscaleService.running
                            ? Theme.accent : Theme.foregroundMuted, 0.10)
                        border.width: 1
                        border.color: TailscaleService.running
                            ? Theme.accent : Theme.gray5
                        Column {
                            anchors.left: parent.left
                            anchors.leftMargin: 14
                            anchors.right: heroToggle.left
                            anchors.rightMargin: 14
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 4
                            Text {
                                text: !TailscaleService.installed ? "Not installed"
                                    : TailscaleService.needsLogin ? "Login required"
                                    : TailscaleService.running ? "Your tailnet is connected"
                                    : "Tailscale is disconnected"
                                color: Theme.fg
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontSize + 2
                                font.bold: true
                            }
                            Text {
                                width: parent.width
                                text: TailscaleService.running
                                    ? TailscaleService.selfName + "  ·  " + TailscaleService.selfIp
                                    : TailscaleService.backendState
                                color: Theme.foregroundMuted
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontSize - 1
                                elide: Text.ElideRight
                            }
                        }
                        ToggleSwitch {
                            id: heroToggle
                            anchors.right: parent.right
                            anchors.rightMargin: 16
                            anchors.verticalCenter: parent.verticalCenter
                            checked: TailscaleService.running
                            enabled: TailscaleService.installed && !TailscaleService.busy
                            onToggled: TailscaleService.toggle()
                        }
                    }

                    SmallButton {
                        visible: TailscaleService.needsLogin
                        label: "Authorize this device"
                        icon: "󰌾"
                        filled: true
                        onActivated: TailscaleService.login()
                    }

                    Rectangle {
                        visible: TailscaleService.operatorRequired
                        width: parent.width
                        height: 55
                        radius: Theme.radiusMedium
                        color: Qt.alpha(Theme.warning, 0.10)
                        border.width: 1
                        border.color: Theme.warning
                        Text {
                            anchors.left: parent.left
                            anchors.leftMargin: 11
                            anchors.right: authorize.left
                            anchors.rightMargin: 9
                            anchors.verticalCenter: parent.verticalCenter
                            text: "Authorize this user to change Tailscale settings"
                            color: Theme.fg
                            wrapMode: Text.Wrap
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSize - 1
                        }
                        SmallButton {
                            id: authorize
                            anchors.right: parent.right
                            anchors.rightMargin: 10
                            anchors.verticalCenter: parent.verticalCenter
                            label: "Authorize"
                            filled: true
                            accentColor: Theme.warning
                            onActivated: TailscaleService.authorizeOperator()
                        }
                    }

                    Repeater {
                        model: TailscaleService.visibleHealth
                        Rectangle {
                            required property string modelData
                            width: connectionColumn.width
                            height: warningText.implicitHeight + 22
                            radius: Theme.radiusMedium
                            color: Qt.alpha(Theme.warning, 0.10)
                            border.width: 1
                            border.color: Theme.warning
                            Text {
                                id: warningText
                                anchors.left: parent.left
                                anchors.leftMargin: 10
                                anchors.right: dismiss.left
                                anchors.rightMargin: 8
                                anchors.verticalCenter: parent.verticalCenter
                                text: modelData
                                color: Theme.fg
                                wrapMode: Text.Wrap
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontSize - 1
                            }
                            SmallButton {
                                id: dismiss
                                anchors.right: parent.right
                                anchors.rightMargin: 9
                                anchors.verticalCenter: parent.verticalCenter
                                label: "Dismiss"
                                accentColor: Theme.warning
                                onActivated: TailscaleService.acknowledgeHealth(modelData)
                            }
                        }
                    }

                    Text {
                        visible: TailscaleService.pendingFiles.length > 0
                        text: "TAILDROP INBOX"
                        color: Theme.accent
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSize - 2
                        font.bold: true
                    }
                    Repeater {
                        model: TailscaleService.pendingFiles
                        Rectangle {
                            required property var modelData
                            width: connectionColumn.width
                            height: 58
                            radius: Theme.radiusMedium
                            color: Theme.gray2
                            border.width: 1
                            border.color: Theme.accent

                            Text {
                                anchors.left: parent.left
                                anchors.leftMargin: 11
                                anchors.right: receiveButton.left
                                anchors.rightMargin: 9
                                anchors.verticalCenter: parent.verticalCenter
                                text: modelData.name + "  ·  "
                                    + TailscaleService.fmtBytes(modelData.size)
                                color: Theme.fg
                                elide: Text.ElideMiddle
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontSize - 1
                            }
                            SmallButton {
                                id: rejectButton
                                anchors.right: parent.right
                                anchors.rightMargin: 9
                                anchors.verticalCenter: parent.verticalCenter
                                label: "Reject"
                                accentColor: Theme.error
                                enabled: !TailscaleService.taildropBusy
                                onActivated: TailscaleService.rejectTaildrop(
                                    modelData.name)
                            }
                            SmallButton {
                                id: receiveButton
                                anchors.right: rejectButton.left
                                anchors.rightMargin: 6
                                anchors.verticalCenter: parent.verticalCenter
                                label: "Receive"
                                filled: true
                                enabled: !TailscaleService.taildropBusy
                                onActivated: TailscaleService.acceptTaildrop(
                                    modelData.name)
                            }
                        }
                    }

                    Text {
                        visible: TailscaleService.prefsAvailable
                        text: "PRIVACY & ROUTING"
                        color: Theme.accent
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSize - 2
                        font.bold: true
                    }
                    SettingRow {
                        visible: TailscaleService.prefsAvailable
                        enabled: TailscaleService.running && !TailscaleService.busy
                        title: "Accept routes"
                        detail: "Use subnet routes advertised by your tailnet"
                        checked: TailscaleService.acceptRoutes
                        onToggled: TailscaleService.setPreference("--accept-routes", !checked)
                    }
                    SettingRow {
                        visible: TailscaleService.prefsAvailable
                        enabled: TailscaleService.running && !TailscaleService.busy
                        title: "Use Tailscale DNS"
                        detail: "Accept MagicDNS and tailnet DNS configuration"
                        checked: TailscaleService.acceptDns
                        onToggled: TailscaleService.setPreference("--accept-dns", !checked)
                    }
                    SettingRow {
                        visible: TailscaleService.prefsAvailable
                        enabled: TailscaleService.running && !TailscaleService.busy
                        title: "Shields up"
                        detail: "Block incoming connections from tailnet devices"
                        checked: TailscaleService.shieldsUp
                        onToggled: TailscaleService.setPreference("--shields-up", !checked)
                    }
                    SettingRow {
                        visible: TailscaleService.prefsAvailable
                        enabled: TailscaleService.running && !TailscaleService.busy
                        title: "Allow local network access"
                        detail: "Reach LAN devices while this machine uses an exit node"
                        checked: TailscaleService.allowLanAccess
                        onToggled: TailscaleService.setPreference(
                            "--exit-node-allow-lan-access", !checked)
                    }
                    SettingRow {
                        visible: TailscaleService.prefsAvailable
                        enabled: TailscaleService.running && !TailscaleService.busy
                        title: "Advertise as an exit node"
                        detail: "Offer an internet gateway; an admin may need to approve it"
                        checked: TailscaleService.advertiseExitNode
                        onToggled: TailscaleService.setPreference(
                            "--advertise-exit-node", !checked)
                    }
                    SettingRow {
                        visible: TailscaleService.prefsAvailable
                        enabled: TailscaleService.running && !TailscaleService.busy
                        title: "Run Tailscale SSH"
                        detail: "Accept SSH connections governed by the tailnet policy"
                        checked: TailscaleService.runSsh
                        onToggled: TailscaleService.setPreference("--ssh", !checked)
                    }

                    SmallButton {
                        visible: TailscaleService.acknowledgedHealth.length > 0
                        label: "Restore warnings"
                        onActivated: TailscaleService.restoreHealthWarnings()
                    }

                }
            }

            Flickable {
                visible: root.tab === "exitNodes"
                anchors.fill: parent
                contentWidth: width
                contentHeight: exitColumn.implicitHeight
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                Column {
                    id: exitColumn
                    width: parent.width
                    spacing: 7
                    Text {
                        width: parent.width
                        text: TailscaleService.currentExitNode === ""
                            ? "Traffic is using a direct connection."
                            : "Routing through " + TailscaleService.currentExitNode
                        color: Theme.foregroundMuted
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSize - 1
                    }
                    Rectangle {
                        width: parent.width
                        height: 58
                        radius: Theme.radiusMedium
                        color: directMouse.containsMouse ? Theme.gray3 : Theme.gray2
                        border.width: 1
                        border.color: TailscaleService.currentExitNode === ""
                            ? Theme.activeBorder : Theme.gray5
                        Text {
                            anchors.left: parent.left
                            anchors.leftMargin: 12
                            anchors.verticalCenter: parent.verticalCenter
                            text: "Direct connection"
                            color: Theme.fg
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSize
                            font.bold: TailscaleService.currentExitNode === ""
                        }
                        ToggleSwitch {
                            anchors.right: parent.right
                            anchors.rightMargin: 11
                            anchors.verticalCenter: parent.verticalCenter
                            checked: TailscaleService.currentExitNode === ""
                            enabled: !TailscaleService.busy
                            onToggled: TailscaleService.clearExitNode()
                        }
                        MouseArea {
                            id: directMouse
                            anchors.fill: parent
                            anchors.rightMargin: 55
                            hoverEnabled: true
                            onClicked: TailscaleService.clearExitNode()
                        }
                    }
                    Rectangle {
                        visible: TailscaleService.suggestedExitNode !== ""
                        width: parent.width
                        height: visible ? 58 : 0
                        radius: Theme.radiusMedium
                        color: suggestMouse.containsMouse ? Theme.gray3
                            : Qt.alpha(Theme.accent, 0.10)
                        border.width: 1
                        border.color: Theme.accent
                        Column {
                            anchors.left: parent.left
                            anchors.leftMargin: 11
                            anchors.verticalCenter: parent.verticalCenter
                            Text {
                                text: "Suggested exit node"
                                color: Theme.accent
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontSize - 2
                                font.bold: true
                            }
                            Text {
                                text: TailscaleService.suggestedExitNode
                                color: Theme.fg
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontSize
                            }
                        }
                        MouseArea {
                            id: suggestMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            onClicked: TailscaleService.setExitNodeByName(
                                TailscaleService.suggestedExitNode)
                        }
                    }
                    Repeater {
                        model: TailscaleService.tailnetExitNodes
                        NodeRow {
                            required property var modelData
                            node: modelData
                            subtitle: modelData.TailscaleIPs[0] || modelData.DNSName
                        }
                    }
                    Text {
                        visible: TailscaleService.tailnetExitNodes.length === 0
                        width: parent.width
                        topPadding: 70
                        horizontalAlignment: Text.AlignHCenter
                        text: TailscaleService.running
                            ? "No tailnet exit nodes are online."
                            : "Connect Tailscale to choose an exit node."
                        color: Theme.foregroundMuted
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSize
                    }
                }
            }

            Column {
                visible: root.tab === "mullvad"
                anchors.fill: parent
                spacing: 8
                SearchField {
                    placeholder: "Search Mullvad city or country"
                    text: root.mullvadQuery
                    onTextChanged: root.mullvadQuery = text
                }
                Flickable {
                    width: parent.width
                    height: parent.height - y
                    contentWidth: width
                    contentHeight: mullvadColumn.implicitHeight
                    clip: true
                    boundsBehavior: Flickable.StopAtBounds
                    Column {
                        id: mullvadColumn
                        width: parent.width
                        spacing: 7
                        Repeater {
                            model: root.visibleMullvad
                            NodeRow {
                                required property var modelData
                                node: modelData
                                subtitle: modelData.HostName
                            }
                        }
                    }
                }
            }

            Column {
                visible: root.tab === "machines"
                anchors.fill: parent
                spacing: 8
                SearchField {
                    placeholder: "Search machines by name, DNS, or IP"
                    text: root.peerQuery
                    onTextChanged: root.peerQuery = text
                }
                Text {
                    text: root.onlinePeers.length + " ONLINE"
                    color: Theme.accent
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSize - 2
                    font.bold: true
                }
                Flickable {
                    id: machinesFlickable
                    width: parent.width
                    height: parent.height - y
                    contentWidth: width
                    contentHeight: peersColumn.implicitHeight
                    clip: true
                    boundsBehavior: Flickable.StopAtBounds
                    Column {
                        id: peersColumn
                        width: parent.width - (machineScrollBar.visible ? 12 : 0)
                        spacing: 7
                        Repeater {
                            model: root.onlinePeers
                            PeerRow {
                                required property var modelData
                                peer: modelData
                            }
                        }
                        Rectangle {
                            visible: root.offlinePeers.length > 0
                            width: parent.width
                            height: 40
                            radius: Theme.radiusSmall
                            color: offlineMouse.containsMouse ? Theme.gray3 : Theme.gray2
                            border.width: 1
                            border.color: Theme.gray5
                            Text {
                                anchors.left: parent.left
                                anchors.leftMargin: 11
                                anchors.verticalCenter: parent.verticalCenter
                                text: (root.offlineExpanded ? "󰅀  " : "󰅂  ")
                                    + root.offlinePeers.length + " OFFLINE"
                                color: Theme.foregroundMuted
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontSize - 1
                                font.bold: true
                            }
                            MouseArea {
                                id: offlineMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                onClicked: root.offlineExpanded = !root.offlineExpanded
                            }
                        }
                        Repeater {
                            model: root.offlineExpanded ? root.offlinePeers : []
                            PeerRow {
                                required property var modelData
                                peer: modelData
                            }
                        }
                        Text {
                            visible: root.onlinePeers.length === 0
                                && root.offlinePeers.length === 0
                            width: parent.width
                            topPadding: 60
                            horizontalAlignment: Text.AlignHCenter
                            text: root.peerQuery === "" ? "No machines to show."
                                : "No machines match your search."
                            color: Theme.foregroundMuted
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSize
                        }
                    }

                    Controls.ScrollBar.vertical: Controls.ScrollBar {
                        id: machineScrollBar
                        width: 8
                        policy: Controls.ScrollBar.AsNeeded
                        interactive: true

                        background: Rectangle {
                            color: Theme.gray2
                            border.width: 1
                            border.color: Theme.gray5
                            radius: Math.min(width / 2, Theme.radiusSmall)
                        }

                        contentItem: Rectangle {
                            implicitWidth: 6
                            implicitHeight: 28
                            color: machineScrollBar.pressed ? Theme.accent
                                : machineScrollBar.hovered
                                ? Qt.lighter(Theme.accent, 1.2) : Theme.gray6
                            radius: Math.min(width / 2, Theme.radiusSmall)

                            Behavior on color {
                                ColorAnimation { duration: 100 }
                            }
                        }
                    }
                }
            }
        }
    }

    Rectangle {
        id: accountMenu
        visible: root.accountMenuOpen
        z: 110
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.topMargin: 38
        width: 280
        height: accountColumn.implicitHeight + 14
        radius: Theme.radiusMedium
        color: Theme.gray2
        border.width: 1
        border.color: Theme.activeBorder

        Column {
            id: accountColumn
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: 7
            spacing: 4

            Text {
                width: parent.width
                leftPadding: 7
                topPadding: 3
                bottomPadding: 3
                text: TailscaleService.selectedAccountLabel !== ""
                    ? "Current: " + TailscaleService.selectedAccountLabel
                    : "Tailscale accounts"
                color: Theme.foregroundMuted
                elide: Text.ElideRight
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSize - 2
            }

            Repeater {
                model: TailscaleService.accounts
                Rectangle {
                    required property var modelData
                    width: accountColumn.width
                    height: 38
                    radius: Theme.radiusSmall
                    color: modelData.id === TailscaleService.selectedAccountId
                        ? Qt.alpha(Theme.accent, 0.16)
                        : accountMouse.containsMouse ? Theme.gray3 : "transparent"
                    border.width: 1
                    border.color: modelData.id === TailscaleService.selectedAccountId
                        ? Theme.accent : "transparent"
                    Text {
                        anchors.left: parent.left
                        anchors.leftMargin: 8
                        anchors.right: accountState.left
                        anchors.rightMargin: 7
                        anchors.verticalCenter: parent.verticalCenter
                        text: modelData.nickname || modelData.tailnet
                            || modelData.account || modelData.id
                        color: Theme.fg
                        elide: Text.ElideRight
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSize - 1
                    }
                    Text {
                        id: accountState
                        anchors.right: parent.right
                        anchors.rightMargin: 8
                        anchors.verticalCenter: parent.verticalCenter
                        text: modelData.id === TailscaleService.selectedAccountId
                            ? "CURRENT" : "SWITCH"
                        color: Theme.accent
                        font.family: Theme.fontFamily
                        font.pixelSize: Math.max(7, Theme.fontSize - 4)
                        font.bold: true
                    }
                    MouseArea {
                        id: accountMouse
                        anchors.fill: parent
                        enabled: modelData.id !== TailscaleService.selectedAccountId
                            && !TailscaleService.busy
                        hoverEnabled: true
                        onClicked: {
                            root.accountMenuOpen = false
                            TailscaleService.switchAccount(modelData.id)
                        }
                    }
                }
            }

            SmallButton {
                width: accountColumn.width
                label: "Log in to another account"
                icon: "󰐕"
                filled: true
                enabled: !TailscaleService.busy
                onActivated: {
                    root.accountMenuOpen = false
                    TailscaleService.loginNewAccount()
                }
            }
        }
    }

    Rectangle {
        id: copyMenu
        visible: root.copyPeer !== null
        z: 100
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.topMargin: 76
        width: 210
        height: copyOptions.implicitHeight + 14
        radius: Theme.radiusMedium
        color: Theme.gray2
        border.width: 1
        border.color: Theme.activeBorder

        Column {
            id: copyOptions
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: 7
            spacing: 3

            Repeater {
                model: [
                    { label: "Copy IP address", value: root.copyPeer
                        ? root.copyPeer.TailscaleIPs[0] || "" : "" },
                    { label: "Copy machine name", value: root.copyPeer
                        ? root.copyPeer.HostName : "" },
                    { label: "Copy DNS name", value: root.copyPeer
                        ? root.copyPeer.DNSName : "" }
                ]
                Rectangle {
                    required property var modelData
                    width: copyOptions.width
                    height: 32
                    radius: Theme.radiusSmall
                    color: optionMouse.containsMouse ? Theme.gray3 : "transparent"
                    opacity: modelData.value !== "" ? 1 : 0.4
                    Text {
                        anchors.left: parent.left
                        anchors.leftMargin: 8
                        anchors.verticalCenter: parent.verticalCenter
                        text: modelData.label
                        color: Theme.fg
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSize - 1
                    }
                    MouseArea {
                        id: optionMouse
                        anchors.fill: parent
                        enabled: modelData.value !== ""
                        hoverEnabled: true
                        onClicked: {
                            TailscaleService.copy(modelData.value)
                            root.copyPeer = null
                        }
                    }
                }
            }
        }

        SmallButton {
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.rightMargin: 7
            anchors.topMargin: -34
            label: "Close"
            onActivated: root.copyPeer = null
        }
    }
}
