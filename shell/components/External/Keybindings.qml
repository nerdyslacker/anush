pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import "../.."

// Searchable keybinding surface for window managers using Wm.uiEvent.
Scope {
    id: root

    property bool open: false
    property string outputName: ""
    property string search: ""
    property var bindings: []

    function matchesScreen(screen) {
        if (!screen) return false
        if (outputName !== "") return screen.name === outputName
        return Quickshell.screens.length > 0 && screen === Quickshell.screens[0]
    }

    function filteredBindings() {
        const needle = search.trim().toLowerCase()
        if (needle === "") return bindings
        return bindings.filter(binding =>
            String(binding.combo ?? "").toLowerCase().indexOf(needle) !== -1
            || String(binding.description ?? "").toLowerCase().indexOf(needle) !== -1)
    }

    function close() {
        open = false
        search = ""
    }

    Connections {
        target: Wm
        function onUiEvent(event) {
            if (String(event.change ?? "") !== "ui-bindings-toggle") return
            if (root.open) {
                root.close()
                return
            }
            root.outputName = String(event.output ?? "")
            root.bindings = Array.isArray(event.bindings) ? event.bindings : []
            root.search = ""
            root.open = true
        }
    }

    Variants {
        model: Quickshell.screens

        Scope {
            id: screenUi
            required property var modelData
            property int focusAttempts: 0

            function focusSearch() {
                if (!window.visible) return
                if (window.contentItem && window.contentItem.window)
                    window.contentItem.window.requestActivate()
                searchInput.forceActiveFocus()
            }

            Timer {
                id: focusRetry
                interval: 50
                repeat: true
                onTriggered: {
                    screenUi.focusAttempts++
                    screenUi.focusSearch()
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
                implicitWidth: Math.min(820, Math.max(320, screenUi.modelData.width - 32))
                implicitHeight: Math.min(620, Math.max(360, screenUi.modelData.height - 64))
                exclusiveZone: 0
                exclusionMode: ExclusionMode.Ignore
                aboveWindows: true
                focusable: true
                color: "transparent"
                visible: root.open && root.matchesScreen(screenUi.modelData)

                Shortcut { sequence: "Escape"; enabled: window.visible; onActivated: root.close() }
                onVisibleChanged: {
                    if (!visible) return
                    screenUi.focusAttempts = 0
                    Qt.callLater(() => screenUi.focusSearch())
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
                        anchors.margins: 18
                        spacing: 12

                        Row {
                            width: parent.width
                            height: 28
                            Text {
                                width: parent.width - closeButton.width
                                anchors.verticalCenter: parent.verticalCenter
                                text: "Keybindings"
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
                                    font.family: Theme.fontFamily; font.pixelSize: 15
                                }
                                MouseArea {
                                    id: closeMouse
                                    anchors.fill: parent; hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: root.close()
                                }
                            }
                        }

                        Rectangle {
                            width: parent.width
                            height: 42
                            radius: Theme.radiusMedium
                            color: Theme.gray2
                            border.width: 1
                            border.color: searchInput.activeFocus ? Theme.accent : Theme.gray5
                            Row {
                                anchors.fill: parent
                                anchors.leftMargin: 12; anchors.rightMargin: 12
                                spacing: 10
                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: "󰍉"; color: Theme.accent
                                    font.family: Theme.fontFamily; font.pixelSize: 16
                                }
                                TextInput {
                                    id: searchInput
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: parent.width - 38
                                    color: Theme.fg
                                    selectionColor: Theme.selbg
                                    selectedTextColor: Theme.selfg
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.fontSize
                                    clip: true
                                    text: root.search
                                    onTextEdited: root.search = text
                                    Text {
                                        anchors.verticalCenter: parent.verticalCenter
                                        visible: searchInput.text.length === 0
                                        text: "Search keys or actions"
                                        color: Theme.brightBlack
                                        font: searchInput.font
                                    }
                                }
                            }
                        }

                        Item {
                            width: parent.width
                            height: parent.height - y
                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                topPadding: 30
                                visible: bindingList.count === 0
                                text: "No matching keybindings"
                                color: Theme.brightBlack
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontSize
                            }
                            ListView {
                                id: bindingList
                                anchors.fill: parent
                                clip: true
                                spacing: 4
                                model: root.filteredBindings()
                                delegate: Rectangle {
                                    id: bindingRow
                                    required property var modelData
                                    width: bindingList.width
                                    height: 42
                                    radius: Theme.radiusSmall
                                    color: root.search.trim() !== ""
                                        ? Qt.alpha(Theme.accent, 0.14)
                                        : bindingMouse.containsMouse ? Theme.gray2 : "transparent"
                                    border.width: root.search.trim() !== "" ? 1 : 0
                                    border.color: Qt.alpha(Theme.accent, 0.45)
                                    Row {
                                        anchors.fill: parent
                                        anchors.margins: 6
                                        spacing: 12
                                        Rectangle {
                                            width: Math.min(300, Math.max(150, comboText.implicitWidth + 20))
                                            height: 30
                                            anchors.verticalCenter: parent.verticalCenter
                                            radius: Theme.radiusSmall
                                            color: root.search.trim() !== ""
                                                ? Qt.alpha(Theme.accent, 0.25) : Theme.gray2
                                            border.width: 1
                                            border.color: root.search.trim() !== "" ? Theme.accent : Theme.gray5
                                            Text {
                                                id: comboText
                                                anchors.centerIn: parent
                                                text: String(bindingRow.modelData.combo ?? "")
                                                color: root.search.trim() !== "" ? Theme.accent : Theme.fg
                                                font.family: Theme.fontFamily
                                                font.pixelSize: Theme.fontSize - 1
                                                font.bold: root.search.trim() !== ""
                                            }
                                        }
                                        Text {
                                            width: parent.width - x
                                            anchors.verticalCenter: parent.verticalCenter
                                            text: String(bindingRow.modelData.description ?? "")
                                            elide: Text.ElideRight
                                            color: Theme.fg
                                            font.family: Theme.fontFamily
                                            font.pixelSize: Theme.fontSize
                                        }
                                    }
                                    MouseArea {
                                        id: bindingMouse
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        acceptedButtons: Qt.NoButton
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
