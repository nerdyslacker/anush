pragma ComponentBehavior: Bound

import QtQuick
import "../.."
import QtQuick.Controls as Controls
import Quickshell
import Quickshell.Io

Popout {
    id: root

    cardWidth: 430
    cardHeight: 500

    property bool pendingAtCursor: false
    property string targetWindow: ""
    property int focusAttempts: 0
    property string selectedId: ""
    property bool pinnedOnly: false
    property bool confirmClearAll: false
    property bool pendingMinniPaste: false
    property string targetWindowClass: ""
    readonly property string query: searchInput.text.trim()
    readonly property var filteredEntries: ClipboardState.entries.filter(entry => {
        if (root.pinnedOnly && entry.pinned !== true)
            return false
        if (ClipboardState.usingMinni || root.query === "")
            return true
        const text = String(entry.preview_text ?? entry.text ?? "").toLowerCase()
        return text.indexOf(root.query.toLowerCase()) !== -1
    })

    function preview(content) {
        const compact = String(content).replace(/\s+/g, " ").trim()
        return compact.length > 125 ? compact.slice(0, 125) + "…" : compact
    }

    function details(entry) {
        if (entry.kind === "image")
            return (entry.pinned ? "Pinned · " : "") + String(entry.mime_type ?? "Image")
        if (entry.kind === "uri_list")
            return (entry.pinned ? "Pinned · " : "") + "Files"
        const type = entry.lineCount > 1 ? entry.lineCount + " lines" : "Text"
        const source = String(entry.source_app ?? "")
        return (entry.pinned ? "Pinned · " : "") + type
            + (source !== "" ? " · " + source : "")
    }

    function entryText(entry) {
        if (entry.kind === "image")
            return String(entry.label ?? "Image")
        return String(entry.preview_text ?? entry.text ?? "")
    }

    function selectedEntry() {
        if (historyList.currentIndex < 0 || historyList.currentIndex >= filteredEntries.length)
            return null
        return filteredEntries[historyList.currentIndex]
    }

    function moveSelection(delta) {
        if (historyList.count === 0)
            return
        historyList.currentIndex = Math.max(0,
            Math.min(historyList.count - 1, historyList.currentIndex + delta))
        historyList.positionViewAtIndex(historyList.currentIndex, ListView.Contain)
    }

    function reconcileSelection() {
        if (historyList.count === 0) {
            historyList.currentIndex = -1
            selectedId = ""
            return
        }
        let index = -1
        if (selectedId !== "") {
            index = filteredEntries.findIndex(
                entry => String(entry.id ?? "") === selectedId)
        }
        if (index < 0)
            index = Math.max(0, Math.min(historyList.currentIndex,
                historyList.count - 1))
        historyList.currentIndex = index
        selectedId = String(filteredEntries[index].id ?? "")
        historyList.positionViewAtIndex(index, ListView.Contain)
    }

    function toggleAtAnchor() {
        if (visible) {
            visible = false
            return
        }
        pendingAtCursor = false
        captureContext()
    }

    function toggleAtCursor() {
        if (visible) {
            visible = false
            return
        }
        pendingAtCursor = true
        captureContext()
    }

    function captureContext() {
        if (!contextProcess.running)
            contextProcess.running = true
    }

    function screenContainsPointer(x, y) {
        if (!anchorItem)
            return false
        const anchorPosition = anchorItem.mapToGlobal(0, 0)
        for (const screen of Quickshell.screens) {
            const ownsAnchor = anchorPosition.x >= screen.x
                && anchorPosition.x < screen.x + screen.width
                && anchorPosition.y >= screen.y
                && anchorPosition.y < screen.y + screen.height
            const ownsPointer = x >= screen.x && x < screen.x + screen.width
                && y >= screen.y && y < screen.y + screen.height
            if (ownsAnchor)
                return ownsPointer
        }
        return false
    }

    function focusSearch() {
        if (!visible)
            return
        requestKeyboardFocus()
        searchInput.forceActiveFocus()
    }

    function activate(entry) {
        if (!entry)
            return
        if (ClipboardState.usingMinni) {
            if (!ClipboardState.backendAvailable)
                return
            visible = false
            pendingMinniPaste = true
            ClipboardState.restore(entry)
            return
        }
        visible = false
        pasteProcess.environment = {
            "ANUSH_CLIPBOARD_ROW": String(entry.row),
            "ANUSH_CLIPBOARD_TARGET": targetWindow,
            "ANUSH_CLIPBOARD_PASTE_KEY": pasteKey()
        }
        pasteProcess.running = true
    }

    Connections {
        target: ClipboardState
        function onRestoreFinished(ok) {
            if (!root.pendingMinniPaste)
                return
            root.pendingMinniPaste = false
            if (!ok)
                return
            pasteProcess.environment = {
                "ANUSH_CLIPBOARD_ROW": "",
                "ANUSH_CLIPBOARD_TARGET": root.targetWindow,
                "ANUSH_CLIPBOARD_PASTE_KEY": root.pasteKey()
            }
            pasteProcess.running = true
        }
    }

    function pasteKey() {
        const configured = ClipboardState.pasteShortcut
        if (configured !== "auto")
            return configured === "shift+insert" ? "shift+Insert" : configured
        const windowClass = targetWindowClass.toLowerCase()
        const terminals = [
            "alacritty", "contour", "cool-retro-term", "foot", "ghostty",
            "gnome-terminal", "kitty", "konsole", "qterminal", "rio", "rxvt",
            "sakura", "st", "terminator", "tilix", "urxvt", "wezterm",
            "xfce4-terminal", "xterm"
        ]
        for (const terminal of terminals) {
            if (windowClass.indexOf(terminal) !== -1)
                return "ctrl+shift+v"
        }
        return "ctrl+v"
    }

    function toggleSelectedPin() {
        const entry = selectedEntry()
        if (ClipboardState.usingMinni && entry)
            ClipboardState.togglePinned(entry)
    }

    function removeSelected() {
        const entry = selectedEntry()
        if (ClipboardState.usingMinni && entry)
            ClipboardState.remove(entry)
    }

    function clearAll() {
        if (!confirmClearAll) {
            confirmClearAll = true
            clearConfirmation.restart()
            return
        }
        confirmClearAll = false
        clearConfirmation.stop()
        ClipboardState.clear("all")
    }

    function statusMessage() {
        if (ClipboardState.errorMessage !== "")
            return ClipboardState.errorMessage
        if (!ClipboardState.available)
            return ClipboardState.usingMinni ? "Connecting to minni…" : "Clipboard unavailable."
        if (ClipboardState.paused)
            return "Clipboard capture is paused."
        if (!ClipboardState.backendAvailable)
            return "History is available, but clipboard restore is unavailable."
        if (ClipboardState.busy)
            return "Loading clipboard history…"
        return ""
    }

    onVisibleChanged: {
        if (visible) {
            searchInput.text = ""
            pinnedOnly = false
            confirmClearAll = false
            historyList.currentIndex = historyList.count > 0 ? 0 : -1
            selectedId = historyList.currentIndex >= 0
                ? String(filteredEntries[historyList.currentIndex].id ?? "") : ""
            focusAttempts = 0
            if (ClipboardState.usingMinni)
                ClipboardState.search("")
            else
                ClipboardState.refresh()
            Qt.callLater(() => root.focusSearch())
            focusRetry.start()
        }
    }

    onFilteredEntriesChanged: Qt.callLater(() => root.reconcileSelection())

    Timer {
        id: searchDebounce
        interval: 180
        onTriggered: ClipboardState.search(root.query)
    }

    Timer {
        id: clearConfirmation
        interval: 4000
        onTriggered: root.confirmClearAll = false
    }

    Timer {
        id: focusRetry
        interval: 50
        repeat: true
        onTriggered: {
            root.focusAttempts++
            root.focusSearch()
            if (root.focusAttempts >= 4)
                stop()
        }
    }

    Process {
        id: contextProcess
        command: ["sh", "-c",
            "window=$(xdotool getactivewindow 2>/dev/null); "
            + "printf 'WINDOW=%s\\nCLASS=' \"$window\"; "
            + "xdotool getwindowclassname \"$window\" 2>/dev/null; "
            + "xdotool getmouselocation --shell 2>/dev/null"]
        stdout: StdioCollector {
            onStreamFinished: {
                const windowMatch = text.match(/(?:^|\n)WINDOW=(\d+)/)
                const classMatch = text.match(/(?:^|\n)CLASS=([^\n]*)/)
                const xMatch = text.match(/(?:^|\n)X=(-?\d+)/)
                const yMatch = text.match(/(?:^|\n)Y=(-?\d+)/)
                root.targetWindow = windowMatch ? windowMatch[1] : ""
                root.targetWindowClass = classMatch ? classMatch[1].trim() : ""

                if (root.pendingAtCursor) {
                    if (!xMatch || !yMatch)
                        return
                    const x = Number(xMatch[1])
                    const y = Number(yMatch[1])
                    if (!root.screenContainsPointer(x, y))
                        return
                    root.showAtGlobalPoint(x, y)
                } else {
                    root.showAtAnchor()
                }
            }
        }
    }

    Process {
        id: pasteProcess
        command: ["sh", "-c",
            "if [ -n \"$ANUSH_CLIPBOARD_ROW\" ]; then "
            + "'" + Theme.scriptsDir + "/clipboard/clipboard-history' select \"$ANUSH_CLIPBOARD_ROW\" || exit; fi; "
            + "if [ -n \"$ANUSH_CLIPBOARD_TARGET\" ]; then "
            + "xdotool windowactivate \"$ANUSH_CLIPBOARD_TARGET\" 2>/dev/null; "
            + "xdotool windowfocus \"$ANUSH_CLIPBOARD_TARGET\" 2>/dev/null; "
            + "sleep 0.05; fi; "
            + "xdotool key --clearmodifiers \"$ANUSH_CLIPBOARD_PASTE_KEY\""]
        stderr: StdioCollector {}
    }

    Column {
        anchors.fill: parent
        spacing: 8

        Item {
            width: parent.width
            height: 25

            Text {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                text: "Clipboard history"
                color: Theme.fg
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSize + 2
                font.bold: true
            }

            Row {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                spacing: 12

                Text {
                    visible: ClipboardState.usingMinni
                    text: ClipboardState.paused ? "Resume" : "Pause"
                    color: pauseMouse.containsMouse ? Theme.brightOrange : Theme.accent
                    font.family: Theme.fontFamily
                    font.pixelSize: Math.max(9, Theme.fontSize - 1)

                    MouseArea {
                        id: pauseMouse
                        anchors.fill: parent
                        anchors.margins: -5
                        hoverEnabled: true
                        onClicked: ClipboardState.togglePaused()
                    }
                }

                Text {
                    visible: ClipboardState.usingMinni
                    text: root.pinnedOnly ? "All" : "Pinned"
                    color: pinFilterMouse.containsMouse ? Theme.brightOrange : Theme.accent
                    font.family: Theme.fontFamily
                    font.pixelSize: Math.max(9, Theme.fontSize - 1)

                    MouseArea {
                        id: pinFilterMouse
                        anchors.fill: parent
                        anchors.margins: -5
                        hoverEnabled: true
                        onClicked: root.pinnedOnly = !root.pinnedOnly
                    }
                }

                Text {
                    text: ClipboardState.usingMinni ? "Clear unpinned" : "Clear"
                    color: clearMouse.containsMouse ? Theme.brightOrange : Theme.accent
                    font.family: Theme.fontFamily
                    font.pixelSize: Math.max(9, Theme.fontSize - 1)

                    MouseArea {
                        id: clearMouse
                        anchors.fill: parent
                        anchors.margins: -5
                        hoverEnabled: true
                        enabled: !ClipboardState.busy
                        onClicked: ClipboardState.clear("unpinned")
                    }
                }

                Text {
                    visible: ClipboardState.usingMinni
                    text: root.confirmClearAll ? "Confirm?" : "Clear all"
                    color: clearAllMouse.containsMouse ? Theme.brightOrange
                        : root.confirmClearAll ? Theme.red : Theme.brightBlack
                    font.family: Theme.fontFamily
                    font.pixelSize: Math.max(9, Theme.fontSize - 1)

                    MouseArea {
                        id: clearAllMouse
                        anchors.fill: parent
                        anchors.margins: -5
                        hoverEnabled: true
                        enabled: !ClipboardState.busy
                        onClicked: root.clearAll()
                    }
                }
            }
        }

        Rectangle {
            width: parent.width
            height: 36
            radius: Theme.radiusSmall
            color: Theme.gray2
            border.width: 1
            border.color: searchInput.activeFocus ? Theme.accent : Theme.gray5

            Text {
                anchors.left: parent.left
                anchors.leftMargin: 10
                anchors.verticalCenter: parent.verticalCenter
                text: "⌕"
                color: Theme.brightBlack
                font.pixelSize: Theme.fontSize + 3
            }

            TextInput {
                id: searchInput
                anchors.fill: parent
                anchors.leftMargin: 32
                anchors.rightMargin: 8
                verticalAlignment: TextInput.AlignVCenter
                color: Theme.fg
                selectionColor: Theme.accent
                selectedTextColor: Theme.bg
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSize
                clip: true

                onTextChanged: {
                    if (ClipboardState.usingMinni)
                        searchDebounce.restart()
                }

                Keys.onPressed: event => {
                    if (event.key === Qt.Key_Down) {
                        root.moveSelection(1)
                        event.accepted = true
                    } else if (event.key === Qt.Key_Up) {
                        root.moveSelection(-1)
                        event.accepted = true
                    } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                        root.activate(root.selectedEntry())
                        event.accepted = true
                    } else if (event.key === Qt.Key_Delete
                            && ClipboardState.usingMinni) {
                        root.removeSelected()
                        event.accepted = true
                    } else if (event.key === Qt.Key_P
                            && (event.modifiers & Qt.ControlModifier)
                            && ClipboardState.usingMinni) {
                        root.toggleSelectedPin()
                        event.accepted = true
                    }
                }

                Text {
                    anchors.fill: parent
                    verticalAlignment: Text.AlignVCenter
                    visible: searchInput.text.length === 0
                    text: "Search clipboard history…"
                    color: Theme.brightBlack
                    font: searchInput.font
                }
            }
        }

        Text {
            visible: root.statusMessage() !== ""
            width: parent.width
            wrapMode: Text.WordWrap
            text: root.statusMessage()
            color: Theme.brightBlack
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSize
        }

        Text {
            visible: ClipboardState.available && ClipboardState.errorMessage === ""
                && !ClipboardState.busy
                && root.filteredEntries.length === 0
            width: parent.width
            topPadding: 35
            horizontalAlignment: Text.AlignHCenter
            text: root.query === "" ? "Copy something to start the history" : "No matching items"
            color: Theme.brightBlack
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSize
        }

        ListView {
            id: historyList
            width: parent.width
            height: parent.height - y
            visible: count > 0
            clip: true
            spacing: 4
            model: root.filteredEntries
            currentIndex: count > 0 ? 0 : -1

            onCurrentIndexChanged: {
                if (currentIndex >= 0 && currentIndex < root.filteredEntries.length)
                    root.selectedId = String(root.filteredEntries[currentIndex].id ?? "")
            }

            delegate: Rectangle {
                id: historyRow
                required property var modelData
                required property int index

                // Scroll bars overlay ListView content, so reserve a fixed
                // gutter instead of allowing rows beneath the thumb.
                width: historyList.width - 14
                height: historyRow.modelData.kind === "image" ? 68 : 62
                radius: Theme.radiusSmall
                color: index === historyList.currentIndex
                    ? Qt.alpha(Theme.accent, 0.2)
                    : rowMouse.containsMouse ? Theme.gray3 : Theme.gray2
                border.width: 1
                border.color: index === historyList.currentIndex
                    ? Theme.accent : Theme.gray5

                MouseArea {
                    id: rowMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    onEntered: historyList.currentIndex = historyRow.index
                    onClicked: root.activate(historyRow.modelData)
                }

                Row {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.leftMargin: 10
                    anchors.rightMargin: 10
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 8

                    Rectangle {
                        width: 52
                        height: 52
                        visible: historyRow.modelData.kind === "image"
                        radius: Theme.radiusSmall
                        color: Theme.gray1
                        border.width: 1
                        border.color: Theme.gray5

                        Image {
                            id: thumbnail
                            anchors.fill: parent
                            anchors.margins: 2
                            source: ClipboardState.previewPath(
                                String(historyRow.modelData.id ?? ""))
                            sourceSize.width: 96
                            sourceSize.height: 96
                            fillMode: Image.PreserveAspectFit
                            asynchronous: true
                            cache: true
                        }

                        Text {
                            anchors.centerIn: parent
                            visible: thumbnail.status !== Image.Ready
                            text: {
                                const error = ClipboardState.previewError(
                                    String(historyRow.modelData.id ?? ""))
                                if (error === "UNSUPPORTED_IMAGE")
                                    return "Unsupported"
                                return error !== "" ? "Unavailable" : "Image"
                            }
                            color: Theme.brightBlack
                            font.family: Theme.fontFamily
                            font.pixelSize: Math.max(8, Theme.fontSize - 3)
                        }

                        Component.onCompleted: {
                            if (historyRow.modelData.kind === "image") {
                                ClipboardState.requestPreview(
                                    String(historyRow.modelData.id ?? ""))
                            }
                        }
                        onVisibleChanged: {
                            if (visible) {
                                ClipboardState.requestPreview(
                                    String(historyRow.modelData.id ?? ""))
                            }
                        }
                    }

                    Column {
                        width: parent.width
                            - (historyRow.modelData.kind === "image" ? 60 : 0)
                            - (ClipboardState.usingMinni ? 72 : 0)
                        spacing: 4

                        Text {
                            width: parent.width
                            text: root.preview(root.entryText(historyRow.modelData))
                            maximumLineCount: 1
                            elide: Text.ElideRight
                            color: Theme.fg
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSize
                        }

                        Text {
                            width: parent.width
                            text: root.details(historyRow.modelData)
                            elide: Text.ElideRight
                            color: Theme.brightBlack
                            font.family: Theme.fontFamily
                            font.pixelSize: Math.max(9, Theme.fontSize - 2)
                        }
                    }

                    Row {
                        visible: ClipboardState.usingMinni
                        width: 64
                        spacing: 8
                        z: 2

                        Rectangle {
                            width: 28
                            height: 28
                            radius: Theme.radiusSmall
                            color: pinMouse.containsMouse ? Theme.gray4 : Theme.gray3

                            Text {
                                anchors.centerIn: parent
                                text: historyRow.modelData.pinned ? "󰐄" : "󰐃"
                                color: pinMouse.containsMouse
                                    ? Theme.brightOrange : Theme.accent
                                font.family: Theme.iconFontFamily
                                font.pixelSize: Theme.iconSizeSmall
                            }

                            MouseArea {
                                id: pinMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                onClicked: ClipboardState.togglePinned(historyRow.modelData)
                            }

                            Controls.ToolTip.visible: pinMouse.containsMouse
                            Controls.ToolTip.text: historyRow.modelData.pinned
                                ? "Unpin" : "Pin"
                        }

                        Rectangle {
                            width: 28
                            height: 28
                            radius: Theme.radiusSmall
                            color: deleteMouse.containsMouse ? Theme.gray4 : Theme.gray3

                            Text {
                                anchors.centerIn: parent
                                text: "󰆴"
                                color: deleteMouse.containsMouse
                                    ? Theme.red : Theme.brightBlack
                                font.family: Theme.iconFontFamily
                                font.pixelSize: Theme.iconSizeSmall
                            }

                            MouseArea {
                                id: deleteMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                onClicked: ClipboardState.remove(historyRow.modelData)
                            }

                            Controls.ToolTip.visible: deleteMouse.containsMouse
                            Controls.ToolTip.text: "Delete"
                        }
                    }
                }
            }

            Controls.ScrollBar.vertical: Controls.ScrollBar {
                id: historyScroll
                width: 8
                policy: Controls.ScrollBar.AsNeeded
                interactive: true

                background: Rectangle {
                    radius: Math.min(width / 2, Theme.radiusSmall)
                    color: Theme.gray2
                    border.width: 1
                    border.color: Theme.gray5
                }

                contentItem: Rectangle {
                    implicitWidth: 6
                    implicitHeight: 28
                    radius: Math.min(width / 2, Theme.radiusSmall)
                    color: historyScroll.pressed ? Theme.brightOrange
                        : historyScroll.hovered ? Theme.orange : Theme.gray6
                }
            }
        }
    }
}
