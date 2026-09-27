import QtQuick
import "../.."
import QtQuick.Controls as Controls
import Quickshell
import Quickshell.Io
import Quickshell.Widgets

// Searchable application launcher backed by the system's .desktop entries.
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
    readonly property string query: search.text.trim().toLowerCase()

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
            if (root.query === "")
                return true
            const searchable = [app.name, app.genericName, app.comment]
                .concat(app.keywords).join(" ").toLowerCase()
            return searchable.indexOf(root.query) !== -1
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

    function launch(app) {
        if (!app)
            return
        visible = false
        app.execute()
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
                        text: "Search applications"
                        color: Theme.brightBlack
                        font: search.font
                    }

                    onTextChanged: {
                        appList.currentIndex = root.applications.length > 0 ? 0 : -1
                        appList.positionViewAtBeginning()
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
                            root.launch(root.applications[appList.currentIndex])
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
                - categoryBar.height - parent.spacing)

            Text {
                anchors.fill: parent
                visible: root.applications.length === 0
                text: root.selectedCategory === ""
                    ? "No matching applications"
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
                model: root.applications
                currentIndex: count > 0 ? 0 : -1

                delegate: Rectangle {
                    id: appRow
                    required property var modelData
                    required property int index
                    readonly property string iconSource: String(modelData.icon ?? "") !== ""
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
                        anchors.rightMargin: 52
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
                            text: "󰏖"
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
                                text: appRow.modelData.name
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
                                text: appRow.modelData.genericName || appRow.modelData.comment
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
                        visible: rowHover.hovered
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
                        anchors.rightMargin: 52
                        anchors.bottom: parent.bottom
                        z: 1
                        acceptedButtons: Qt.LeftButton
                        onClicked: root.launch(appRow.modelData)
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
            height: 44
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
    }
}
