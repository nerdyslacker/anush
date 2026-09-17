pragma ComponentBehavior: Bound

import QtQuick
import "../.."
import QtQuick.Controls as Controls
import Quickshell.Io
import Quickshell.Networking as QsNetwork

// Dedicated NetworkManager quick controls. Device and access-point state is
// native/reactive; VPN profiles are presented as a distinct section.
Popout {
    id: root

    cardWidth: 430
    cardHeight: 620
    property var passwordNetwork: null
    property string expandedWifi: ""

    onVisibleChanged: {
        if (visible) {
            PopupCoordinator.requestOpen("network", root)
            NetworkService.setPopupActive(true)
            NetworkService.error = ""
        } else {
            NetworkService.setPopupActive(false)
            passwordNetwork = null
            expandedWifi = ""
        }
    }

    Connections {
        target: PopupCoordinator
        function onOpening(name, owner) {
            if (owner !== root) root.visible = false
        }
    }

    IpcHandler {
        target: "network"
        function toggle(): void { root.visible = !root.visible }
        function open(): void { root.visible = true }
        function close(): void { root.visible = false }
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
        color: filled ? accentColor : mouse.containsMouse
            ? Qt.alpha(accentColor, 0.24) : Qt.alpha(accentColor, 0.12)
        border.width: 1
        border.color: accentColor
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
        Rectangle {
            x: pill.checked ? parent.width - width - 3 : 3
            anchors.verticalCenter: parent.verticalCenter
            width: 14
            height: 14
            radius: Math.min(width / 2, Theme.radiusSmall)
            color: pill.checked ? Theme.bg : Qt.alpha(Theme.fg, 0.7)
            Behavior on x { NumberAnimation { duration: 140 } }
        }
        MouseArea { anchors.fill: parent; onClicked: pill.toggled() }
    }

    function signalGlyph(strength) {
        return strength < 0.2 ? "󰤯" : strength < 0.45 ? "󰤟"
            : strength < 0.7 ? "󰤢" : strength < 0.88 ? "󰤥" : "󰤨"
    }

    function activate(network) {
        if (network.connected || network.known
                || network.security === QsNetwork.WifiSecurityType.Open) {
            passwordNetwork = null
            NetworkService.activateNetwork(network, "")
        } else {
            passwordNetwork = network
        }
    }

    Column {
        anchors.fill: parent
        spacing: 8
        focus: true
        Keys.onEscapePressed: {
            if (root.passwordNetwork)
                root.passwordNetwork = null
            else
                root.visible = false
        }

        Row {
            width: parent.width
            height: 30
            Text {
                width: parent.width - wifiSwitch.width
                anchors.verticalCenter: parent.verticalCenter
                text: "Network"
                color: Theme.fg
                font.family: Theme.fontFamily
                font.pixelSize: 16
                font.bold: true
            }
            SwitchPill {
                id: wifiSwitch
                anchors.verticalCenter: parent.verticalCenter
                checked: NetworkService.wifiEnabled
                enabled: NetworkService.wifiHardwareEnabled
                opacity: enabled ? 1 : 0.45
                onToggled: NetworkService.toggleWifi()
            }
        }

        Rectangle {
            visible: !NetworkService.available
            width: parent.width
            height: 70
            radius: Theme.radiusMedium
            color: Theme.gray2
            Text {
                anchors.centerIn: parent
                width: parent.width - 20
                horizontalAlignment: Text.AlignHCenter
                text: "NetworkManager is unavailable"
                color: Theme.disabled
                font.family: Theme.fontFamily
                font.pixelSize: 12
            }
        }

        Text {
            visible: NetworkService.available
            width: parent.width
            text: NetworkService.online
                ? "Connected to " + NetworkService.primaryName : "Offline"
            color: NetworkService.online ? Theme.green : Theme.red
            font.family: Theme.fontFamily
            font.pixelSize: 11
            elide: Text.ElideRight
        }

        Repeater {
            model: NetworkService.wiredDevices
            Rectangle {
                id: wiredRow
                required property var modelData
                width: parent.width
                height: 42
                radius: Theme.radiusSmall
                color: modelData.connected ? Qt.alpha(Theme.green, 0.12) : Theme.gray2
                border.width: 1
                border.color: Theme.gray5
                Row {
                    anchors.left: parent.left
                    anchors.leftMargin: 10
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 7
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "󰈀"
                        color: Theme.fg
                        font.family: Theme.iconFontFamily
                        font.pixelSize: Theme.iconSize
                    }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: wiredRow.modelData.name
                        color: Theme.fg
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSize
                    }
                }
                Text {
                    anchors.right: parent.right
                    anchors.rightMargin: 10
                    anchors.verticalCenter: parent.verticalCenter
                    text: wiredRow.modelData.connected
                        ? (wiredRow.modelData.network?.name ?? "connected")
                        : wiredRow.modelData.hasLink ? "available" : "unplugged"
                    color: wiredRow.modelData.connected ? Theme.green : Theme.disabled
                    font.family: Theme.fontFamily
                    font.pixelSize: 10
                }
            }
        }

        Row {
            visible: NetworkService.wifiDevices.length > 0
            width: parent.width
            height: 28
            Text {
                width: parent.width - rescan.width - 8
                anchors.verticalCenter: parent.verticalCenter
                text: NetworkService.wifiHardwareEnabled ? "Wi-Fi" : "Wi-Fi · hardware blocked"
                color: Theme.accent
                font.family: Theme.fontFamily
                font.pixelSize: 12
                font.bold: true
            }
            SmallButton {
                id: rescan
                anchors.verticalCenter: parent.verticalCenter
                buttonText: "Rescan"
                enabled: NetworkService.wifiEnabled
                opacity: enabled ? 1 : 0.45
                onActivated: NetworkService.rescanWifi()
            }
        }

        Rectangle {
            visible: NetworkService.wifiDevices.length > 0
                && !NetworkService.wifiEnabled
            width: parent.width
            height: 54
            radius: Theme.radiusMedium
            color: Theme.gray2
            Text {
                anchors.centerIn: parent
                text: "Wi-Fi is disabled"
                color: Theme.disabled
                font.family: Theme.fontFamily
                font.pixelSize: 11
            }
        }

        Flickable {
            visible: NetworkService.wifiEnabled
                && NetworkService.wifiDevices.length > 0
            width: parent.width
            height: Math.min(wifiList.implicitHeight,
                NetworkService.vpns.length > 0 ? 240 : 320)
            contentWidth: width
            contentHeight: wifiList.implicitHeight
            clip: true
            boundsBehavior: Flickable.StopAtBounds

            Column {
                id: wifiList
                width: parent.width
                spacing: 4

                Repeater {
                    model: NetworkService.wifiNetworks
                    Rectangle {
                        id: networkRow
                        required property var modelData
                        readonly property bool expanded:
                            root.expandedWifi === modelData.name
                        readonly property bool asking:
                            root.passwordNetwork === modelData
                        width: wifiList.width
                        height: 34 + (expanded ? 40 : 0) + (asking ? 38 : 0)
                        radius: Theme.radiusSmall
                        clip: true
                        color: Theme.gray2
                        Behavior on height {
                            NumberAnimation { duration: 140; easing.type: Easing.OutCubic }
                        }

                        Connections {
                            target: networkRow.modelData
                            function onConnectionFailed(reason) {
                                NetworkService.reportConnectionFailure(reason)
                            }
                        }
                        Column {
                            anchors.fill: parent
                            spacing: 0

                            Rectangle {
                                width: parent.width
                                height: 34
                                radius: Theme.radiusSmall
                                color: networkRow.modelData.connected
                                    ? Qt.alpha(Theme.accent, 0.22)
                                    : networkMouse.containsMouse ? Theme.gray3 : Theme.gray2

                                Row {
                                    anchors.left: parent.left
                                    anchors.leftMargin: 10
                                    anchors.right: networkTag.left
                                    anchors.rightMargin: 8
                                    anchors.verticalCenter: parent.verticalCenter
                                    spacing: 7
                                    Text {
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: root.signalGlyph(networkRow.modelData.signalStrength)
                                        color: networkRow.modelData.connected
                                            ? Theme.accent : Theme.fg
                                        font.family: Theme.iconFontFamily
                                        font.pixelSize: Theme.iconSize
                                    }
                                    Text {
                                        width: parent.width - x
                                            - (connectedIcon.visible
                                                ? connectedIcon.width + parent.spacing : 0)
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: networkRow.modelData.name
                                        color: networkRow.modelData.connected
                                            ? Theme.accent : Theme.fg
                                        font.family: Theme.fontFamily
                                        font.pixelSize: Theme.fontSize
                                        font.bold: networkRow.modelData.connected
                                        elide: Text.ElideRight
                                    }
                                    Text {
                                        id: connectedIcon
                                        visible: networkRow.modelData.connected
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: "󰄬"
                                        color: Theme.accent
                                        font.family: Theme.iconFontFamily
                                        font.pixelSize: Theme.iconSizeSmall
                                    }
                                }
                                Row {
                                    id: networkTag
                                    anchors.right: parent.right
                                    anchors.rightMargin: 10
                                    anchors.verticalCenter: parent.verticalCenter
                                    spacing: 5
                                    Text {
                                        visible: networkRow.modelData.known
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: "saved"
                                        color: Theme.disabled
                                        font.family: Theme.fontFamily
                                        font.pixelSize: Theme.fontSize - 2
                                    }
                                    Text {
                                        visible: networkRow.modelData.security
                                            !== QsNetwork.WifiSecurityType.Open
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: "󰌾"
                                        color: Theme.disabled
                                        font.family: Theme.iconFontFamily
                                        font.pixelSize: Theme.iconSizeSmall
                                    }
                                    Text {
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: networkRow.expanded ? "󰅀" : "󰅂"
                                        color: Theme.disabled
                                        font.family: Theme.iconFontFamily
                                        font.pixelSize: Theme.iconSizeSmall
                                    }
                                }
                                MouseArea {
                                    id: networkMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    onClicked: {
                                        if (networkRow.expanded) {
                                            root.expandedWifi = ""
                                            if (networkRow.asking)
                                                root.passwordNetwork = null
                                        } else {
                                            root.expandedWifi = networkRow.modelData.name
                                            root.passwordNetwork = null
                                        }
                                    }
                                }
                            }

                            Item {
                                width: parent.width
                                height: 40
                                SmallButton {
                                    anchors.right: parent.right
                                    anchors.rightMargin: 5
                                    anchors.verticalCenter: parent.verticalCenter
                                    buttonText: networkRow.modelData.stateChanging
                                        ? QsNetwork.ConnectionState.toString(
                                            networkRow.modelData.state) + "…"
                                        : networkRow.modelData.connected
                                        ? "Disconnect" : "Connect"
                                    accentColor: networkRow.modelData.connected
                                        ? Theme.brightOrange : Theme.green
                                    filled: true
                                    enabled: !NetworkService.busy
                                        && !networkRow.modelData.stateChanging
                                    opacity: enabled ? 1 : 0.45
                                    onActivated: root.activate(networkRow.modelData)
                                }
                            }

                            Item {
                                visible: networkRow.asking
                                width: parent.width
                                height: visible ? 38 : 0
                                Rectangle {
                                    anchors.fill: parent
                                    anchors.margins: 4
                                    radius: Theme.radiusSmall
                                    color: Qt.alpha(Theme.fg, 0.08)
                                    TextInput {
                                        id: passwordInput
                                        anchors.left: parent.left
                                        anchors.right: joinButton.left
                                        anchors.leftMargin: 10
                                        anchors.rightMargin: 6
                                        anchors.verticalCenter: parent.verticalCenter
                                        echoMode: TextInput.Password
                                        color: Theme.fg
                                        font.family: Theme.fontFamily
                                        font.pixelSize: 12
                                        focus: networkRow.asking
                                        onAccepted: joinButton.activated()
                                        Text {
                                            visible: passwordInput.text === ""
                                            text: "password"
                                            color: Theme.disabled
                                            font: passwordInput.font
                                        }
                                    }
                                    SmallButton {
                                        id: joinButton
                                        anchors.right: parent.right
                                        anchors.rightMargin: 4
                                        anchors.verticalCenter: parent.verticalCenter
                                        buttonText: "Join"
                                        filled: true
                                        enabled: passwordInput.text.length > 0
                                            && !NetworkService.busy
                                        opacity: enabled ? 1 : 0.45
                                        onActivated: {
                                            if (passwordInput.text.length === 0)
                                                return
                                            NetworkService.activateNetwork(
                                                networkRow.modelData, passwordInput.text)
                                            passwordInput.text = ""
                                            root.passwordNetwork = null
                                        }
                                    }
                                }
                            }
                        }

                        Rectangle {
                            anchors.fill: parent
                            radius: Theme.radiusSmall
                            z: 2
                            color: "transparent"
                            border.width: 1
                            border.color: networkRow.expanded
                                || networkRow.modelData.connected
                                ? Theme.accent : Theme.gray5
                        }
                    }
                }

                Text {
                    visible: NetworkService.wifiNetworks.length === 0
                    width: parent.width
                    topPadding: 16
                    horizontalAlignment: Text.AlignHCenter
                    text: "Scanning for Wi-Fi networks…"
                    color: Theme.disabled
                    font.family: Theme.fontFamily
                    font.pixelSize: 11
                }
            }

            Controls.ScrollBar.vertical: Controls.ScrollBar {
                policy: parent.contentHeight > parent.height + 0.5
                    ? Controls.ScrollBar.AlwaysOn : Controls.ScrollBar.AlwaysOff
            }
        }

        Rectangle { width: parent.width; height: 1; color: Qt.alpha(Theme.fg, 0.1) }

        Text {
            text: "VPN"
            color: Theme.accent
            font.family: Theme.fontFamily
            font.pixelSize: 12
            font.bold: true
        }

        Text {
            visible: NetworkService.loadingVpns
            text: "Loading VPN connections…"
            color: Theme.disabled
            font.family: Theme.fontFamily
            font.pixelSize: 10
        }

        Flickable {
            visible: NetworkService.vpns.length > 0
            width: parent.width
            height: Math.min(vpnList.implicitHeight, 130)
            contentWidth: width
            contentHeight: vpnList.implicitHeight
            clip: true
            boundsBehavior: Flickable.StopAtBounds

            Column {
                id: vpnList
                width: parent.width
                spacing: 4

                Repeater {
                    model: NetworkService.vpns
                    Rectangle {
                        id: vpnRow
                        required property var modelData
                        width: vpnList.width
                        height: 38
                        radius: Theme.radiusSmall
                        color: modelData.active ? Qt.alpha(Theme.green, 0.13) : Theme.gray2
                        border.width: 1
                        border.color: Theme.gray5
                        Row {
                            anchors.left: parent.left
                            anchors.leftMargin: 10
                            anchors.right: vpnToggle.visible
                                ? vpnToggle.left : vpnExternal.left
                            anchors.rightMargin: 8
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 7
                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: "󰦝"
                                color: vpnRow.modelData.active ? Theme.green : Theme.fg
                                font.family: Theme.iconFontFamily
                                font.pixelSize: Theme.iconSize
                            }
                            Text {
                                width: parent.width - x
                                anchors.verticalCenter: parent.verticalCenter
                                text: vpnRow.modelData.name
                                color: vpnRow.modelData.active ? Theme.green : Theme.fg
                                elide: Text.ElideRight
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontSize - 1
                            }
                        }
                        Text {
                            id: vpnExternal
                            visible: vpnRow.modelData.external
                            anchors.right: parent.right
                            anchors.rightMargin: 10
                            anchors.verticalCenter: parent.verticalCenter
                            text: vpnRow.modelData.active
                                ? "active · external" : "external"
                            color: vpnRow.modelData.active ? Theme.green : Theme.accent
                            font.family: Theme.fontFamily
                            font.pixelSize: 10
                        }
                        SwitchPill {
                            id: vpnToggle
                            visible: !vpnRow.modelData.external
                            anchors.right: parent.right
                            anchors.rightMargin: 10
                            anchors.verticalCenter: parent.verticalCenter
                            checked: vpnRow.modelData.active
                            enabled: !NetworkService.busy
                            opacity: enabled ? 1 : 0.45
                            onToggled: NetworkService.toggleVpn(vpnRow.modelData)
                        }
                    }
                }
            }
        }

        Text {
            visible: !NetworkService.loadingVpns && NetworkService.vpns.length === 0
            text: NetworkService.vpnError !== "" ? NetworkService.vpnError
                : "No VPN profiles configured"
            color: NetworkService.vpnError !== "" ? Theme.red : Theme.disabled
            font.family: Theme.fontFamily
            font.pixelSize: 10
        }

        Text {
            visible: NetworkService.error !== "" || NetworkService.status !== ""
            width: parent.width
            text: NetworkService.error !== "" ? NetworkService.error : NetworkService.status
            color: NetworkService.error !== "" ? Theme.red : Theme.green
            elide: Text.ElideRight
            font.family: Theme.fontFamily
            font.pixelSize: 10
        }
    }
}
