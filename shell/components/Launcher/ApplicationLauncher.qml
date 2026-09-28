import QtQuick
import "../.."
import QtQuick.Controls as Controls
import Quickshell
import Quickshell.Io
import Quickshell.Widgets

// Application launcher with opt-in file, SSH host, and mount search modes.
Popout {
    id: root

    cardWidth: 520
    cardHeight: 480

    property string selectedCategory: ""
    readonly property var categoryDefinitions: [
        { name: "Favorites", icon: "󰓎", matches: [] },
        { name: "Development", icon: "󰅩", matches: ["Development"] },
        { name: "Graphics", icon: "󰏘", matches: ["Graphics"] },
        { name: "Internet", icon: "󰖟", matches: ["Network"] },
        { name: "Multimedia", icon: "󰝚", matches: ["AudioVideo", "Audio", "Video"] },
        { name: "Office", icon: "󰈙", matches: ["Office"] },
        { name: "System", icon: "󰒓", matches: ["System", "Settings"] },
        { name: "Utilities", icon: "󰦬", matches: ["Utility"] },
        { name: "Other", icon: "󰘦", matches: [] }
    ]
    readonly property string rawQuery: search.text.trim()
    readonly property string lowerQuery: rawQuery.toLowerCase()
    readonly property string searchMode: lowerQuery.startsWith("file:") ? "file"
        : lowerQuery.startsWith("f:") ? "file"
        : lowerQuery.startsWith("ssh:") ? "ssh"
        : lowerQuery.startsWith("mounts:") ? "mounts" : "applications"
    readonly property int prefixLength: lowerQuery.startsWith("file:") ? 5
        : lowerQuery.startsWith("f:") ? 2
        : lowerQuery.startsWith("ssh:") ? 4
        : lowerQuery.startsWith("mounts:") ? 7 : 0
    readonly property string modeQuery: rawQuery.slice(prefixLength).trim()
    property var providerResults: []
    property bool providerPartial: false
    property string providerError: ""
    property string providerRequest: ""
    property string providerCompletedRequest: ""
    readonly property var results: searchMode === "applications"
        ? applications : providerResults
    readonly property int footerHeight: 44

    function categoryFor(app) {
        const appCategories = app.categories || []
        for (const definition of categoryDefinitions) {
            if (definition.name === "Favorites" || definition.name === "Other")
                continue
            if (definition.matches.some(category =>
                    appCategories.indexOf(category) !== -1))
                return definition.name
        }
        return "Other"
    }

    readonly property var applications: {
        const entries = DesktopEntries.applications.values.filter(app => {
            if (app.noDisplay)
                return false
            if (root.selectedCategory === "Favorites"
                    && !LauncherState.isFavorite(app.id))
                return false
            if (root.selectedCategory !== ""
                    && root.selectedCategory !== "Favorites"
                    && root.categoryFor(app) !== root.selectedCategory)
                return false
            if (root.searchMode !== "applications")
                return false
            if (root.lowerQuery === "")
                return true
            const searchable = [app.name, app.genericName, app.comment]
                .concat(app.keywords).join(" ").toLowerCase()
            return searchable.indexOf(root.lowerQuery) !== -1
        })
        entries.sort((a, b) => a.name.localeCompare(b.name))
        return entries
    }

    function toggle() {
        if (visible)
            visible = false
        else
            showAtAnchor()
    }

    function toggleCentered() {
        if (visible) {
            visible = false
            return
        }
        if (!focusedOutputQuery.running)
            focusedOutputQuery.running = true
    }

    function anchorBelongsTo(rect) {
        if (!anchorItem || !rect)
            return false
        const anchorPosition = anchorItem.mapToGlobal(0, 0)
        return anchorPosition.x >= rect.x
            && anchorPosition.x < rect.x + rect.width
            && anchorPosition.y >= rect.y
            && anchorPosition.y < rect.y + rect.height
    }

    function focusSearch() {
        if (!visible)
            return
        if (_backingWindow)
            _backingWindow.requestActivate()
        search.forceActiveFocus()
    }

    function sshCommand(host) {
        return "ssh '" + host.split("'").join("'\"'\"'") + "'"
    }

    function openSsh(host) {
        const sessionScript =
            "ssh \"$1\"; status=$?; "
            + "if [ \"$status\" -ne 0 ]; then "
            + "printf '\\nSSH exited with status %s. Press Enter to close.\\n' \"$status\"; "
            + "read answer; fi; exit \"$status\""
        const terminalScript =
            "config=${ANUSH_CONFIG_DIR:-${XDG_CONFIG_HOME:-$HOME/.config}/anush/config}; "
            + "if [ -n \"${TERMINAL:-}\" ] && command -v \"$TERMINAL\" >/dev/null 2>&1; then "
            + "if [ \"${TERMINAL##*/}\" = kitty ]; then "
            + "exec \"$TERMINAL\" --config \"$config/kitty/kitty.conf\" -- \"$@\"; "
            + "else exec \"$TERMINAL\" -e \"$@\"; fi; "
            + "elif command -v kitty >/dev/null 2>&1; then "
            + "exec kitty --config \"$config/kitty/kitty.conf\" -- \"$@\"; "
            + "elif command -v foot >/dev/null 2>&1; then exec foot -- \"$@\"; "
            + "elif command -v alacritty >/dev/null 2>&1; then exec alacritty -e \"$@\"; "
            + "elif command -v wezterm >/dev/null 2>&1; then exec wezterm start -- \"$@\"; "
            + "elif command -v xterm >/dev/null 2>&1; then exec xterm -e \"$@\"; "
            + "else command -v notify-send >/dev/null 2>&1 && "
            + "notify-send -u critical 'anush launcher' 'No supported terminal was found.'; exit 127; fi"
        Quickshell.execDetached(["sh", "-c", terminalScript, "anush-ssh-terminal",
            "sh", "-c", sessionScript, "anush-ssh", host])
    }

    function activate(item, copyOnly) {
        if (!item)
            return
        if (searchMode === "applications") {
            visible = false
            item.execute()
            return
        }
        const value = String(item.value ?? "")
        if (value === "") return
        if (copyOnly) {
            Quickshell.clipboardText = item.kind === "ssh"
                ? sshCommand(value) : value
            visible = false
            return
        }
        visible = false
        if (item.kind === "ssh") openSsh(value)
        else Quickshell.execDetached(["xdg-open", value])
    }

    function refreshProvider() {
        if (searchMode === "applications" || (searchMode === "file" && modeQuery === "")) {
            providerResults = []
            providerPartial = false
            providerError = ""
            providerRequest = ""
            providerCompletedRequest = ""
            return
        }
        const signature = searchMode + "\n" + modeQuery
        if (providerQuery.running || signature === providerCompletedRequest)
            return
        providerRequest = signature
        providerError = ""
        providerQuery.command = [Theme.scriptsDir + "/launcher/search-provider",
            searchMode, modeQuery]
        providerQuery.running = true
    }

    onVisibleChanged: {
        if (visible) {
            search.text = ""
            selectedCategory = ""
            appList.currentIndex = applications.length > 0 ? 0 : -1
            appList.positionViewAtBeginning()
            focusAttempts = 0
            Qt.callLater(() => {
                appList.positionViewAtBeginning()
                root.focusSearch()
            })
            focusRetry.start()
        } else {
            // Persist after the popup has closed. Writing ShellState while this
            // window is handling the star click can recreate/hide the popup.
            LauncherState.saveFavorites()
        }
    }

    property int focusAttempts: 0
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

    Timer {
        id: favoriteClickGuard
        interval: 180
        onTriggered: root.suspendOutsideClose = false
    }

    Timer {
        id: providerDebounce
        interval: 120
        onTriggered: root.refreshProvider()
    }

    Connections {
        target: LauncherState
        function onCenteredRequested() { root.toggleCentered() }
    }

    Process {
        id: focusedOutputQuery
        command: [Wm.msgPath, "get-outputs"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const outputs = JSON.parse(text)
                    const focused = outputs.find(output => output.focused === true)
                    if (focused && root.anchorBelongsTo(focused.rect)) {
                        const rect = focused.rect
                        root.showCenteredInRect(
                            rect.x, rect.y, rect.width, rect.height)
                    }
                } catch (error) {
                    console.warn("application launcher output query:", error)
                }
            }
        }
    }


    Process {
        id: providerQuery
        stdout: StdioCollector {
            onStreamFinished: {
                const current = root.searchMode + "\n" + root.modeQuery
                if (root.providerRequest !== current)
                    return
                try {
                    const response = JSON.parse(text)
                    root.providerResults = Array.isArray(response.results)
                        ? response.results : []
                    root.providerPartial = response.partial === true
                    root.providerError = String(response.error ?? "")
                    root.providerCompletedRequest = current
                    appList.currentIndex = root.providerResults.length > 0 ? 0 : -1
                    appList.positionViewAtBeginning()
                } catch (error) {
                    root.providerResults = []
                    root.providerError = "Could not read search results."
                    root.providerCompletedRequest = current
                    console.warn("application launcher provider:", error)
                }
            }
        }
        onExited: exitCode => {
            if (exitCode !== 0 && root.providerRequest
                    === root.searchMode + "\n" + root.modeQuery) {
                root.providerError = "The search provider failed."
                root.providerCompletedRequest = root.providerRequest
            }
            Qt.callLater(() => root.refreshProvider())
        }
    }

    Column {
        anchors.fill: parent
        spacing: 10

        Rectangle {
            width: parent.width
            height: 42
            radius: Theme.radiusMedium
            color: Theme.gray2
            border.width: 1
            border.color: search.activeFocus ? Theme.accent : Theme.gray5

            Row {
                anchors.fill: parent
                anchors.leftMargin: 12
                anchors.rightMargin: 12
                spacing: 10

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "󰍉"
                    color: Theme.accent
                    font.family: Theme.iconFontFamily
                    font.pixelSize: Theme.iconSize
                }

                TextInput {
                    id: search
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width - 40
                    color: Theme.fg
                    selectionColor: Theme.selbg
                    selectedTextColor: Theme.selfg
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSize + 1
                    clip: true

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        visible: search.text.length === 0
                        text: "Search applications, f:, ssh:, or mounts:"
                        color: Theme.brightBlack
                        font: search.font
                    }

                    onTextChanged: {
                        const signature = root.searchMode + "\n" + root.modeQuery
                        if (root.searchMode !== "applications"
                                && signature !== root.providerCompletedRequest) {
                            root.providerResults = []
                            root.providerPartial = false
                            root.providerError = ""
                        }
                        appList.currentIndex = root.results.length > 0 ? 0 : -1
                        appList.positionViewAtBeginning()
                        root.providerRequest = root.searchMode === "applications"
                            ? "" : root.providerRequest
                        providerDebounce.restart()
                    }
                    Keys.onPressed: event => {
                        if (event.key === Qt.Key_Down) {
                            appList.currentIndex = Math.min(appList.count - 1,
                                appList.currentIndex + 1)
                            appList.positionViewAtIndex(appList.currentIndex, ListView.Contain)
                            event.accepted = true
                        } else if (event.key === Qt.Key_Up) {
                            appList.currentIndex = Math.max(0, appList.currentIndex - 1)
                            appList.positionViewAtIndex(appList.currentIndex, ListView.Contain)
                            event.accepted = true
                        } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                            root.activate(root.results[appList.currentIndex],
                                (event.modifiers & Qt.ShiftModifier) !== 0)
                            event.accepted = true
                        }
                    }
                }
            }
        }

        Item {
            id: resultsArea
            width: parent.width
            height: Math.max(0, parent.height - y
                - root.footerHeight - parent.spacing)

            Text {
                anchors.fill: parent
                visible: root.results.length === 0
                text: root.searchMode === "file" && root.modeQuery === ""
                    ? "Type after f: to search files"
                    : root.searchMode !== "applications"
                        && (providerDebounce.running || providerQuery.running) ? "Searching…"
                    : root.providerError !== "" ? root.providerError
                    : root.searchMode !== "applications" ? "No matching results"
                    : root.selectedCategory === "" ? "No matching applications"
                    : "No applications in " + root.selectedCategory
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
                color: Theme.brightBlack
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSize
            }

            ListView {
                id: appList
                anchors.fill: parent
                visible: count > 0
                clip: true
                spacing: 3
                model: root.results
                currentIndex: count > 0 ? 0 : -1

                delegate: Rectangle {
                    id: appRow
                    required property var modelData
                    required property int index
                    readonly property string iconSource: root.searchMode === "applications"
                        && String(modelData.icon ?? "") !== ""
                        ? Quickshell.iconPath(String(modelData.icon), true) : ""

                    width: appList.width
                    height: 52
                    radius: Theme.radiusSmall
                    color: index === appList.currentIndex
                        ? Theme.selbg
                        : rowHover.hovered ? Qt.alpha(Theme.fg, 0.12) : "transparent"
                    border.width: index === appList.currentIndex ? 1 : 0
                    border.color: Theme.brightOrange

                    HoverHandler {
                        id: rowHover
                        onHoveredChanged: {
                            if (hovered) appList.currentIndex = appRow.index
                        }
                    }

                    Row {
                        anchors.fill: parent
                        anchors.leftMargin: 10
                        anchors.rightMargin: root.searchMode === "applications" ? 52 : 10
                        spacing: 12

                        IconImage {
                            anchors.verticalCenter: parent.verticalCenter
                            implicitSize: 32
                            source: appRow.iconSource
                            visible: source.toString() !== ""
                        }

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            width: 32
                            visible: appRow.iconSource === ""
                            horizontalAlignment: Text.AlignHCenter
                            text: root.searchMode === "file" ? "󰈔"
                                : root.searchMode === "ssh" ? "󰣀"
                                : root.searchMode === "mounts" ? "󰋊" : "󰏖"
                            color: appRow.index === appList.currentIndex
                                ? Theme.selfg : Theme.accent
                            font.family: Theme.iconFontFamily
                            font.pixelSize: Theme.iconSize
                        }

                        Column {
                            anchors.verticalCenter: parent.verticalCenter
                            width: parent.width - 44
                            spacing: 2

                            Text {
                                width: parent.width
                                text: String(appRow.modelData.name ?? "")
                                elide: Text.ElideRight
                                color: appRow.index === appList.currentIndex
                                    ? Theme.selfg : Theme.fg
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontSize + 1
                                font.bold: true
                            }

                            Text {
                                width: parent.width
                                visible: text.length > 0
                                text: root.searchMode === "applications"
                                    ? (appRow.modelData.genericName || appRow.modelData.comment)
                                    : String(appRow.modelData.detail ?? "")
                                elide: Text.ElideRight
                                color: appRow.index === appList.currentIndex
                                    ? Qt.alpha(Theme.selfg, 0.75) : Theme.brightBlack
                                font.family: Theme.fontFamily
                                font.pixelSize: Math.max(10, Theme.fontSize - 1)
                            }
                        }
                    }

                    Rectangle {
                        id: favoriteButton
                        anchors.right: parent.right
                        anchors.rightMargin: 10
                        anchors.verticalCenter: parent.verticalCenter
                        width: 32
                        height: 32
                        z: 2
                        readonly property bool favorite:
                            LauncherState.isFavorite(appRow.modelData.id)
                        visible: root.searchMode === "applications" && rowHover.hovered
                        radius: Theme.radiusSmall
                        color: favoriteMouse.containsMouse
                            ? favorite ? Qt.alpha(Theme.brightOrange, 0.28)
                                : Theme.gray3
                            : appRow.index === appList.currentIndex
                            ? Qt.alpha(Theme.selfg, 0.16) : Theme.gray2
                        border.width: 1
                        border.color: favorite ? Theme.brightOrange
                            : appRow.index === appList.currentIndex
                            ? Qt.alpha(Theme.selfg, 0.55) : Theme.gray5

                        Text {
                            anchors.centerIn: parent
                            text: "󰓎"
                            color: favoriteButton.favorite
                                ? Theme.brightOrange
                                : appRow.index === appList.currentIndex
                                ? Theme.selfg : Theme.cyan
                            font.family: Theme.iconFontFamily
                            font.pixelSize: Theme.iconSize
                        }

                        MouseArea {
                            id: favoriteMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            onEntered: appList.currentIndex = appRow.index
                            onPressed: mouse => {
                                root.suspendOutsideClose = true
                                // Start the failsafe immediately. Removing an
                                // item in Favorites destroys this delegate, so
                                // no delegate event may arrive afterward.
                                favoriteClickGuard.restart()
                                mouse.accepted = true
                            }
                            onClicked: mouse => {
                                // Arm the root-owned timer before changing the
                                // model in case this row disappears instantly.
                                favoriteClickGuard.restart()
                                LauncherState.toggleFavorite(appRow.modelData.id)
                                mouse.accepted = true
                            }
                            onCanceled: favoriteClickGuard.restart()
                        }

                        Controls.ToolTip.visible: favoriteMouse.containsMouse
                        Controls.ToolTip.delay: 350
                        Controls.ToolTip.text: favorite
                            ? "Remove from Favorites" : "Add to Favorites"
                    }

                    MouseArea {
                        id: rowMouse
                        anchors.left: parent.left
                        anchors.top: parent.top
                        anchors.right: parent.right
                        anchors.rightMargin: root.searchMode === "applications" ? 52 : 0
                        anchors.bottom: parent.bottom
                        z: 1
                        acceptedButtons: Qt.LeftButton
                        onClicked: root.activate(appRow.modelData, false)
                    }
                }

                Controls.ScrollBar.vertical: Controls.ScrollBar {
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
                        color: parent.pressed ? Theme.brightOrange
                             : parent.hovered ? Theme.orange : Theme.gray6
                        radius: Math.min(width / 2, Theme.radiusSmall)

                        Behavior on color { ColorAnimation { duration: 100 } }
                    }
                }
            }
        }

        Rectangle {
            id: categoryBar
            width: parent.width
            height: root.searchMode === "applications" ? root.footerHeight : 0
            visible: height > 0
            radius: Theme.radiusMedium
            color: Theme.gray2
            border.width: 1
            border.color: Theme.gray5

            Row {
                anchors.centerIn: parent
                spacing: 4

                Repeater {
                    model: root.categoryDefinitions

                    delegate: Rectangle {
                        id: categoryButton
                        required property var modelData
                        readonly property bool selected:
                            root.selectedCategory === modelData.name
                        width: 48
                        height: 34
                        radius: Theme.radiusSmall
                        color: selected ? Theme.selbg
                            : categoryMouse.containsMouse
                            ? Qt.alpha(Theme.fg, 0.12) : "transparent"
                        border.width: selected ? 1 : 0
                        border.color: Theme.brightOrange

                        Text {
                            anchors.centerIn: parent
                            text: categoryButton.modelData.icon
                            color: categoryButton.selected
                                ? Theme.selfg : Theme.accent
                            font.family: Theme.iconFontFamily
                            font.pixelSize: Theme.iconSize
                        }

                        MouseArea {
                            id: categoryMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            onClicked: {
                                root.selectedCategory = categoryButton.selected
                                    ? "" : categoryButton.modelData.name
                                appList.currentIndex = root.applications.length > 0 ? 0 : -1
                                appList.positionViewAtBeginning()
                                root.focusSearch()
                            }
                        }

                        Controls.ToolTip.visible: categoryMouse.containsMouse
                        Controls.ToolTip.delay: 350
                        Controls.ToolTip.text: categoryButton.modelData.name
                    }
                }
            }
        }


        Rectangle {
            width: parent.width
            height: root.searchMode !== "applications" ? root.footerHeight : 0
            visible: height > 0
            radius: Theme.radiusMedium
            color: Theme.gray2
            border.width: 1
            border.color: Theme.gray5

            Text {
                anchors.centerIn: parent
                text: (root.searchMode === "file"
                    ? "Files · plocate + fd · Enter opens"
                    : root.searchMode === "ssh"
                    ? "SSH hosts · Enter connects · Shift+Enter copies"
                    : "Mounted filesystems · Enter opens · Shift+Enter copies")
                    + (root.providerPartial ? " · partial results" : "")
                color: root.providerPartial ? Theme.brightOrange : Theme.brightBlack
                font.family: Theme.fontFamily
                font.pixelSize: Math.max(10, Theme.fontSize - 1)
            }
        }
    }
}
