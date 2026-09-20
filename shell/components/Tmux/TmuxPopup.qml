pragma ComponentBehavior: Bound

import QtQuick
import "../.."

Popout {
    id: root

    property string renameTarget: ""
    property string pendingKill: ""

    cardWidth: 480
    cardHeight: 500

    onVisibleChanged: {
        TmuxService.popupVisible = visible
        if (visible) {
            PopupCoordinator.requestOpen("tmux", root)
            TmuxService.refresh()
            Qt.callLater(() => sessionInput.forceActiveFocus())
        } else {
            renameTarget = ""
            pendingKill = ""
            sessionInput.text = ""
        }
    }

    Connections {
        target: PopupCoordinator
        function onOpening(name, owner) {
            if (owner !== root) root.visible = false
        }
    }

    function submitName() {
        const name = sessionInput.text.trim()
        const accepted = renameTarget !== ""
            ? TmuxService.renameSession(renameTarget, name)
            : TmuxService.createSession(name)
        if (accepted) {
            renameTarget = ""
            sessionInput.text = ""
        }
    }

    function beginRename(name) {
        pendingKill = ""
        renameTarget = name
        sessionInput.text = name
        sessionInput.selectAll()
        sessionInput.forceActiveFocus()
    }

    component ActionButton: Rectangle {
        id: button
        required property string label
        property color accentColor: Theme.accent
        property bool filled: false
        signal activated()

        implicitWidth: buttonLabel.implicitWidth + 18
        height: 28
        radius: Theme.radiusSmall
        color: filled ? accentColor
            : buttonMouse.containsMouse ? Qt.alpha(accentColor, 0.22)
            : Theme.gray2
        border.width: 1
        border.color: accentColor
        opacity: enabled ? 1 : 0.45

        Text {
            id: buttonLabel
            anchors.centerIn: parent
            text: button.label
            color: button.filled ? Theme.selfg : button.accentColor
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSize - 2
            font.bold: button.filled
        }
        MouseArea {
            id: buttonMouse
            anchors.fill: parent
            enabled: button.enabled
            hoverEnabled: true
            onClicked: button.activated()
        }
    }

    Column {
        anchors.fill: parent
        spacing: 9

        Row {
            width: parent.width
            height: 30
            spacing: 8
            Text {
                width: parent.width - refreshButton.width - parent.spacing
                anchors.verticalCenter: parent.verticalCenter
                text: "tmux sessions"
                color: Theme.fg
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSize + 2
                font.bold: true
            }
            ActionButton {
                id: refreshButton
                label: "Refresh"
                enabled: TmuxService.available && !TmuxService.busy
                onActivated: TmuxService.refresh()
            }
        }

        Row {
            visible: TmuxService.available
            width: parent.width
            height: 36
            spacing: 7

            Rectangle {
                width: parent.width - submitButton.width - parent.spacing
                    - (cancelRename.visible
                        ? cancelRename.width + parent.spacing : 0)
                height: parent.height
                radius: Theme.radiusSmall
                color: Theme.gray2
                border.width: 1
                border.color: sessionInput.activeFocus
                    ? Theme.activeBorder : Theme.gray5

                TextInput {
                    id: sessionInput
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
                    onAccepted: root.submitName()

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        visible: sessionInput.text === ""
                        text: root.renameTarget === ""
                            ? "New session name" : "Rename session"
                        color: Theme.foregroundMuted
                        font: sessionInput.font
                    }
                }
            }

            ActionButton {
                id: cancelRename
                visible: root.renameTarget !== ""
                label: "Cancel"
                onActivated: {
                    root.renameTarget = ""
                    sessionInput.text = ""
                }
            }
            ActionButton {
                id: submitButton
                label: root.renameTarget === "" ? "Create" : "Rename"
                filled: true
                enabled: !TmuxService.busy && sessionInput.text.trim() !== ""
                onActivated: root.submitName()
            }
        }

        Text {
            visible: TmuxService.checking || !TmuxService.available
            width: parent.width
            topPadding: 55
            horizontalAlignment: Text.AlignHCenter
            text: TmuxService.checking ? "Checking for tmux…"
                : "tmux is not installed."
            color: Theme.foregroundMuted
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSize
        }

        Text {
            visible: TmuxService.error !== ""
            width: parent.width
            text: TmuxService.error
            color: Theme.error
            wrapMode: Text.Wrap
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSize - 1
        }

        Text {
            visible: TmuxService.available && TmuxService.sessions.length > 0
            text: TmuxService.sessions.length + (TmuxService.sessions.length === 1
                ? " SESSION" : " SESSIONS")
            color: Theme.accent
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSize - 2
            font.bold: true
        }

        Flickable {
            visible: TmuxService.available
            width: parent.width
            height: Math.max(0, parent.height - y)
            contentWidth: width
            contentHeight: sessionList.implicitHeight
            clip: true
            boundsBehavior: Flickable.StopAtBounds

            Column {
                id: sessionList
                width: parent.width
                spacing: 6

                Repeater {
                    model: TmuxService.sessions

                    Rectangle {
                        id: sessionRow
                        required property var modelData
                        width: sessionList.width
                        height: 58
                        radius: Theme.radiusMedium
                        color: rowMouse.containsMouse ? Theme.gray3 : Theme.gray2
                        border.width: 1
                        border.color: modelData.attached > 0
                            ? Theme.activeBorder : Theme.gray5

                        MouseArea {
                            id: rowMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            onDoubleClicked: {
                                root.visible = false
                                TmuxService.attachSession(sessionRow.modelData.name)
                            }
                        }

                        Text {
                            id: sessionIcon
                            anchors.left: parent.left
                            anchors.leftMargin: 10
                            anchors.verticalCenter: parent.verticalCenter
                            text: ""
                            color: sessionRow.modelData.attached > 0
                                ? Theme.success : Theme.accent
                            font.family: Theme.iconFontFamily
                            font.pixelSize: Theme.iconSizeLarge
                        }

                        Column {
                            anchors.left: sessionIcon.right
                            anchors.leftMargin: 9
                            anchors.right: actions.left
                            anchors.rightMargin: 8
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 2
                            Text {
                                width: parent.width
                                text: sessionRow.modelData.name
                                color: Theme.fg
                                elide: Text.ElideRight
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontSize
                                font.bold: true
                            }
                            Text {
                                width: parent.width
                                text: sessionRow.modelData.windows
                                    + (sessionRow.modelData.windows === 1
                                        ? " window" : " windows")
                                    + " · " + (sessionRow.modelData.attached > 0
                                        ? sessionRow.modelData.attached + " attached"
                                        : "detached")
                                color: sessionRow.modelData.attached > 0
                                    ? Theme.success : Theme.foregroundMuted
                                elide: Text.ElideRight
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontSize - 2
                            }
                        }

                        Row {
                            id: actions
                            anchors.right: parent.right
                            anchors.rightMargin: 8
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 5
                            ActionButton {
                                label: "Open"
                                accentColor: Theme.success
                                enabled: !TmuxService.busy
                                onActivated: {
                                    root.visible = false
                                    TmuxService.attachSession(sessionRow.modelData.name)
                                }
                            }
                            ActionButton {
                                label: "Rename"
                                enabled: !TmuxService.busy
                                onActivated: root.beginRename(sessionRow.modelData.name)
                            }
                            ActionButton {
                                label: root.pendingKill === sessionRow.modelData.name
                                    ? "Confirm" : "Kill"
                                accentColor: Theme.error
                                filled: root.pendingKill === sessionRow.modelData.name
                                enabled: !TmuxService.busy
                                onActivated: {
                                    if (root.pendingKill === sessionRow.modelData.name) {
                                        TmuxService.killSession(sessionRow.modelData.name)
                                        root.pendingKill = ""
                                    } else {
                                        root.pendingKill = sessionRow.modelData.name
                                    }
                                }
                            }
                        }
                    }
                }

                Text {
                    visible: TmuxService.sessions.length === 0
                    width: parent.width
                    topPadding: 55
                    horizontalAlignment: Text.AlignHCenter
                    text: "No tmux sessions. Create one above."
                    color: Theme.foregroundMuted
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSize
                }
            }
        }
    }
}
