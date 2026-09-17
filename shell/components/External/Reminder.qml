pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import "../.."

// Reminder editor and pending-reminder list for external integrations.
Scope {
    id: root

    property string mode: ""
    property string outputName: ""
    property var reminders: []

    function matchesScreen(screen) {
        if (!screen) return false
        if (outputName !== "") return screen.name === outputName
        return Quickshell.screens.length > 0 && screen === Quickshell.screens[0]
    }

    function close() { mode = "" }

    Connections {
        target: Wm
        function onUiEvent(event) {
            const change = String(event.change ?? "")
            if (change !== "ui-reminder-new" && change !== "ui-reminders-show") return
            root.outputName = String(event.output ?? "")
            if (change === "ui-reminder-new") {
                root.mode = root.mode === "new" ? "" : "new"
            } else {
                root.reminders = Array.isArray(event.reminders) ? event.reminders : []
                root.mode = root.mode === "list" ? "" : "list"
            }
        }
    }

    Variants {
        model: Quickshell.screens

        Scope {
            id: screenUi
            required property var modelData
            property int focusAttempts: 0

            function focusEditor() {
                if (!window.visible || root.mode !== "new") return
                if (window.contentItem && window.contentItem.window)
                    window.contentItem.window.requestActivate()
                minutesInput.forceActiveFocus()
            }

            Timer {
                id: focusRetry
                interval: 50
                repeat: true
                onTriggered: {
                    screenUi.focusAttempts++
                    screenUi.focusEditor()
                    if (screenUi.focusAttempts >= 5) stop()
                }
            }

            PanelWindow {
                id: window
                screen: screenUi.modelData
                anchors.top: true
                anchors.left: true
                margins.top: Math.max(16, Math.round((screenUi.modelData.height - implicitHeight) / 2))
                margins.left: Math.max(16, Math.round((screenUi.modelData.width - implicitWidth) / 2))
                implicitWidth: root.mode === "list"
                    ? Math.min(620, Math.max(320, screenUi.modelData.width - 32))
                    : Math.min(560, Math.max(320, screenUi.modelData.width - 32))
                implicitHeight: root.mode === "list"
                    ? Math.min(500, Math.max(220, 112 + root.reminders.length * 50))
                    : 220
                exclusiveZone: 0
                exclusionMode: ExclusionMode.Ignore
                aboveWindows: true
                focusable: true
                color: "transparent"
                visible: root.mode !== "" && root.matchesScreen(screenUi.modelData)

                Shortcut { sequence: "Escape"; enabled: window.visible; onActivated: root.close() }
                onVisibleChanged: {
                    if (!visible || root.mode !== "new") return
                    screenUi.focusAttempts = 0
                    editor.errorText = ""
                    minutesInput.text = ""
                    messageInput.text = ""
                    Qt.callLater(() => screenUi.focusEditor())
                    focusRetry.restart()
                }

                Rectangle {
                    anchors.fill: parent
                    radius: Theme.radiusLarge
                    color: Theme.bg
                    border.width: 1
                    border.color: Qt.alpha(Theme.accent, 0.55)

                    Column {
                        anchors.fill: parent
                        anchors.margins: root.mode === "new" ? 15 : 18
                        spacing: root.mode === "new" ? 9 : 12

                        Row {
                            width: parent.width
                            height: 28
                            Text {
                                width: parent.width - closeButton.width
                                anchors.verticalCenter: parent.verticalCenter
                                text: root.mode === "new" ? "New reminder" : "Pending reminders"
                                color: Theme.fg
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontSize + 3
                                font.bold: true
                            }
                            Rectangle {
                                id: closeButton
                                width: 28; height: 28
                                radius: Theme.radiusSmall
                                color: closeMouse.containsMouse ? Theme.gray4 : Theme.gray2
                                Text {
                                    anchors.centerIn: parent
                                    text: "󰅖"; color: Theme.brightBlack
                                    font.family: Theme.iconFontFamily; font.pixelSize: Theme.iconSize
                                }
                                MouseArea {
                                    id: closeMouse
                                    anchors.fill: parent; hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: root.close()
                                }
                            }
                        }

                        Column {
                            id: editor
                            width: parent.width
                            height: parent.height - y
                            spacing: 9
                            visible: root.mode === "new"
                            property string errorText: ""

                            Text {
                                text: "Countdowns stay active while the window manager is running."
                                color: Theme.brightBlack
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontSize
                            }
                            Row {
                                width: parent.width
                                height: 40
                                spacing: 8
                                Rectangle {
                                    width: 108; height: parent.height
                                    radius: Theme.radiusMedium
                                    color: Theme.gray2
                                    border.width: 1
                                    border.color: minutesInput.activeFocus ? Theme.accent : Theme.gray5
                                    TextInput {
                                        id: minutesInput
                                        anchors.fill: parent; anchors.margins: 11
                                        verticalAlignment: TextInput.AlignVCenter
                                        inputMethodHints: Qt.ImhDigitsOnly
                                        validator: IntValidator { bottom: 1; top: 525600 }
                                        KeyNavigation.tab: messageInput
                                        color: Theme.fg
                                        selectionColor: Theme.selbg
                                        selectedTextColor: Theme.selfg
                                        font.family: Theme.fontFamily
                                        font.pixelSize: Theme.fontSize
                                        Text {
                                            visible: minutesInput.text.length === 0
                                            text: "Minutes"; color: Theme.brightBlack
                                            font: minutesInput.font
                                        }
                                        Keys.priority: Keys.BeforeItem
                                        Keys.onPressed: event => {
                                            if (event.key === Qt.Key_Tab || event.key === Qt.Key_Return
                                                    || event.key === Qt.Key_Enter) {
                                                messageInput.forceActiveFocus()
                                                event.accepted = true
                                            }
                                        }
                                    }
                                }
                                Rectangle {
                                    width: parent.width - 116; height: parent.height
                                    radius: Theme.radiusMedium
                                    color: Theme.gray2
                                    border.width: 1
                                    border.color: messageInput.activeFocus ? Theme.accent : Theme.gray5
                                    TextInput {
                                        id: messageInput
                                        anchors.fill: parent; anchors.margins: 11
                                        verticalAlignment: TextInput.AlignVCenter
                                        KeyNavigation.backtab: minutesInput
                                        color: Theme.fg
                                        selectionColor: Theme.selbg
                                        selectedTextColor: Theme.selfg
                                        font.family: Theme.fontFamily
                                        font.pixelSize: Theme.fontSize
                                        clip: true
                                        Text {
                                            visible: messageInput.text.length === 0
                                            text: "What should I remind you about?"
                                            color: Theme.brightBlack
                                            font: messageInput.font
                                        }
                                        Keys.onReturnPressed: applyButton.submit()
                                        Keys.onBacktabPressed: minutesInput.forceActiveFocus()
                                    }
                                }
                            }
                            Text {
                                text: editor.errorText
                                visible: text !== ""
                                color: Theme.red
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontSize - 1
                            }
                            Item { width: 1; height: 1 }
                            Row {
                                width: parent.width
                                height: 36
                                spacing: 8
                                layoutDirection: Qt.RightToLeft
                                Rectangle {
                                    id: applyButton
                                    width: 96; height: parent.height
                                    radius: Theme.radiusMedium
                                    color: applyMouse.containsMouse ? Theme.brightOrange : Theme.accent
                                    function submit() {
                                        const minutes = Number(minutesInput.text)
                                        const message = messageInput.text.trim()
                                        if (!Number.isInteger(minutes) || minutes < 1 || minutes > 525600) {
                                            editor.errorText = "Enter a whole number of minutes from 1 to 525600."
                                            minutesInput.forceActiveFocus()
                                            return
                                        }
                                        if (message === "") {
                                            editor.errorText = "Enter a reminder message."
                                            messageInput.forceActiveFocus()
                                            return
                                        }
                                        Wm.addReminder(minutes, message)
                                        root.close()
                                    }
                                    Text {
                                        anchors.centerIn: parent
                                        text: "Apply"; color: Theme.selfg
                                        font.family: Theme.fontFamily
                                        font.pixelSize: Theme.fontSize; font.bold: true
                                    }
                                    MouseArea {
                                        id: applyMouse
                                        anchors.fill: parent; hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: applyButton.submit()
                                    }
                                }
                                Rectangle {
                                    width: 96; height: parent.height
                                    radius: Theme.radiusMedium
                                    color: cancelMouse.containsMouse ? Theme.gray4 : Theme.gray2
                                    border.width: 1; border.color: Theme.gray5
                                    Text {
                                        anchors.centerIn: parent
                                        text: "Cancel"; color: Theme.fg
                                        font.family: Theme.fontFamily
                                        font.pixelSize: Theme.fontSize
                                    }
                                    MouseArea {
                                        id: cancelMouse
                                        anchors.fill: parent; hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: root.close()
                                    }
                                }
                            }
                        }

                        ListView {
                            width: parent.width
                            height: parent.height - y
                            visible: root.mode === "list"
                            clip: true
                            spacing: 6
                            model: root.reminders
                            delegate: Rectangle {
                                required property string modelData
                                width: ListView.view.width
                                height: 44
                                radius: Theme.radiusMedium
                                color: Theme.gray2
                                border.width: 1; border.color: Theme.gray5
                                Text {
                                    anchors.fill: parent
                                    anchors.leftMargin: 12; anchors.rightMargin: 12
                                    verticalAlignment: Text.AlignVCenter
                                    text: modelData
                                    elide: Text.ElideRight
                                    color: Theme.fg
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.fontSize
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
