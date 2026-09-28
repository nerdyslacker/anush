pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls as Controls
import "../.."

Item {
    id: root

    property var device: null
    property string page: "inbox"
    property var thread: null
    property string recipientQuery: ""
    property string recipientNumber: ""
    readonly property string deviceId: String(device?.id ?? "")
    readonly property var contactMatches: {
        const query = recipientQuery.trim().toLocaleLowerCase()
        if (query === "") return PhoneService.contacts.slice(0, 30)
        return PhoneService.contacts.filter(contact =>
            String(contact.name ?? "").toLocaleLowerCase().includes(query)
            || String(contact.phone ?? "").includes(query)).slice(0, 30)
    }

    signal backRequested()

    function openInbox() {
        page = "inbox"
        thread = null
        draftInput.text = ""
        if (deviceId !== "") PhoneService.loadConversations(deviceId)
    }

    function openThread(value) {
        if (!value) return
        thread = value
        page = "thread"
        draftInput.text = ""
        PhoneService.loadConversation(deviceId, value.threadId)
        Qt.callLater(scrollToBottom)
    }

    function openCompose() {
        page = "compose"
        thread = null
        recipientQuery = ""
        recipientNumber = ""
        recipient.text = ""
        draftInput.text = ""
        PhoneService.loadContacts(deviceId)
    }

    function scrollToBottom() {
        messageList.contentY = Math.max(0,
            messageList.contentHeight - messageList.height)
    }

    function send() {
        const text = draftInput.text.trim()
        if (text === "" || PhoneService.busy) return
        if (page === "thread" && thread) {
            if (PhoneService.smsReply(deviceId, thread.threadId, text))
                draftInput.text = ""
            return
        }
        const number = recipientNumber !== ""
            ? recipientNumber : recipientQuery.trim()
        if (number !== "" && PhoneService.smsSend(deviceId, number, text)) {
            draftInput.text = ""
            openInbox()
        }
    }

    function formatTime(value) {
        const numeric = Number(value)
        if (!isFinite(numeric) || numeric <= 0) return ""
        const date = new Date(numeric < 100000000000 ? numeric * 1000 : numeric)
        return Qt.formatDateTime(date, "MMM d  HH:mm")
    }

    function preview(value, maximum) {
        const text = String(value ?? "").replace(/\s+/g, " ").trim()
        return text.length > maximum
            ? text.slice(0, Math.max(0, maximum - 1)) + "…" : text
    }

    onDeviceIdChanged: {
        PhoneService.clearSms()
        if (visible && deviceId !== "") openInbox()
    }
    onVisibleChanged: if (visible && deviceId !== "") openInbox()

    Connections {
        target: PhoneService
        function onMessagesChanged() {
            if (root.page === "thread") Qt.callLater(root.scrollToBottom)
        }
    }

    component SmallButton: Rectangle {
        id: button
        required property string label
        property color accentColor: Theme.accent
        signal activated()
        implicitWidth: textItem.implicitWidth + 18
        height: 28
        radius: Theme.radiusSmall
        color: mouse.containsMouse ? Qt.alpha(accentColor, 0.24)
            : Qt.alpha(accentColor, 0.12)
        border.width: 1
        border.color: accentColor
        opacity: enabled ? 1 : 0.4
        Text {
            id: textItem
            anchors.centerIn: parent
            text: button.label
            color: button.accentColor
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSize - 2
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

    component InputBox: Rectangle {
        id: box
        property alias text: editor.text
        property string placeholder: ""
        signal accepted()
        function focusEditor() { editor.forceActiveFocus() }
        height: 34
        radius: Theme.radiusSmall
        color: Theme.gray2
        border.width: 1
        border.color: editor.activeFocus ? Theme.activeBorder : Theme.gray5
        TextInput {
            id: editor
            anchors.fill: parent
            anchors.leftMargin: 9
            anchors.rightMargin: 9
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
                color: Theme.foregroundMuted
                font: editor.font
            }
        }
    }

    Row {
        id: smsHeader
        width: parent.width
        height: 30
        spacing: 7
        SmallButton {
            label: root.page === "inbox" ? "Devices" : "Inbox"
            onActivated: root.page === "inbox"
                ? root.backRequested() : root.openInbox()
        }
        Text {
            width: parent.width - x - newMessage.width - 7
            anchors.verticalCenter: parent.verticalCenter
            text: root.page === "thread" ? String(root.thread?.title ?? "Messages")
                : root.page === "compose" ? "New message" : "Messages"
            color: Theme.fg
            horizontalAlignment: Text.AlignRight
            elide: Text.ElideRight
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSize + 1
            font.bold: true
        }
        SmallButton {
            id: newMessage
            visible: root.page === "inbox"
            label: "New"
            onActivated: root.openCompose()
        }
    }

    InputBox {
        id: recipient
        visible: root.page === "compose"
        anchors.top: smsHeader.bottom
        anchors.topMargin: 8
        width: parent.width
        placeholder: "Contact name or phone number"
        onTextChanged: {
            root.recipientQuery = text
            root.recipientNumber = ""
        }
    }

    Flickable {
        id: messageList
        anchors.top: root.page === "compose" ? recipient.bottom : smsHeader.bottom
        anchors.topMargin: 8
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: root.page === "inbox" ? parent.bottom : composer.top
        anchors.bottomMargin: root.page === "inbox" ? 0 : 8
        contentWidth: width
        contentHeight: content.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        Column {
            id: content
            width: messageList.width - 14
            spacing: 6

            Text {
                visible: PhoneService.smsLoading
                width: parent.width
                text: "Loading messages…"
                color: Theme.foregroundMuted
                horizontalAlignment: Text.AlignHCenter
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSize
            }

            Repeater {
                model: root.page === "inbox" ? PhoneService.conversations : []
                Rectangle {
                    id: conversationRow
                    required property var modelData
                    width: content.width
                    height: 58
                    radius: Theme.radiusMedium
                    clip: true
                    color: conversationMouse.containsMouse ? Theme.gray3 : Theme.gray2
                    border.width: 1
                    border.color: modelData.read === 0 ? Theme.accent : Theme.gray5
                    Column {
                        anchors.left: parent.left
                        anchors.right: timestamp.left
                        anchors.margins: 10
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 4
                        Text {
                            width: parent.width
                            text: root.preview(conversationRow.modelData.title, 70)
                            color: Theme.fg
                            elide: Text.ElideRight
                            maximumLineCount: 1
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSize
                            font.bold: conversationRow.modelData.read === 0
                        }
                        Text {
                            width: parent.width
                            text: root.preview(
                                conversationRow.modelData.body || "Attachment", 140)
                            color: Theme.foregroundMuted
                            elide: Text.ElideRight
                            maximumLineCount: 1
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSize - 2
                        }
                    }
                    Text {
                        id: timestamp
                        anchors.right: parent.right
                        anchors.rightMargin: 10
                        anchors.top: parent.top
                        anchors.topMargin: 10
                        text: root.formatTime(conversationRow.modelData.date)
                        color: Theme.foregroundMuted
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSize - 3
                    }
                    MouseArea {
                        id: conversationMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        onClicked: root.openThread(conversationRow.modelData)
                    }
                }
            }

            Repeater {
                model: root.page === "thread" ? PhoneService.messages : []
                Item {
                    id: messageRow
                    required property var modelData
                    readonly property bool mine: modelData.fromMe === true
                    width: content.width
                    height: bubble.height + 6
                    Rectangle {
                        id: bubble
                        anchors.left: messageRow.mine ? undefined : parent.left
                        anchors.right: messageRow.mine ? parent.right : undefined
                        width: Math.min(parent.width * 0.82,
                            Math.max(120, messageText.implicitWidth + 22))
                        height: bubbleContent.implicitHeight + 16
                        radius: Theme.radiusMedium
                        color: messageRow.mine
                            ? Qt.alpha(Theme.accent, 0.28) : Theme.gray2
                        border.width: 1
                        border.color: messageRow.mine ? Theme.accent : Theme.gray5
                        Column {
                            id: bubbleContent
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.top: parent.top
                            anchors.margins: 8
                            spacing: 4
                            Text {
                                id: messageText
                                width: parent.width
                                text: messageRow.modelData.body || "Attachment"
                                color: Theme.fg
                                wrapMode: Text.WrapAnywhere
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontSize
                            }
                            Text {
                                width: parent.width
                                text: root.formatTime(messageRow.modelData.date)
                                color: Theme.foregroundMuted
                                horizontalAlignment: Text.AlignRight
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontSize - 3
                            }
                        }
                    }
                }
            }

            Repeater {
                model: root.page === "compose" ? root.contactMatches : []
                Rectangle {
                    id: contactRow
                    required property var modelData
                    width: content.width
                    height: 46
                    radius: Theme.radiusSmall
                    color: contactMouse.containsMouse ? Theme.gray3 : Theme.gray2
                    border.width: 1
                    border.color: root.recipientNumber === modelData.phone
                        ? Theme.activeBorder : Theme.gray5
                    Column {
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.margins: 9
                        anchors.verticalCenter: parent.verticalCenter
                        Text {
                            width: parent.width
                            text: contactRow.modelData.name
                            color: Theme.fg
                            elide: Text.ElideRight
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSize
                        }
                        Text {
                            width: parent.width
                            text: contactRow.modelData.phone
                            color: Theme.foregroundMuted
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSize - 3
                        }
                    }
                    MouseArea {
                        id: contactMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        onClicked: {
                            root.recipientNumber = String(contactRow.modelData.phone)
                            root.recipientQuery = String(contactRow.modelData.name)
                            recipient.text = root.recipientQuery
                            draftInput.focusEditor()
                        }
                    }
                }
            }

            Text {
                visible: !PhoneService.smsLoading
                    && ((root.page === "inbox" && PhoneService.conversations.length === 0)
                    || (root.page === "thread" && PhoneService.messages.length === 0)
                    || (root.page === "compose" && root.contactMatches.length === 0))
                width: parent.width
                text: root.page === "compose"
                    ? "No matching contacts. You can type a phone number."
                    : "No messages found. Enable SMS and Contacts permissions on the phone."
                color: Theme.foregroundMuted
                wrapMode: Text.Wrap
                horizontalAlignment: Text.AlignHCenter
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSize
            }
        }

        Controls.ScrollBar.vertical: Controls.ScrollBar {
            id: messageScrollBar
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
                color: messageScrollBar.pressed ? Theme.brightOrange
                    : messageScrollBar.hovered ? Theme.orange : Theme.gray6
                radius: Math.min(width / 2, Theme.radiusSmall)
                Behavior on color { ColorAnimation { duration: 100 } }
            }
        }
    }

    Row {
        id: composer
        visible: root.page !== "inbox"
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        height: 34
        spacing: 7
        InputBox {
            id: draftInput
            width: parent.width - sendButton.width - parent.spacing
            placeholder: root.page === "thread" ? "Reply" : "Message"
            onAccepted: root.send()
        }
        SmallButton {
            id: sendButton
            anchors.verticalCenter: parent.verticalCenter
            label: "Send"
            accentColor: Theme.success
            enabled: !PhoneService.busy && draftInput.text.trim() !== ""
                && (root.page === "thread" || root.recipientNumber !== ""
                    || root.recipientQuery.trim() !== "")
            onActivated: root.send()
        }
    }
}
