pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls as Controls
import "../.."

Popout {
    id: root

    property bool settingsOpen: false
    property string filter: "all"
    property string errorText: ""
    property int refreshDraft: 15
    property int maxItemsDraft: 100
    readonly property var visibleArticles: RssService.articles.filter(article => {
        if (root.filter === "unread" && article.read === true)
            return false;
        const needle = searchInput.text.trim().toLocaleLowerCase();
        return needle === "" || String(article.title ?? "").toLocaleLowerCase().includes(needle) || String(article.feed ?? "").toLocaleLowerCase().includes(needle) || String(article.summary ?? "").toLocaleLowerCase().includes(needle);
    })

    cardWidth: 570
    cardHeight: 650
    alignRight: true

    function formatDate(value) {
        const date = new Date(String(value ?? ""));
        if (isNaN(date.getTime()))
            return "";
        return date.toLocaleString(Qt.locale(), Locale.ShortFormat);
    }

    function syncDraft() {
        feedModel.clear();
        for (const feed of RssService.feeds)
            feedModel.append({
                name: String(feed.name ?? ""),
                url: String(feed.url ?? "")
            });
        refreshDraft = RssService.refreshMinutes;
        maxItemsDraft = RssService.maxItems;
        errorText = "";
    }

    function openSettings() {
        syncDraft();
        settingsOpen = true;
        visible = true;
    }

    function addFeed() {
        feedModel.append({
            name: "",
            url: ""
        });
    }

    function removeFeed(index) {
        feedModel.remove(index);
    }

    function updateFeed(index, key, value) {
        feedModel.setProperty(index, key, value);
    }

    function saveSettings() {
        const clean = [];
        const seen = ({});
        for (let index = 0; index < feedModel.count; ++index) {
            const feed = feedModel.get(index);
            const url = String(feed.url ?? "").trim();
            const name = String(feed.name ?? "").trim();
            if (!/^https?:\/\/[^\s]+$/i.test(url)) {
                errorText = "Every feed needs a valid http(s) URL.";
                return;
            }
            const key = url.toLowerCase().replace(/\/$/, "");
            if (seen[key]) {
                errorText = "Each feed URL must be unique.";
                return;
            }
            seen[key] = true;
            clean.push({
                name: name,
                url: url
            });
        }
        RssService.saveSettings(clean, refreshDraft, maxItemsDraft);
        settingsOpen = false;
    }

    onVisibleChanged: {
        RssService.popupVisible = visible;
        if (visible) {
            PopupCoordinator.requestOpen("rss", root);
            RssService.initialize();
        } else {
            settingsOpen = false;
            errorText = "";
        }
    }

    Connections {
        target: PopupCoordinator
        function onOpening(name, owner) {
            if (owner !== root)
                root.visible = false;
        }
    }

    ListModel {
        id: feedModel
    }

    component ActionButton: Rectangle {
        id: button
        required property string label
        property string glyph: ""
        property bool primary: false
        property color accentColor: Theme.accent
        signal activated

        implicitWidth: buttonText.implicitWidth + (glyph !== "" ? 34 : 20)
        height: 30
        radius: Theme.radiusSmall
        color: primary ? accentColor : buttonMouse.containsMouse ? Qt.alpha(accentColor, 0.2) : Theme.gray2
        border.width: 1
        border.color: primary ? Theme.brightOrange : Qt.alpha(accentColor, 0.65)
        opacity: enabled ? 1 : 0.45

        Row {
            anchors.centerIn: parent
            spacing: 6
            Text {
                visible: button.glyph !== ""
                text: button.glyph
                color: button.primary ? Theme.selfg : button.accentColor
                font.family: Theme.iconFontFamily
                font.pixelSize: Theme.iconSizeSmall
            }
            Text {
                id: buttonText
                text: button.label
                color: button.primary ? Theme.selfg : Theme.fg
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSize - 1
                font.bold: button.primary
            }
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
        spacing: 10

        Row {
            id: header
            width: parent.width
            height: 32
            spacing: 8

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: ""
                color: Theme.orange
                font.family: Theme.iconFontFamily
                font.pixelSize: Theme.iconSizeLarge
            }
            Column {
                width: parent.width - x - headerActions.width - parent.spacing
                anchors.verticalCenter: parent.verticalCenter
                spacing: 0
                Text {
                    text: root.settingsOpen ? "RSS feed settings" : "RSS reader"
                    color: Theme.fg
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSize + 2
                    font.bold: true
                }
                Text {
                    visible: !root.settingsOpen
                    text: RssService.tooltip
                    color: Theme.brightBlack
                    font.family: Theme.fontFamily
                    font.pixelSize: Math.max(8, Theme.fontSize - 3)
                }
            }
            Row {
                id: headerActions
                spacing: 6
                anchors.verticalCenter: parent.verticalCenter
                ActionButton {
                    visible: !root.settingsOpen
                    label: RssService.loading ? "Updating…" : "Refresh"
                    glyph: "󰑓"
                    enabled: !RssService.loading && RssService.feeds.length > 0
                    onActivated: RssService.refresh()
                }
                ActionButton {
                    label: root.settingsOpen ? "Back" : "Feeds"
                    glyph: root.settingsOpen ? "󰁍" : "󰒓"
                    onActivated: {
                        if (root.settingsOpen)
                            root.settingsOpen = false;
                        else
                            root.openSettings();
                    }
                }
            }
        }

        Item {
            visible: !root.settingsOpen
            width: parent.width
            height: parent.height - y

            Rectangle {
                id: searchBox
                anchors.left: parent.left
                anchors.right: filters.left
                anchors.rightMargin: 8
                anchors.top: parent.top
                height: 36
                radius: Theme.radiusSmall
                color: Theme.gray2
                border.width: 1
                border.color: searchInput.activeFocus ? Theme.accent : Theme.gray5

                TextInput {
                    id: searchInput
                    anchors.fill: parent
                    anchors.leftMargin: 10
                    anchors.rightMargin: 10
                    verticalAlignment: TextInput.AlignVCenter
                    color: Theme.fg
                    selectionColor: Theme.selbg
                    selectedTextColor: Theme.selfg
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSize
                    clip: true
                    Text {
                        visible: searchInput.text === ""
                        anchors.verticalCenter: parent.verticalCenter
                        text: "Search articles"
                        color: Theme.brightBlack
                        font: searchInput.font
                    }
                }
            }

            Row {
                id: filters
                anchors.right: parent.right
                anchors.top: parent.top
                height: 36
                spacing: 5
                Repeater {
                    model: [
                        {
                            label: "All",
                            value: "all"
                        },
                        {
                            label: "Unread",
                            value: "unread"
                        }
                    ]
                    Rectangle {
                        required property var modelData
                        width: filterLabel.implicitWidth + 18
                        height: 36
                        radius: Theme.radiusSmall
                        color: root.filter === modelData.value ? Theme.accent : Theme.gray2
                        border.width: 1
                        border.color: root.filter === modelData.value ? Theme.brightOrange : Theme.gray5
                        Text {
                            id: filterLabel
                            anchors.centerIn: parent
                            text: parent.modelData.label
                            color: root.filter === parent.modelData.value ? Theme.selfg : Theme.fg
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSize - 1
                            font.bold: root.filter === parent.modelData.value
                        }
                        MouseArea {
                            anchors.fill: parent
                            onClicked: root.filter = parent.modelData.value
                        }
                    }
                }
            }

            Row {
                id: listMeta
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: searchBox.bottom
                anchors.topMargin: 9
                height: 24
                Text {
                    width: parent.width - markAll.width
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.visibleArticles.length + (root.visibleArticles.length === 1 ? " ARTICLE" : " ARTICLES")
                    color: Theme.accent
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSize - 2
                    font.bold: true
                }
                ActionButton {
                    id: markAll
                    visible: RssService.unreadCount > 0
                    label: "Mark all read"
                    height: 24
                    onActivated: RssService.markAllRead()
                }
            }

            Text {
                id: statusText
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: listMeta.bottom
                visible: RssService.error !== "" || RssService.feedErrors.length > 0
                text: RssService.error !== "" ? RssService.error : RssService.feedErrors.length + " feed(s) could not be updated"
                color: Theme.red
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSize - 2
                elide: Text.ElideRight
            }

            ListView {
                id: articleList
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: statusText.visible ? statusText.bottom : listMeta.bottom
                anchors.topMargin: 5
                anchors.bottom: footer.top
                anchors.bottomMargin: 6
                clip: true
                spacing: 6
                model: root.visibleArticles
                boundsBehavior: Flickable.StopAtBounds

                Controls.ScrollBar.vertical: Controls.ScrollBar {
                    id: articleScrollBar
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
                        color: articleScrollBar.pressed ? Theme.brightOrange : articleScrollBar.hovered ? Theme.orange : Theme.gray6
                    }
                }

                Text {
                    anchors.centerIn: parent
                    visible: articleList.count === 0
                    width: Math.min(360, parent.width)
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.WordWrap
                    text: RssService.feeds.length === 0 ? "No feeds configured. Open Feeds to add one." : RssService.loading ? "Updating feeds…" : root.filter === "unread" ? "No unread articles" : "No matching articles"
                    color: Theme.brightBlack
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSize
                }

                delegate: Rectangle {
                    id: articleRow
                    required property var modelData
                    width: articleList.width - (articleScrollBar.visible ? 12 : 0)
                    height: 94
                    radius: Theme.radiusMedium
                    color: articleMouse.containsMouse ? Theme.gray3 : Theme.gray2
                    border.width: 1
                    border.color: modelData.read === true ? Theme.gray5 : Theme.accent

                    Rectangle {
                        anchors.left: parent.left
                        anchors.top: parent.top
                        anchors.bottom: parent.bottom
                        width: 3
                        radius: Theme.radiusSmall
                        color: articleRow.modelData.read === true ? "transparent" : Theme.orange
                    }

                    Column {
                        anchors.fill: parent
                        anchors.leftMargin: 12
                        anchors.rightMargin: 10
                        anchors.topMargin: 8
                        anchors.bottomMargin: 7
                        spacing: 4
                        Text {
                            width: parent.width
                            text: articleRow.modelData.title
                            color: Theme.fg
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSize
                            font.bold: articleRow.modelData.read !== true
                            elide: Text.ElideRight
                        }
                        Text {
                            width: parent.width
                            text: String(articleRow.modelData.feed ?? "") + (root.formatDate(articleRow.modelData.published) !== "" ? " · " + root.formatDate(articleRow.modelData.published) : "")
                            color: Theme.accent
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSize - 2
                            elide: Text.ElideRight
                        }
                        Text {
                            width: parent.width
                            text: String(articleRow.modelData.summary ?? "")
                            color: Theme.brightBlack
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSize - 2
                            maximumLineCount: 2
                            wrapMode: Text.Wrap
                            elide: Text.ElideRight
                        }
                    }
                    MouseArea {
                        id: articleMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: RssService.openArticle(articleRow.modelData)
                    }
                }
            }

            Text {
                id: footer
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                text: RssService.lastUpdated !== "" ? "Last updated " + root.formatDate(RssService.lastUpdated) : "Not updated yet"
                color: Theme.brightBlack
                font.family: Theme.fontFamily
                font.pixelSize: Math.max(8, Theme.fontSize - 3)
                horizontalAlignment: Text.AlignRight
            }
        }

        Item {
            visible: root.settingsOpen
            width: parent.width
            height: parent.height - y

            Text {
                id: settingsIntro
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                text: "Add RSS or Atom URLs. Feeds refresh only while this widget is enabled."
                color: Theme.brightBlack
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSize - 1
                wrapMode: Text.WordWrap
            }

            Flickable {
                id: feedFlick
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: settingsIntro.bottom
                anchors.topMargin: 10
                height: Math.min(365, feedColumn.implicitHeight)
                contentWidth: width
                contentHeight: feedColumn.implicitHeight
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                Controls.ScrollBar.vertical: Controls.ScrollBar {
                    id: feedScrollBar
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
                        color: feedScrollBar.pressed ? Theme.brightOrange : feedScrollBar.hovered ? Theme.orange : Theme.gray6
                    }
                }

                Column {
                    id: feedColumn
                    width: feedFlick.width - (feedScrollBar.visible ? 12 : 0)
                    spacing: 7

                    Repeater {
                        model: feedModel
                        Rectangle {
                            id: feedRow
                            required property int index
                            required property string name
                            required property string url
                            width: feedColumn.width
                            height: 82
                            radius: Theme.radiusMedium
                            color: Theme.gray2
                            border.width: 1
                            border.color: Theme.gray5

                            Rectangle {
                                id: nameBox
                                anchors.left: parent.left
                                anchors.leftMargin: 8
                                anchors.right: removeButton.left
                                anchors.rightMargin: 7
                                anchors.top: parent.top
                                anchors.topMargin: 7
                                height: 30
                                radius: Theme.radiusSmall
                                color: Theme.gray1
                                border.width: 1
                                border.color: nameInput.activeFocus ? Theme.accent : Theme.gray5
                                TextInput {
                                    id: nameInput
                                    anchors.fill: parent
                                    anchors.leftMargin: 8
                                    anchors.rightMargin: 8
                                    verticalAlignment: TextInput.AlignVCenter
                                    text: feedRow.name
                                    color: Theme.fg
                                    selectionColor: Theme.selbg
                                    selectedTextColor: Theme.selfg
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.fontSize - 1
                                    onTextEdited: root.updateFeed(feedRow.index, "name", text)
                                    Text {
                                        visible: nameInput.text === ""
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: "Optional feed name"
                                        color: Theme.brightBlack
                                        font: nameInput.font
                                    }
                                }
                            }

                            ActionButton {
                                id: removeButton
                                anchors.right: parent.right
                                anchors.rightMargin: 8
                                anchors.top: nameBox.top
                                label: "Remove"
                                accentColor: Theme.red
                                onActivated: root.removeFeed(feedRow.index)
                            }

                            Rectangle {
                                anchors.left: nameBox.left
                                anchors.right: parent.right
                                anchors.rightMargin: 8
                                anchors.top: nameBox.bottom
                                anchors.topMargin: 7
                                height: 30
                                radius: Theme.radiusSmall
                                color: Theme.gray1
                                border.width: 1
                                border.color: urlInput.activeFocus ? Theme.accent : Theme.gray5
                                TextInput {
                                    id: urlInput
                                    anchors.fill: parent
                                    anchors.leftMargin: 8
                                    anchors.rightMargin: 8
                                    verticalAlignment: TextInput.AlignVCenter
                                    text: feedRow.url
                                    color: Theme.fg
                                    selectionColor: Theme.selbg
                                    selectedTextColor: Theme.selfg
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.fontSize - 1
                                    clip: true
                                    onTextEdited: root.updateFeed(feedRow.index, "url", text)
                                    Text {
                                        visible: urlInput.text === ""
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: "https://example.com/feed.xml"
                                        color: Theme.brightBlack
                                        font: urlInput.font
                                    }
                                }
                            }
                        }
                    }
                }
            }

            ActionButton {
                id: addFeedButton
                anchors.left: parent.left
                anchors.top: feedFlick.bottom
                anchors.topMargin: 8
                label: "Add feed"
                glyph: "+"
                onActivated: root.addFeed()
            }

            Row {
                id: numericSettings
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: addFeedButton.bottom
                anchors.topMargin: 12
                height: 52
                spacing: 10

                Column {
                    width: (parent.width - parent.spacing) / 2
                    spacing: 4
                    Text {
                        text: "Refresh interval (minutes)"
                        color: Theme.brightBlack
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSize - 2
                    }
                    Rectangle {
                        width: parent.width
                        height: 31
                        radius: Theme.radiusSmall
                        color: Theme.gray2
                        border.width: 1
                        border.color: refreshInput.activeFocus ? Theme.accent : Theme.gray5
                        TextInput {
                            id: refreshInput
                            anchors.fill: parent
                            anchors.leftMargin: 8
                            verticalAlignment: TextInput.AlignVCenter
                            text: String(root.refreshDraft)
                            inputMethodHints: Qt.ImhDigitsOnly
                            validator: IntValidator {
                                bottom: 1
                                top: 1440
                            }
                            color: Theme.fg
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSize
                            onTextEdited: if (acceptableInput)
                                root.refreshDraft = Number(text)
                        }
                    }
                }
                Column {
                    width: (parent.width - parent.spacing) / 2
                    spacing: 4
                    Text {
                        text: "Articles shown"
                        color: Theme.brightBlack
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSize - 2
                    }
                    Rectangle {
                        width: parent.width
                        height: 31
                        radius: Theme.radiusSmall
                        color: Theme.gray2
                        border.width: 1
                        border.color: maxItemsInput.activeFocus ? Theme.accent : Theme.gray5
                        TextInput {
                            id: maxItemsInput
                            anchors.fill: parent
                            anchors.leftMargin: 8
                            verticalAlignment: TextInput.AlignVCenter
                            text: String(root.maxItemsDraft)
                            inputMethodHints: Qt.ImhDigitsOnly
                            validator: IntValidator {
                                bottom: 10
                                top: 500
                            }
                            color: Theme.fg
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSize
                            onTextEdited: if (acceptableInput)
                                root.maxItemsDraft = Number(text)
                        }
                    }
                }
            }

            Text {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: numericSettings.bottom
                anchors.topMargin: 7
                visible: root.errorText !== ""
                text: root.errorText
                color: Theme.red
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSize - 1
                wrapMode: Text.WordWrap
            }

            Row {
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                spacing: 8
                ActionButton {
                    label: "Cancel"
                    onActivated: root.settingsOpen = false
                }
                ActionButton {
                    label: "Save feeds"
                    primary: true
                    onActivated: root.saveSettings()
                }
            }
        }
    }
}
