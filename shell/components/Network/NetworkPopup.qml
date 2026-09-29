pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Dialogs
import "../.."
import QtQuick.Controls as Controls
import Quickshell.Networking as QsNetwork

// Dedicated NetworkManager quick controls. Device and access-point state is
// native/reactive; VPN profiles are presented as a distinct section.
Popout {
    id: root

    cardWidth: 430
    cardHeight: 620
    property var passwordNetwork: null
    property string expandedWifi: ""
    property bool vpnChooserOpen: false
    property bool vpnEditorOpen: false
    property bool restoreVpnEditor: false
    property string selectedVpnType: ""
    property string editingVpnUuid: ""
    property string expandedVpn: ""
    property string pendingVpnRemoval: ""
    property string certificateTarget: ""
    property bool fortiSaml: false

    readonly property var vpnTypes: [
        { key: "openconnect", name: "Cisco AnyConnect / OpenConnect",
            detail: "AnyConnect-compatible gateway" },
        { key: "l2tp", name: "L2TP / IPsec",
            detail: "Username, password and pre-shared key" },
        { key: "fortisslvpn", name: "FortiVPN",
            detail: "Fortinet SSL VPN with password or browser SSO" },
        { key: "openvpn", name: "OpenVPN",
            detail: "Enter a server or import an .ovpn file" },
        { key: "openvpn3", name: "OpenVPN 3",
            detail: "Import an .ovpn profile for OpenVPN 3" }
    ]

    onVisibleChanged: {
        if (visible) {
            PopupCoordinator.requestOpen("network", root)
            NetworkService.setPopupActive(true)
            NetworkService.error = ""
        } else {
            NetworkService.setPopupActive(false)
            passwordNetwork = null
            expandedWifi = ""
            expandedVpn = ""
            pendingVpnRemoval = ""
            vpnChooserOpen = false
            vpnEditorOpen = false
            if (!restoreVpnEditor)
                editingVpnUuid = ""
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
        function onNetworkRequested(action) {
            if (!ShellActions.ownsFocusedOutput(root.anchorItem)) return
            if (action === "toggle") root.visible = !root.visible
            else if (action === "open") root.visible = true
            else if (action === "close") root.visible = false
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

    component FormField: Rectangle {
        id: formField
        required property string placeholder
        property bool secret: false
        property alias text: fieldInput.text
        property alias validator: fieldInput.validator
        width: parent ? parent.width : 0
        height: 38
        radius: Theme.radiusSmall
        color: Theme.gray2
        border.width: 1
        border.color: fieldInput.activeFocus ? Theme.accent : Theme.gray5

        TextInput {
            id: fieldInput
            anchors.fill: parent
            anchors.leftMargin: 10
            anchors.rightMargin: 10
            verticalAlignment: TextInput.AlignVCenter
            color: Theme.fg
            selectionColor: Theme.accent
            selectedTextColor: Theme.bg
            echoMode: formField.secret ? TextInput.Password : TextInput.Normal
            font.family: Theme.fontFamily
            font.pixelSize: 12
            clip: true
            Text {
                visible: fieldInput.text === ""
                anchors.verticalCenter: parent.verticalCenter
                text: formField.placeholder
                color: Theme.disabled
                font: fieldInput.font
            }
        }
    }

    component BrowseField: Row {
        id: browseField
        required property string placeholder
        property alias text: browseInput.text
        signal browseRequested()
        width: parent ? parent.width : 0
        height: 38
        spacing: 6
        FormField {
            id: browseInput
            width: parent.width - browseButton.width - parent.spacing
            placeholder: browseField.placeholder
        }
        SmallButton {
            id: browseButton
            anchors.verticalCenter: parent.verticalCenter
            buttonText: "Browse…"
            onActivated: browseField.browseRequested()
        }
    }

    function vpnTypeName(key) {
        const item = vpnTypes.find(type => type.key === key)
        return item ? item.name : "VPN"
    }

    function editVpn(key) {
        editingVpnUuid = ""
        selectedVpnType = key
        vpnChooserOpen = false
        vpnEditorOpen = true
        vpnNameField.text = ""
        vpnImportNameField.text = ""
        vpnGatewayField.text = ""
        vpnUsernameField.text = ""
        vpnPasswordField.text = ""
        vpnPskField.text = ""
        vpnCaField.text = ""
        vpnClientCertField.text = ""
        vpnPrivateKeyField.text = ""
        vpnSamlPortField.text = "8020"
        fortiSaml = false
    }

    function editExistingVpn(vpn) {
        if (!vpn || vpn.active || vpn.external)
            return
        if (vpn.editable !== true || !vpn.kind) {
            NetworkService.editVpnExternally(vpn.uuid || "")
            return
        }
        editingVpnUuid = vpn.uuid || ""
        selectedVpnType = vpn.kind || ""
        vpnChooserOpen = false
        vpnEditorOpen = true
        vpnNameField.text = vpn.name || ""
        vpnImportNameField.text = ""
        vpnGatewayField.text = vpn.gateway || ""
        vpnUsernameField.text = vpn.username || ""
        vpnPasswordField.text = ""
        vpnPskField.text = ""
        vpnCaField.text = vpn.caCert || ""
        vpnClientCertField.text = vpn.clientCert || ""
        vpnPrivateKeyField.text = vpn.privateKey || ""
        vpnSamlPortField.text = vpn.samlPort || "8020"
        fortiSaml = vpn.saml === true
    }

    function saveVpn() {
        if (selectedVpnType === "openvpn3")
            return
        NetworkService.createVpn({
            uuid: editingVpnUuid,
            type: selectedVpnType,
            name: vpnNameField.text.trim(),
            gateway: vpnGatewayField.text.trim(),
            username: vpnUsernameField.text.trim(),
            password: vpnPasswordField.text,
            psk: vpnPskField.text,
            caCert: vpnCaField.text.trim(),
            clientCert: vpnClientCertField.text.trim(),
            privateKey: vpnPrivateKeyField.text.trim(),
            saml: fortiSaml,
            samlPort: vpnSamlPortField.text.trim()
        })
        vpnPasswordField.text = ""
        vpnPskField.text = ""
    }

    function openVpnImport() {
        restoreVpnEditor = true
        visible = false
        vpnConfigDialog.open()
    }

    function vpnKey(vpn) {
        return vpn.configPath || vpn.uuid || vpn.name || ""
    }

    function toggleVpnExpanded(vpn) {
        if (!vpn || vpn.external)
            return
        const key = vpnKey(vpn)
        expandedVpn = expandedVpn === key ? "" : key
        pendingVpnRemoval = ""
    }

    function requestVpnRemoval(vpn) {
        const key = vpnKey(vpn)
        if (pendingVpnRemoval !== key) {
            pendingVpnRemoval = key
            return
        }
        pendingVpnRemoval = ""
        expandedVpn = ""
        NetworkService.removeVpn(vpn)
    }

    FileDialog {
        id: vpnConfigDialog
        title: root.selectedVpnType === "openvpn3"
            ? "Import OpenVPN 3 configuration" : "Import OpenVPN configuration"
        modality: Qt.ApplicationModal
        nameFilters: ["OpenVPN configurations (*.ovpn *.conf)", "All files (*)"]
        onAccepted: NetworkService.importVpn(root.selectedVpnType, selectedFile,
            vpnImportNameField.text.trim())
        onVisibleChanged: if (!visible && root.restoreVpnEditor) {
            root.restoreVpnEditor = false
            root.showAtAnchor()
            root.vpnEditorOpen = true
        }
    }

    FileDialog {
        id: certificateDialog
        title: root.certificateTarget === "privateKey"
            ? "Choose private key" : "Choose certificate"
        modality: Qt.ApplicationModal
        nameFilters: [
            "Certificates and keys (*.pem *.crt *.cer *.key *.p12 *.pfx)",
            "All files (*)"
        ]
        onAccepted: {
            const path = decodeURIComponent(String(selectedFile).replace(/^file:\/\//, ""))
            if (root.certificateTarget === "ca") vpnCaField.text = path
            else if (root.certificateTarget === "client") vpnClientCertField.text = path
            else if (root.certificateTarget === "privateKey") vpnPrivateKeyField.text = path
        }
        onVisibleChanged: if (!visible && root.restoreVpnEditor) {
            root.restoreVpnEditor = false
            root.showAtAnchor()
            root.vpnEditorOpen = true
        }
    }

    function browseCertificate(target) {
        certificateTarget = target
        restoreVpnEditor = true
        visible = false
        certificateDialog.open()
    }

    Connections {
        target: NetworkService
        function onVpnProfileCreated() {
            root.vpnEditorOpen = false
            root.vpnChooserOpen = false
            root.editingVpnUuid = ""
        }
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
            if (root.vpnEditorOpen) {
                root.vpnEditorOpen = false
                root.vpnChooserOpen = root.editingVpnUuid === ""
                root.editingVpnUuid = ""
            } else if (root.vpnChooserOpen) {
                root.vpnChooserOpen = false
            } else if (root.passwordNetwork)
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
                    width: parent.width - 14
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
                id: wifiScrollBar
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
                    color: wifiScrollBar.pressed ? Theme.brightOrange
                         : wifiScrollBar.hovered ? Theme.orange : Theme.gray6
                    radius: Math.min(width / 2, Theme.radiusSmall)

                    Behavior on color { ColorAnimation { duration: 100 } }
                }
            }
        }

        Rectangle { width: parent.width; height: 1; color: Qt.alpha(Theme.fg, 0.1) }

        Row {
            width: parent.width
            height: 28
            Text {
                width: parent.width - addVpnButton.width - 8
                anchors.verticalCenter: parent.verticalCenter
                text: "VPN"
                color: Theme.accent
                font.family: Theme.fontFamily
                font.pixelSize: 12
                font.bold: true
            }
            SmallButton {
                id: addVpnButton
                anchors.verticalCenter: parent.verticalCenter
                buttonText: "Add"
                enabled: !NetworkService.busy
                onActivated: {
                    root.vpnEditorOpen = false
                    root.vpnChooserOpen = !root.vpnChooserOpen
                }
            }
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
                width: parent.width - 14
                spacing: 4

                Repeater {
                    model: NetworkService.vpns
                    Rectangle {
                        id: vpnRow
                        required property var modelData
                        readonly property bool expanded:
                            root.expandedVpn === root.vpnKey(modelData)
                        width: vpnList.width
                        height: 38 + (expanded ? 40 : 0)
                        radius: Theme.radiusSmall
                        clip: true
                        color: modelData.active ? Qt.alpha(Theme.green, 0.13) : Theme.gray2
                        border.width: 1
                        border.color: expanded ? Theme.accent : Theme.gray5
                        Behavior on height {
                            NumberAnimation { duration: 140; easing.type: Easing.OutCubic }
                        }

                        Column {
                            anchors.fill: parent

                            Rectangle {
                                width: parent.width
                                height: 38
                                radius: Theme.radiusSmall
                                color: vpnRow.modelData.active
                                    ? Qt.alpha(Theme.green, 0.13)
                                    : vpnHeaderMouse.containsMouse ? Theme.gray3 : "transparent"
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
                                        width: parent.width - x - expandIcon.width - parent.spacing
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: vpnRow.modelData.name
                                        color: vpnRow.modelData.active ? Theme.green : Theme.fg
                                        elide: Text.ElideRight
                                        font.family: Theme.fontFamily
                                        font.pixelSize: Theme.fontSize - 1
                                    }
                                    Text {
                                        id: expandIcon
                                        visible: !vpnRow.modelData.external
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: vpnRow.expanded ? "󰅀" : "󰅂"
                                        color: Theme.disabled
                                        font.family: Theme.iconFontFamily
                                        font.pixelSize: Theme.iconSizeSmall
                                    }
                                }
                                MouseArea {
                                    id: vpnHeaderMouse
                                    anchors.fill: parent
                                    enabled: !vpnRow.modelData.external
                                    hoverEnabled: true
                                    onClicked: root.toggleVpnExpanded(vpnRow.modelData)
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
                                    z: 2
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
                                    z: 2
                                    onToggled: NetworkService.toggleVpn(vpnRow.modelData)
                                }
                            }

                            Item {
                                width: parent.width
                                height: 40
                                Row {
                                    anchors.right: parent.right
                                    anchors.rightMargin: 5
                                    anchors.verticalCenter: parent.verticalCenter
                                    spacing: 6
                                    SmallButton {
                                        visible: !vpnRow.modelData.external
                                            && vpnRow.modelData.engine !== "openvpn3"
                                        buttonText: "Edit"
                                        enabled: !NetworkService.busy
                                            && !vpnRow.modelData.active
                                        opacity: enabled ? 1 : 0.45
                                        onActivated: root.editExistingVpn(vpnRow.modelData)
                                    }
                                    SmallButton {
                                        visible: !vpnRow.modelData.external
                                        buttonText: root.pendingVpnRemoval
                                            === root.vpnKey(vpnRow.modelData)
                                            ? "Confirm remove" : "Remove"
                                        accentColor: Theme.red
                                        enabled: !NetworkService.busy
                                            && !vpnRow.modelData.active
                                        opacity: enabled ? 1 : 0.45
                                        onActivated: root.requestVpnRemoval(vpnRow.modelData)
                                    }
                                }
                            }
                        }
                    }
                }
            }

            Controls.ScrollBar.vertical: Controls.ScrollBar {
                id: vpnScrollBar
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
                    color: vpnScrollBar.pressed ? Theme.brightOrange
                         : vpnScrollBar.hovered ? Theme.orange : Theme.gray6
                    radius: Math.min(width / 2, Theme.radiusSmall)
                    Behavior on color { ColorAnimation { duration: 100 } }
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

    Rectangle {
        id: vpnOverlay
        anchors.fill: parent
        z: 20
        visible: root.vpnChooserOpen || root.vpnEditorOpen
        radius: Theme.radiusMedium
        color: Theme.bg
        border.width: 1
        border.color: Theme.gray5

        Column {
            anchors.fill: parent
            anchors.margins: 12
            spacing: 8

            Row {
                width: parent.width
                height: 30
                SmallButton {
                    anchors.verticalCenter: parent.verticalCenter
                    buttonText: root.vpnEditorOpen
                        && root.editingVpnUuid !== "" ? "Cancel"
                        : root.vpnEditorOpen ? "Back" : "Close"
                    onActivated: {
                        if (root.vpnEditorOpen) {
                            root.vpnEditorOpen = false
                            root.vpnChooserOpen = root.editingVpnUuid === ""
                            root.editingVpnUuid = ""
                        } else {
                            root.vpnChooserOpen = false
                        }
                    }
                }
                Text {
                    width: parent.width - x
                    anchors.verticalCenter: parent.verticalCenter
                    horizontalAlignment: Text.AlignHCenter
                    text: root.vpnEditorOpen
                        ? (root.editingVpnUuid !== "" ? "Edit " : "Add ")
                            + root.vpnTypeName(root.selectedVpnType)
                        : "Add VPN connection"
                    color: Theme.fg
                    font.family: Theme.fontFamily
                    font.pixelSize: 15
                    font.bold: true
                }
            }

            Column {
                visible: root.vpnChooserOpen
                width: parent.width
                spacing: 6

                Text {
                    width: parent.width
                    text: "Choose the VPN implementation to configure"
                    color: Theme.disabled
                    font.family: Theme.fontFamily
                    font.pixelSize: 11
                }

                Repeater {
                    model: root.vpnTypes
                    Rectangle {
                        id: vpnTypeRow
                        required property var modelData
                        width: parent.width
                        height: 58
                        radius: Theme.radiusSmall
                        color: typeMouse.containsMouse ? Theme.gray3 : Theme.gray2
                        border.width: 1
                        border.color: Theme.gray5
                        Column {
                            anchors.left: parent.left
                            anchors.right: arrow.left
                            anchors.leftMargin: 12
                            anchors.rightMargin: 8
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 3
                            Text {
                                text: vpnTypeRow.modelData.name
                                color: Theme.fg
                                font.family: Theme.fontFamily
                                font.pixelSize: 12
                                font.bold: true
                            }
                            Text {
                                width: parent.width
                                text: vpnTypeRow.modelData.detail
                                color: Theme.disabled
                                font.family: Theme.fontFamily
                                font.pixelSize: 10
                                elide: Text.ElideRight
                            }
                        }
                        Text {
                            id: arrow
                            anchors.right: parent.right
                            anchors.rightMargin: 12
                            anchors.verticalCenter: parent.verticalCenter
                            text: "󰅂"
                            color: Theme.accent
                            font.family: Theme.iconFontFamily
                            font.pixelSize: Theme.iconSizeSmall
                        }
                        MouseArea {
                            id: typeMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            onClicked: root.editVpn(vpnTypeRow.modelData.key)
                        }
                    }
                }
            }

            Flickable {
                visible: root.vpnEditorOpen
                width: parent.width
                height: parent.height - y
                contentWidth: width
                contentHeight: vpnForm.implicitHeight
                clip: true
                boundsBehavior: Flickable.StopAtBounds

                Column {
                    id: vpnForm
                    width: parent.width
                    spacing: 8

                    Text {
                        width: parent.width
                        text: root.selectedVpnType === "openvpn3"
                            ? "OpenVPN 3 profiles are created by importing a configuration file."
                            : root.selectedVpnType === "openconnect"
                            ? "NetworkManager will request AnyConnect credentials when the profile connects."
                            : root.selectedVpnType === "fortisslvpn"
                            ? "openfortivpn requests credentials in a terminal. Enable browser login for SAML gateways."
                            : "Enter connection details, or import a configuration when available."
                        color: Theme.disabled
                        font.family: Theme.fontFamily
                        font.pixelSize: 11
                        wrapMode: Text.WordWrap
                    }

                    FormField {
                        id: vpnImportNameField
                        visible: (root.selectedVpnType === "openvpn"
                            || root.selectedVpnType === "openvpn3")
                            && root.editingVpnUuid === ""
                        width: parent.width
                        placeholder: "Imported connection name (optional)"
                    }

                    SmallButton {
                        visible: (root.selectedVpnType === "openvpn"
                            && root.editingVpnUuid === "")
                            || root.selectedVpnType === "openvpn3"
                        buttonText: "Import configuration…"
                        filled: true
                        enabled: !NetworkService.busy
                        onActivated: root.openVpnImport()
                    }

                    Rectangle {
                        visible: (root.selectedVpnType === "openvpn"
                            || root.selectedVpnType === "openvpn3")
                            && root.selectedVpnType !== "openvpn3"
                        width: parent.width
                        height: 1
                        color: Qt.alpha(Theme.fg, 0.1)
                    }

                    FormField {
                        id: vpnNameField
                        visible: root.selectedVpnType !== "openvpn3"
                        width: parent.width
                        placeholder: "Connection name"
                    }
                    FormField {
                        id: vpnGatewayField
                        visible: root.selectedVpnType !== "openvpn3"
                        width: parent.width
                        placeholder: root.selectedVpnType === "openvpn"
                            ? "VPN server (host or host:port)" : "Server / gateway"
                    }
                    FormField {
                        id: vpnUsernameField
                        visible: root.selectedVpnType !== "openvpn3"
                        width: parent.width
                        placeholder: "Username (optional)"
                    }
                    FormField {
                        id: vpnPasswordField
                        visible: root.selectedVpnType === "l2tp"
                            || root.selectedVpnType === "openvpn"
                        width: parent.width
                        placeholder: root.editingVpnUuid !== ""
                            ? "New password (blank keeps current)"
                            : "Password (optional)"
                        secret: true
                    }

                    Row {
                        visible: root.selectedVpnType === "fortisslvpn"
                        width: parent.width
                        height: 30
                        spacing: 8
                        SwitchPill {
                            anchors.verticalCenter: parent.verticalCenter
                            checked: root.fortiSaml
                            onToggled: root.fortiSaml = !root.fortiSaml
                        }
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: "Login via browser (SAML SSO)"
                            color: Theme.fg
                            font.family: Theme.fontFamily
                            font.pixelSize: 11
                        }
                    }
                    FormField {
                        id: vpnSamlPortField
                        visible: root.selectedVpnType === "fortisslvpn"
                            && root.fortiSaml
                        width: parent.width
                        placeholder: "SAML callback port (default 8020)"
                        validator: IntValidator { bottom: 1; top: 65535 }
                    }
                    Text {
                        visible: root.selectedVpnType === "fortisslvpn"
                            && root.fortiSaml
                        width: parent.width
                        text: "Connect opens the gateway sign-in in your default browser. "
                            + "Keep the terminal open while the VPN is active."
                        color: Theme.disabled
                        font.family: Theme.fontFamily
                        font.pixelSize: 10
                        wrapMode: Text.WordWrap
                    }

                    Text {
                        visible: root.selectedVpnType === "openvpn"
                            || root.selectedVpnType === "openconnect"
                            || root.selectedVpnType === "fortisslvpn"
                        width: parent.width
                        text: "Certificates (optional)"
                        color: Theme.accent
                        font.family: Theme.fontFamily
                        font.pixelSize: 11
                        font.bold: true
                    }
                    BrowseField {
                        id: vpnCaField
                        visible: root.selectedVpnType === "openvpn"
                            || root.selectedVpnType === "openconnect"
                        width: parent.width
                        placeholder: "CA certificate"
                        onBrowseRequested: root.browseCertificate("ca")
                    }
                    BrowseField {
                        id: vpnClientCertField
                        visible: root.selectedVpnType === "openvpn"
                            || root.selectedVpnType === "openconnect"
                            || root.selectedVpnType === "fortisslvpn"
                        width: parent.width
                        placeholder: "Client certificate"
                        onBrowseRequested: root.browseCertificate("client")
                    }
                    BrowseField {
                        id: vpnPrivateKeyField
                        visible: root.selectedVpnType === "openvpn"
                            || root.selectedVpnType === "openconnect"
                            || root.selectedVpnType === "fortisslvpn"
                        width: parent.width
                        placeholder: "Private key"
                        onBrowseRequested: root.browseCertificate("privateKey")
                    }
                    FormField {
                        id: vpnPskField
                        visible: root.selectedVpnType === "l2tp"
                        width: parent.width
                        placeholder: root.editingVpnUuid !== ""
                            ? "New IPsec key (blank keeps current)"
                            : "IPsec pre-shared key (optional)"
                        secret: true
                    }

                    SmallButton {
                        visible: root.selectedVpnType !== "openvpn3"
                        buttonText: NetworkService.busy
                            ? (root.editingVpnUuid !== "" ? "Saving…" : "Adding…")
                            : (root.editingVpnUuid !== "" ? "Save changes" : "Add connection")
                        filled: true
                        enabled: !NetworkService.busy
                            && vpnNameField.text.trim() !== ""
                            && vpnGatewayField.text.trim() !== ""
                        opacity: enabled ? 1 : 0.45
                        onActivated: root.saveVpn()
                    }

                    Text {
                        visible: NetworkService.error !== ""
                        width: parent.width
                        text: NetworkService.error
                        color: Theme.red
                        font.family: Theme.fontFamily
                        font.pixelSize: 10
                        wrapMode: Text.WordWrap
                    }
                }
            }
        }
    }
}
