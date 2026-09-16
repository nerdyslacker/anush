pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls as Controls
import Quickshell
import "../.."

PanelWindow {
    id: root

    required property var modelData
    property bool windowActive: false
    property bool drawerShown: false
    property bool syncing: false
    readonly property bool shouldShow: NotepadState.opened
        && NotepadState.matchesScreen(modelData)
    readonly property bool barOnScreen: BarVisibility.showOnScreen(modelData)
    readonly property int edgeGap: Theme.surfaceGap
    readonly property int barGap: Math.max(2, Math.round(Theme.surfaceGap / 2))
    readonly property int topInset: barOnScreen
        && BarVisibility.barPosition === "top" ? barGap : edgeGap
    readonly property int bottomInset: barOnScreen
        && BarVisibility.barPosition === "bottom" ? barGap : edgeGap
    readonly property int leftInset: barOnScreen
        && BarVisibility.barPosition === "left" ? barGap : edgeGap
    readonly property int rightInset: barOnScreen
        && BarVisibility.barPosition === "right" ? barGap : edgeGap
    readonly property int availableWidth: Math.max(1,
        Number(modelData?.width ?? 680) - leftInset - rightInset)
    // Keep the native window stable at the largest supported size. Resizing a
    // PanelWindow every animation frame makes some X11 compositors visibly
    // stutter; only the QML drawer below should animate.
    readonly property int hostWidth: Math.min(availableWidth, 680)
    readonly property int drawerWidth: Math.min(hostWidth,
        NotepadState.extended ? 680 : 420)

    screen: modelData
    anchors.top: true
    anchors.bottom: true
    anchors.left: NotepadState.side === "left"
    anchors.right: NotepadState.side === "right"
    margins.top: topInset
    margins.bottom: bottomInset
    margins.left: leftInset
    margins.right: rightInset
    implicitWidth: hostWidth
    exclusiveZone: 0
    exclusionMode: ExclusionMode.Ignore
    aboveWindows: true
    focusable: true
    color: "transparent"
    visible: windowActive
    mask: Region { item: drawer }

    function syncEditor() {
        if (editor.text === NotepadState.text)
            return
        syncing = true
        const previousPosition = editor.cursorPosition
        editor.text = NotepadState.text
        editor.cursorPosition = Math.min(previousPosition, editor.length)
        syncing = false
    }

    function focusEditor() {
        if (root.contentItem && root.contentItem.window)
            root.contentItem.window.requestActivate()
        editor.forceActiveFocus()
    }

    function scrollTabs(delta) {
        const maximum = Math.max(0, tabFlick.contentWidth - tabFlick.width)
        tabFlick.contentX = Math.max(0,
            Math.min(maximum, tabFlick.contentX + delta))
    }

    function ensureTabVisible(tab) {
        if (!tab)
            return
        if (tab.x < tabFlick.contentX)
            tabFlick.contentX = tab.x
        else if (tab.x + tab.width > tabFlick.contentX + tabFlick.width)
            tabFlick.contentX = tab.x + tab.width - tabFlick.width
    }

    function ensureActiveTabVisible() {
        Qt.callLater(() => root.ensureTabVisible(
            tabRepeater.itemAt(NotepadState.activeIndex)))
    }

    onShouldShowChanged: {
        if (shouldShow) {
            closeWindow.stop()
            windowActive = true
            Qt.callLater(() => {
                root.drawerShown = true
                root.syncEditor()
                root.focusEditor()
            })
        } else if (windowActive) {
            drawerShown = false
            closeWindow.restart()
        }
    }

    onVisibleChanged: if (visible && shouldShow) Qt.callLater(() => root.focusEditor())

    Connections {
        target: NotepadState
        function onTextChanged() { root.syncEditor() }
        function onActiveFilePathChanged() { Qt.callLater(() => root.syncEditor()) }
        function onActiveIndexChanged() { root.ensureActiveTabVisible() }
        function onFilesChanged() { root.ensureActiveTabVisible() }
    }

    Timer {
        id: closeWindow
        interval: 230
        onTriggered: if (!root.shouldShow) root.windowActive = false
    }

    Shortcut {
        sequence: "Escape"
        enabled: root.visible
        onActivated: NotepadState.close()
    }
    Shortcut {
        sequence: "Ctrl+N"
        enabled: root.visible
        onActivated: NotepadState.createNote()
    }

    component ToolButton: Rectangle {
        id: button
        required property string glyph
        property string tooltip: ""
        signal activated

        width: 32
        height: 32
        radius: Theme.radiusSmall
        color: buttonMouse.pressed ? Theme.pressed
            : buttonMouse.containsMouse ? Theme.hover : Theme.surfaceVariant
        border.width: 1
        border.color: Theme.outline

        Text {
            anchors.centerIn: parent
            text: button.glyph
            color: Theme.foreground
            font.family: Theme.iconFontFamily
            font.pixelSize: 16
        }
        MouseArea {
            id: buttonMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: button.activated()
        }
    }

    Rectangle {
        id: drawer
        property real revealProgress: root.drawerShown ? 1 : 0
        readonly property real restingX: NotepadState.side === "left"
            ? 0 : root.width - width
        readonly property real hiddenOffset: NotepadState.side === "left"
            ? -width : width

        width: root.drawerWidth
        height: root.height
        // Pin the visible edge while width changes. Sliding is expressed as
        // real geometry so Quickshell's window mask follows the animation.
        x: restingX + (1 - revealProgress) * hiddenOffset
        color: Theme.background
        border.width: 1
        border.color: Qt.alpha(Theme.accent, 0.55)
        radius: Theme.radiusLarge

        Behavior on revealProgress {
            NumberAnimation { duration: 220; easing.type: Easing.OutCubic }
        }

        Behavior on width {
            NumberAnimation { duration: 240; easing.type: Easing.InOutCubic }
        }
        Behavior on color { ColorAnimation { duration: 250 } }

        Item {
            id: header
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: 14
            height: 34

            Text {
                anchors.left: titleIcon.right
                anchors.leftMargin: 9
                anchors.verticalCenter: parent.verticalCenter
                text: "Notepad"
                color: Theme.foreground
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSize + 2
                font.bold: true
            }
            ToolButton {
                id: closeButton
                anchors.right: parent.right
                glyph: "󰅖"
                tooltip: "Close Notepad"
                onActivated: NotepadState.close()
            }
            ToolButton {
                anchors.right: closeButton.left
                anchors.rightMargin: 7
                glyph: NotepadState.extended ? "󰘕" : "󰘖"
                tooltip: NotepadState.extended ? "Use compact width" : "Extend width"
                onActivated: NotepadState.toggleExtended()
            }
        }

        Item {
            id: tabBar
            readonly property bool overflow: tabs.implicitWidth > tabFlick.width + 1
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: header.bottom
            anchors.leftMargin: 14
            anchors.rightMargin: 14
            anchors.topMargin: 10
            height: 38

            ToolButton {
                id: newTabButton
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                glyph: "+"
                tooltip: "New note (Ctrl+N)"
                onActivated: NotepadState.createNote()
            }

            ToolButton {
                id: nextTabsButton
                visible: tabBar.overflow
                enabled: tabFlick.contentX
                    < tabFlick.contentWidth - tabFlick.width - 1
                opacity: enabled ? 1 : 0.4
                anchors.right: newTabButton.left
                anchors.rightMargin: 6
                anchors.verticalCenter: parent.verticalCenter
                width: visible ? 32 : 0
                glyph: "›"
                tooltip: "Later tabs"
                onActivated: root.scrollTabs(130)
            }

            ToolButton {
                id: previousTabsButton
                visible: tabBar.overflow
                enabled: tabFlick.contentX > 1
                opacity: enabled ? 1 : 0.4
                anchors.right: nextTabsButton.left
                anchors.rightMargin: 5
                anchors.verticalCenter: parent.verticalCenter
                width: visible ? 32 : 0
                glyph: "‹"
                tooltip: "Earlier tabs"
                onActivated: root.scrollTabs(-130)
            }

            Flickable {
                id: tabFlick
                anchors.left: parent.left
                anchors.right: tabBar.overflow
                    ? previousTabsButton.left : newTabButton.left
                anchors.rightMargin: 8
                height: parent.height
                contentWidth: tabs.implicitWidth
                contentHeight: height
                clip: true
                boundsBehavior: Flickable.StopAtBounds

                Behavior on contentX {
                    NumberAnimation { duration: 140; easing.type: Easing.OutCubic }
                }

                Row {
                    id: tabs
                    height: parent.height
                    spacing: 5

                    Repeater {
                        id: tabRepeater
                        model: NotepadState.files
                        Rectangle {
                            id: tab
                            required property var modelData
                            required property int index
                            readonly property bool selected: index === NotepadState.activeIndex
                            width: Math.min(170, Math.max(92,
                                tabLabel.implicitWidth + (tabClose.visible ? 48 : 26)))
                            height: 34
                            radius: Theme.radiusSmall
                            color: selected ? Theme.surfaceVariant
                                : tabMouse.containsMouse ? Theme.hover : Theme.surface
                            border.width: 1
                            border.color: selected ? Theme.accent : Theme.outline

                            Text {
                                id: tabLabel
                                anchors.left: parent.left
                                anchors.right: tabClose.visible ? tabClose.left : parent.right
                                anchors.leftMargin: 12
                                anchors.rightMargin: tabClose.visible ? 5 : 12
                                anchors.verticalCenter: parent.verticalCenter
                                text: tab.modelData.title
                                    + (tab.selected && NotepadState.dirty ? " •" : "")
                                color: tab.selected ? Theme.foreground : Theme.foregroundMuted
                                elide: Text.ElideRight
                                font.family: Theme.fontFamily
                                font.pixelSize: Math.max(9, Theme.fontSize - 1)
                            }
                            Rectangle {
                                id: tabClose
                                visible: NotepadState.files.length > 1
                                anchors.right: parent.right
                                anchors.rightMargin: 6
                                anchors.verticalCenter: parent.verticalCenter
                                width: 20
                                height: 20
                                radius: Theme.radiusSmall
                                color: closeMouse.containsMouse
                                    ? Theme.pressed : "transparent"
                                z: 2

                                Text {
                                    anchors.centerIn: parent
                                    text: "×"
                                    color: closeMouse.containsMouse
                                        ? Theme.foreground : Theme.foregroundMuted
                                    font.family: Theme.fontFamily
                                    font.pixelSize: 15
                                }
                                MouseArea {
                                    id: closeMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: NotepadState.closeTab(tab.index)
                                }
                            }
                            MouseArea {
                                id: tabMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    NotepadState.activate(tab.index)
                                    root.ensureTabVisible(tab)
                                }
                            }
                        }
                    }
                }
            }
        }

        Rectangle {
            id: editorFrame
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: tabBar.bottom
            anchors.bottom: footer.top
            anchors.margins: 14
            anchors.topMargin: 8
            anchors.bottomMargin: 10
            radius: Theme.radiusMedium
            color: Theme.surface
            border.width: 1
            border.color: editor.activeFocus ? Theme.accent : Theme.outline
            clip: true

            Controls.ScrollView {
                anchors.fill: parent
                anchors.margins: 2
                clip: true

                Controls.TextArea {
                    id: editor
                    enabled: NotepadState.ready
                    padding: 12
                    placeholderText: NotepadState.ready
                        ? "Write a note… Markdown is welcome."
                        : "Loading note…"
                    color: Theme.foreground
                    placeholderTextColor: Theme.foregroundMuted
                    selectionColor: Theme.accent
                    selectedTextColor: Theme.accentForeground
                    wrapMode: TextEdit.Wrap
                    textFormat: TextEdit.PlainText
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSize
                    background: Rectangle { color: "transparent" }
                    onTextChanged: if (!root.syncing) NotepadState.setText(text)
                    Keys.onPressed: event => {
                        if (event.modifiers & Qt.ControlModifier
                                && event.key === Qt.Key_S) {
                            NotepadState.saveNow(true)
                            event.accepted = true
                        }
                    }
                }
            }
        }

        Item {
            id: footer
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.margins: 14
            height: errorText.visible ? 72 : 48

            Text {
                id: errorText
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                visible: NotepadState.errorMessage !== ""
                    || NotepadState.externalConflict
                text: NotepadState.errorMessage !== ""
                    ? NotepadState.errorMessage
                    : "Changed on disk. Ctrl+S overwrites; your text is still safe."
                color: Theme.error
                elide: Text.ElideRight
                font.family: Theme.fontFamily
                font.pixelSize: Math.max(8, Theme.fontSize - 2)
            }

            Row {
                anchors.left: parent.left
                anchors.bottom: parent.bottom
                height: 30
                spacing: 5

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Open from"
                    color: Theme.foregroundMuted
                    font.family: Theme.fontFamily
                    font.pixelSize: Math.max(8, Theme.fontSize - 2)
                }
                Repeater {
                    model: ["left", "right"]
                    Rectangle {
                        id: sideButton
                        required property string modelData
                        width: 48
                        height: 26
                        radius: Theme.radiusSmall
                        color: NotepadState.side === modelData
                            ? Theme.accent : Theme.surfaceVariant
                        border.width: 1
                        border.color: NotepadState.side === modelData
                            ? Theme.accent : Theme.outline
                        Text {
                            anchors.centerIn: parent
                            text: sideButton.modelData.charAt(0).toUpperCase()
                                + sideButton.modelData.slice(1)
                            color: NotepadState.side === sideButton.modelData
                                ? Theme.accentForeground : Theme.foreground
                            font.family: Theme.fontFamily
                            font.pixelSize: Math.max(8, Theme.fontSize - 2)
                        }
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: NotepadState.setSide(sideButton.modelData)
                        }
                    }
                }
            }

            Text {
                anchors.left: parent.left
                anchors.leftMargin: 170
                anchors.right: openExternal.left
                anchors.rightMargin: 8
                anchors.bottom: parent.bottom
                height: 30
                verticalAlignment: Text.AlignVCenter
                text: {
                    const prefix = NotepadState.status === "saving" ? "Saving…"
                        : NotepadState.status === "unsaved" ? "Unsaved"
                        : NotepadState.status === "error" ? "Save failed"
                        : NotepadState.status === "conflict" ? "Changed externally"
                        : "Saved"
                    return prefix + (NotepadState.activeFile
                        ? "  ·  " + NotepadState.activeFile.name : "")
                }
                color: NotepadState.status === "error"
                    || NotepadState.status === "conflict" ? Theme.error
                    : NotepadState.status === "unsaved" ? Theme.warning
                    : NotepadState.status === "saved" ? Theme.success
                    : Theme.foregroundMuted
                elide: Text.ElideMiddle
                horizontalAlignment: Text.AlignRight
                font.family: Theme.fontFamily
                font.pixelSize: Math.max(8, Theme.fontSize - 2)
            }

            ToolButton {
                id: openExternal
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                width: 30
                height: 30
                glyph: "󰏌"
                tooltip: "Open current note externally"
                onActivated: NotepadState.openExternally()
            }
        }
    }
}
