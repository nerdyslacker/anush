pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls as Controls
import "../.."

Popout {
    id: root

    cardWidth: 470
    cardHeight: 680

    property bool dirty: false
    property bool syncing: false
    property bool passwordVisible: false
    property string draftSsid: ""
    property string draftPassword: ""
    property string draftUpstreamUuid: ""
    property string draftWifiDevice: ""
    property string draftBand: "auto"
    property int draftChannel: 0

    readonly property var upstreamOptions: HotspotService.upstreams
    readonly property var wifiOptions: HotspotService.wifiDevices.filter(item =>
        item.apSupported).map(item => ({ value: item.name, label: item.label }))
    readonly property var selectedDraftDevice: HotspotService.wifiDevices.find(item =>
        item.name === draftWifiDevice) ?? null
    readonly property var bandOptions: [{ value: "auto", label: "Auto" }].concat(
        !selectedDraftDevice ? []
        : (selectedDraftDevice.channels5.length
            ? [{ value: "5", label: "5 GHz" }] : []).concat(
                selectedDraftDevice.channels24.length
                    ? [{ value: "2.4", label: "2.4 GHz" }] : []))
    readonly property var draftChannels: !selectedDraftDevice ? []
        : draftBand === "2.4" ? selectedDraftDevice.channels24
        : draftBand === "5" ? selectedDraftDevice.channels5 : []
    readonly property var channelOptions: [{ value: 0, label: "Auto" }].concat(
        draftChannels.map(value => ({ value: value, label: "Channel " + value })))
    readonly property var unavailableUpstreams: HotspotService.upstreams.filter(item =>
        !item.usable)

    function syncFromService() {
        if (dirty)
            return
        syncing = true
        draftSsid = HotspotService.ssid
        draftPassword = HotspotService.password
        const usable = HotspotService.usableUpstreams
        const savedUpstream = usable.find(item =>
            item.uuid === HotspotService.upstreamUuid)
        draftUpstreamUuid = savedUpstream ? savedUpstream.uuid
            : usable.length ? usable[0].uuid : ""
        const savedDevice = wifiOptions.find(item =>
            item.value === HotspotService.wifiDevice)
        draftWifiDevice = savedDevice ? savedDevice.value
            : wifiOptions.length ? wifiOptions[0].value : ""
        draftBand = HotspotService.band
        draftChannel = HotspotService.channel
        syncing = false
    }

    function markDirty() {
        if (!syncing)
            dirty = true
    }

    function configuration() {
        return {
            ssid: draftSsid,
            password: draftPassword,
            upstreamUuid: draftUpstreamUuid,
            wifiDevice: draftWifiDevice,
            band: draftBand,
            channel: draftChannel
        }
    }

    function apply(activate) {
        HotspotService.applyConfiguration(configuration(), activate)
        dirty = false
    }

    onVisibleChanged: {
        if (visible) {
            PopupCoordinator.requestOpen("hotspot", root)
            dirty = false
            passwordVisible = false
            HotspotService.setPopupActive(true)
            syncFromService()
        } else {
            HotspotService.setPopupActive(false)
            dirty = false
            passwordVisible = false
            draftPassword = ""
        }
    }

    Connections {
        target: PopupCoordinator
        function onOpening(name, owner) {
            if (owner !== root) root.visible = false
        }
    }

    Connections {
        target: HotspotService
        function onSsidChanged() { root.syncFromService() }
        function onPasswordChanged() { root.syncFromService() }
        function onUpstreamsChanged() { root.syncFromService() }
        function onWifiDevicesChanged() { root.syncFromService() }
        function onBandChanged() { root.syncFromService() }
        function onChannelChanged() { root.syncFromService() }
        function onPopupRequested(action) {
            if (!ShellActions.ownsFocusedOutput(root.anchorItem)) return
            if (action === "open") root.visible = true
            else if (action === "close") root.visible = false
            else root.visible = !root.visible
        }
    }

    component SectionTitle: Text {
        required property string title
        text: title
        color: Theme.accent
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontSize
        font.bold: true
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
            color: pill.checked ? Theme.bg : Qt.alpha(Theme.fg, 0.72)
            Behavior on x { NumberAnimation { duration: 140 } }
        }
        MouseArea { anchors.fill: parent; onClicked: pill.toggled() }
    }

    component FormField: Rectangle {
        id: field
        property alias text: input.text
        property alias echoMode: input.echoMode
        property string placeholder: ""
        signal edited()
        height: 34
        radius: Theme.radiusSmall
        color: Theme.gray2
        border.width: 1
        border.color: input.activeFocus ? Theme.accent : Theme.gray5
        TextInput {
            id: input
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            anchors.leftMargin: 10
            anchors.rightMargin: 10
            color: Theme.fg
            selectionColor: Theme.accent
            selectedTextColor: Theme.selfg
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSize
            clip: true
            onTextEdited: field.edited()
            Text {
                visible: input.text === ""
                text: field.placeholder
                color: Theme.disabled
                font: input.font
            }
        }
    }

    component Choice: Controls.ComboBox {
        id: choice
        required property string selectedValue
        signal chosen(string value)
        textRole: "label"
        valueRole: "value"
        implicitHeight: 34

        function selectedIndex() {
            for (let index = 0; index < model.length; ++index)
                if (String(model[index].value) === selectedValue)
                    return index
            return model.length ? 0 : -1
        }

        currentIndex: selectedIndex()
        onActivated: index => {
            if (index >= 0 && model[index])
                chosen(String(model[index].value))
        }
        contentItem: Text {
            leftPadding: 10
            rightPadding: 28
            verticalAlignment: Text.AlignVCenter
            text: choice.displayText
            color: choice.enabled ? Theme.fg : Theme.disabled
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSize
            elide: Text.ElideRight
        }
        background: Rectangle {
            radius: Theme.radiusSmall
            color: Theme.gray2
            border.width: 1
            border.color: choice.activeFocus ? Theme.accent : Theme.gray5
        }
        indicator: Text {
            anchors.right: parent.right
            anchors.rightMargin: 9
            anchors.verticalCenter: parent.verticalCenter
            text: "󰅀"
            color: Theme.disabled
            font.family: Theme.iconFontFamily
            font.pixelSize: Theme.iconSizeSmall
        }
        popup: Controls.Popup {
            y: choice.height + 3
            width: choice.width
            padding: 4
            contentItem: ListView {
                implicitHeight: Math.min(contentHeight, 260)
                clip: true
                model: choice.popup.visible ? choice.delegateModel : null
                currentIndex: choice.highlightedIndex
            }
            background: Rectangle {
                radius: Theme.radiusSmall
                color: Theme.bg
                border.width: 1
                border.color: Theme.gray5
            }
        }
        delegate: Controls.ItemDelegate {
            id: choiceDelegate
            required property int index
            width: choice.width - 8
            height: 32
            enabled: choice.model[choiceDelegate.index]?.usable !== false
            highlighted: choice.highlightedIndex === choiceDelegate.index
            contentItem: Text {
                text: choice.model[choiceDelegate.index]?.label ?? ""
                color: parent.enabled ? Theme.fg : Theme.disabled
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSize
                elide: Text.ElideRight
                verticalAlignment: Text.AlignVCenter
            }
            background: Rectangle {
                radius: Theme.radiusSmall
                color: choiceDelegate.highlighted ? Theme.gray3 : "transparent"
            }
        }
    }

    Column {
        anchors.fill: parent
        spacing: 10
        focus: true
        Keys.onEscapePressed: root.visible = false

        Row {
            width: parent.width
            height: 32
            spacing: 8
            Text {
                width: parent.width - hotspotSwitch.width - parent.spacing
                anchors.verticalCenter: parent.verticalCenter
                text: HotspotService.busy ? HotspotService.message : "Wi-Fi Hotspot"
                color: Theme.fg
                font.family: Theme.fontFamily
                font.pixelSize: 16
                font.bold: true
                elide: Text.ElideRight
            }
            SwitchPill {
                id: hotspotSwitch
                anchors.verticalCenter: parent.verticalCenter
                checked: HotspotService.active
                enabled: !HotspotService.busy && HotspotService.supported
                    && (HotspotService.active
                        || root.draftUpstreamUuid !== "")
                opacity: enabled ? 1 : 0.45
                onToggled: HotspotService.active
                    ? HotspotService.turnOff() : root.apply(true)
            }
        }

        Text {
            width: parent.width
            visible: !HotspotService.available || !HotspotService.supported
            text: !HotspotService.available ? "NetworkManager is unavailable."
                : HotspotService.supportReason
            color: Theme.red
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSize - 1
            wrapMode: Text.WordWrap
        }

        Text {
            width: parent.width
            visible: HotspotService.upstreamLost
                || HotspotService.upstreamMessage !== ""
            text: HotspotService.upstreamMessage
            color: Theme.brightOrange
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSize - 1
            wrapMode: Text.WordWrap
        }

        Flickable {
            width: parent.width
            height: parent.height - y
            contentWidth: width
            contentHeight: form.implicitHeight
            clip: true
            boundsBehavior: Flickable.StopAtBounds

            Column {
                id: form
                width: parent.width
                spacing: 10

                SectionTitle { title: "Internet source" }

                Row {
                    width: parent.width
                    height: 34
                    spacing: 10
                    Text {
                        width: 120
                        anchors.verticalCenter: parent.verticalCenter
                        text: "Share over"
                        color: Theme.fg
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSize
                    }
                    Choice {
                        width: parent.width - 130
                        model: root.upstreamOptions
                        selectedValue: root.draftUpstreamUuid
                        enabled: model.length > 0 && !HotspotService.busy
                        onChosen: value => {
                            root.draftUpstreamUuid = value
                            root.markDirty()
                        }
                    }
                }

                Text {
                    width: parent.width
                    visible: root.upstreamOptions.length === 0
                    text: "Connect Ethernet, Wi-Fi, or a VPN before starting the hotspot."
                    color: Theme.disabled
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSize - 1
                    wrapMode: Text.WordWrap
                }

                Text {
                    width: parent.width
                    visible: root.unavailableUpstreams.length > 0
                    text: root.unavailableUpstreams.map(item =>
                        item.label + ": " + item.reason).join("\n")
                    color: Theme.disabled
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSize - 2
                    wrapMode: Text.WordWrap
                }

                SectionTitle { title: "Network" }

                FormField {
                    width: parent.width
                    text: root.draftSsid
                    placeholder: "Network name / SSID"
                    enabled: !HotspotService.busy
                    onEdited: {
                        root.draftSsid = text
                        root.markDirty()
                    }
                }

                Row {
                    width: parent.width
                    height: 34
                    spacing: 8
                    FormField {
                        width: parent.width - reveal.width - parent.spacing
                        text: root.draftPassword
                        echoMode: root.passwordVisible
                            ? TextInput.Normal : TextInput.Password
                        placeholder: "Password (8–63 ASCII characters)"
                        enabled: !HotspotService.busy
                        onEdited: {
                            root.draftPassword = text
                            root.markDirty()
                        }
                    }
                    Rectangle {
                        id: reveal
                        width: 64
                        height: 34
                        radius: Theme.radiusSmall
                        color: revealMouse.containsMouse ? Theme.gray3 : Theme.gray2
                        border.width: 1
                        border.color: Theme.gray5
                        Text {
                            anchors.centerIn: parent
                            text: root.passwordVisible ? "Hide" : "Show"
                            color: Theme.fg
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSize - 1
                        }
                        MouseArea {
                            id: revealMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            onClicked: root.passwordVisible = !root.passwordVisible
                        }
                    }
                }

                SectionTitle { title: "Wireless" }

                Row {
                    width: parent.width
                    height: 34
                    spacing: 10
                    Text {
                        width: 120
                        anchors.verticalCenter: parent.verticalCenter
                        text: "Wi-Fi adapter"
                        color: Theme.fg
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSize
                    }
                    Choice {
                        width: parent.width - 130
                        model: root.wifiOptions
                        selectedValue: root.draftWifiDevice
                        enabled: model.length > 0 && !HotspotService.busy
                        onChosen: value => {
                            root.draftWifiDevice = value
                            if (!root.bandOptions.some(item =>
                                    item.value === root.draftBand))
                                root.draftBand = "auto"
                            root.draftChannel = 0
                            root.markDirty()
                        }
                    }
                }

                Row {
                    width: parent.width
                    height: 34
                    spacing: 10
                    Text {
                        width: 120
                        anchors.verticalCenter: parent.verticalCenter
                        text: "Frequency"
                        color: Theme.fg
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSize
                    }
                    Choice {
                        width: parent.width - 130
                        model: root.bandOptions
                        selectedValue: root.draftBand
                        enabled: !HotspotService.busy
                        onChosen: value => {
                            root.draftBand = value
                            root.draftChannel = 0
                            root.markDirty()
                        }
                    }
                }

                Row {
                    width: parent.width
                    height: 34
                    spacing: 10
                    Text {
                        width: 120
                        anchors.verticalCenter: parent.verticalCenter
                        text: "Channel"
                        color: Theme.fg
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSize
                    }
                    Choice {
                        width: parent.width - 130
                        model: root.channelOptions
                        selectedValue: String(root.draftChannel)
                        enabled: root.draftBand !== "auto" && !HotspotService.busy
                        onChosen: value => {
                            root.draftChannel = Number(value) || 0
                            root.markDirty()
                        }
                    }
                }

                SectionTitle { title: "Limits" }

                Rectangle {
                    width: parent.width
                    height: limitText.implicitHeight + 18
                    radius: Theme.radiusSmall
                    color: Theme.gray2
                    Text {
                        id: limitText
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.top: parent.top
                        anchors.margins: 9
                        text: "Maximum connected devices: unavailable\n"
                            + HotspotService.clientLimitReason
                        color: Theme.disabled
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSize - 1
                        wrapMode: Text.WordWrap
                    }
                }

                Rectangle {
                    width: parent.width
                    height: 34
                    radius: Theme.radiusSmall
                    color: applyMouse.containsMouse ? Theme.brightOrange : Theme.accent
                    opacity: enabled ? 1 : 0.45
                    enabled: root.dirty && !HotspotService.busy
                    Text {
                        anchors.centerIn: parent
                        text: HotspotService.active ? "Save and restart hotspot"
                            : "Save hotspot settings"
                        color: Theme.selfg
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSize
                        font.bold: true
                    }
                    MouseArea {
                        id: applyMouse
                        anchors.fill: parent
                        enabled: parent.enabled
                        hoverEnabled: true
                        onClicked: root.apply(false)
                    }
                }

                Text {
                    width: parent.width
                    visible: HotspotService.error !== ""
                        || HotspotService.message !== ""
                    text: HotspotService.error !== ""
                        ? HotspotService.error : HotspotService.message
                    color: HotspotService.error !== "" ? Theme.red : Theme.green
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSize - 1
                    wrapMode: Text.WordWrap
                }

                SectionTitle {
                    title: "Connected devices (" + HotspotService.clientCount + ")"
                }

                Text {
                    width: parent.width
                    visible: !HotspotService.active
                        || HotspotService.clients.length === 0
                    text: HotspotService.active
                        ? "No associated stations."
                        : "Start the hotspot to see associated stations."
                    color: Theme.disabled
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSize - 1
                }

                Repeater {
                    model: HotspotService.clients
                    Rectangle {
                        id: clientRow
                        required property var modelData
                        width: form.width
                        height: 44
                        radius: Theme.radiusSmall
                        color: Theme.gray2
                        Column {
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.margins: 9
                            spacing: 2
                            Text {
                                width: parent.width
                                text: clientRow.modelData.hostname || "Associated device"
                                color: Theme.fg
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontSize
                                elide: Text.ElideRight
                            }
                            Text {
                                width: parent.width
                                text: (clientRow.modelData.ipAddress || "IP not observed")
                                    + " · " + clientRow.modelData.macAddress
                                color: Theme.disabled
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontSize - 2
                                elide: Text.ElideRight
                            }
                        }
                    }
                }

                Text {
                    width: parent.width
                    text: "Device membership is verified with iw station data; IP addresses "
                        + "are best-effort neighbor-cache observations."
                    color: Theme.disabled
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSize - 2
                    wrapMode: Text.WordWrap
                }
            }
        }
    }
}
