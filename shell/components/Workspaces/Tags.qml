pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls as Controls
import "../.."

Rectangle {
    id: root
    property var barScreen
    visible: Wm.connected && Wm.capabilities.workspaces === true
    enabled: visible
    readonly property string outputName: Wm.outputNameForScreen(barScreen)
    readonly property bool implicitWorkspaces:
        Wm.capabilities.implicitWorkspaces === true
    readonly property int availableTagCount: implicitWorkspaces
        ? Math.max(TagConfig.count, Wm.tagCount) : Wm.tagCount
    readonly property int totalTagCount: TagConfig.dynamicWorkspaces
        ? (implicitWorkspaces ? Wm.dynamicTagCount
            : Math.min(Wm.dynamicTagCount, availableTagCount))
        : availableTagCount
    readonly property int displayedTagCount: TagConfig.limitVisibleTags
        ? Math.min(totalTagCount, TagConfig.visibleTagLimit) : totalTagCount
    readonly property int pageTagCount: Math.max(0, Math.min(displayedTagCount,
        totalTagCount - pageStart))
    readonly property bool navigationVisible: displayedTagCount < totalTagCount
    property int pageStart: 0
    readonly property int activeTagIndex: {
        for (const ws of Wm.workspaces) {
            if ((Wm.capabilities.perScreenWorkspaces !== true && ws.focused)
                    || (!outputName && ws.focused)
                    || (outputName && String(ws.screenId) === outputName && ws.visible))
                return Math.max(0, Number(ws.index) || 0)
        }
        return 0
    }

    implicitWidth: BarVisibility.verticalBar ? Theme.moduleHeight
        : pager.implicitWidth + 8
    implicitHeight: BarVisibility.verticalBar ? pager.implicitHeight + 8
        : Theme.moduleHeight
    radius: Math.min(height / 2, Theme.radiusMedium)
    color: Theme.barSurface(0.07)
    border.width: 1
    border.color: Theme.gray5

    WheelHandler {
        onWheel: event => Wm.cycleTag(
            event.angleDelta.y > 0 ? -1 : 1, root.totalTagCount, root.outputName)
    }

    function clampPage() {
        if (displayedTagCount >= totalTagCount) {
            pageStart = 0
            return
        }
        const lastPage = Math.max(0,
            Math.floor((totalTagCount - 1) / displayedTagCount) * displayedTagCount)
        pageStart = Math.max(0, Math.min(pageStart, lastPage))
    }

    function revealTag(index) {
        if (index < pageStart || index >= pageStart + displayedTagCount)
            pageStart = Math.floor(index / displayedTagCount) * displayedTagCount
        clampPage()
    }

    function changePage(direction) {
        pageStart += direction * displayedTagCount
        clampPage()
    }

    onTotalTagCountChanged: clampPage()
    onDisplayedTagCountChanged: {
        pageStart = Math.floor(activeTagIndex / displayedTagCount)
            * displayedTagCount
        clampPage()
    }
    onActiveTagIndexChanged: revealTag(activeTagIndex)

    Grid {
        id: pager
        anchors.centerIn: parent
        columns: BarVisibility.verticalBar ? 1 : 3
        spacing: 4

        component NavigationButton: Rectangle {
            id: navigation
            required property string symbol
            required property bool forward

            visible: root.navigationVisible
            enabled: forward
                ? root.pageStart + root.displayedTagCount < root.totalTagCount
                : root.pageStart > 0
            width: BarVisibility.verticalBar ? Theme.moduleHeight - 8 : 20
            height: BarVisibility.verticalBar ? 20 : Theme.moduleHeight - 8
            radius: Math.min(height / 2, Theme.radiusSmall)
            color: pointer.containsMouse && enabled ? Theme.gray4
                : Theme.barSurface(enabled ? 0.06 : 0.025)

            Text {
                anchors.centerIn: parent
                text: navigation.symbol
                color: navigation.enabled ? Theme.fg : Theme.brightBlack
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSize + 3
                font.bold: true
            }

            MouseArea {
                id: pointer
                anchors.fill: parent
                hoverEnabled: true
                enabled: navigation.enabled
                onClicked: root.changePage(navigation.forward ? 1 : -1)
            }
        }

        NavigationButton {
            symbol: BarVisibility.verticalBar ? "⌃" : "‹"
            forward: false
        }

        Grid {
            id: tagGrid
            columns: BarVisibility.verticalBar ? 1 : root.pageTagCount
            spacing: 4

            Repeater {
                model: root.pageTagCount
                Rectangle {
                    id: tag
                    required property int index
                    readonly property int tagIndex: root.pageStart + index
                    readonly property bool selected: Wm.isSelected(tagIndex, root.outputName)
                    readonly property bool occupied: Wm.isOccupied(tagIndex, root.outputName)
                    readonly property bool urgent: Wm.isUrgent(tagIndex, root.outputName)
                    readonly property string workspaceIcon: Wm.workspaceIcon(tagIndex)
                    readonly property string workspaceName: Wm.workspaceName(tagIndex)
                    width: BarVisibility.verticalBar ? Theme.moduleHeight - 8
                        : selected ? 28 : 22
                    height: BarVisibility.verticalBar
                        ? selected ? 28 : 22 : Theme.moduleHeight - 8
                    radius: Math.min(height / 2, Theme.radiusMedium)
                    color: urgent ? Theme.red
                        : selected ? Theme.accent
                        : Theme.barSurface(occupied ? 0.08 : 0.035)

                    Behavior on width { NumberAnimation { duration: 160 } }
                    Behavior on height { NumberAnimation { duration: 160 } }
                    Behavior on color { ColorAnimation { duration: 160 } }

                    Text {
                        anchors.centerIn: parent
                        visible: TagConfig.showNumbers || tag.workspaceIcon !== ""
                        text: tag.workspaceIcon !== "" ? tag.workspaceIcon : tag.tagIndex + 1
                        color: tag.selected || tag.urgent
                            ? Theme.accentForeground
                            : Qt.alpha(Theme.foreground,
                                tag.occupied ? 0.62 : 0.34)
                        font.family: Theme.fontFamily
                        font.pixelSize: tag.workspaceIcon !== "" ? Theme.fontSize + 2 : Theme.fontSize - 1
                        font.bold: tag.selected
                    }

                    Rectangle {
                        visible: !TagConfig.showNumbers && tag.workspaceIcon === ""
                        anchors.centerIn: parent
                        width: tag.selected || tag.urgent ? 5 : 4
                        height: width
                        radius: width / 2
                        color: tag.selected || tag.urgent
                            ? Theme.accentForeground
                            : Qt.alpha(Theme.fg, tag.occupied ? 0.50 : 0.24)
                    }
                    MouseArea {
                        id: pointer
                        anchors.fill: parent
                        hoverEnabled: true
                        acceptedButtons: Qt.LeftButton | Qt.MiddleButton
                            | Qt.RightButton
                        onClicked: mouse => {
                            if (mouse.button === Qt.RightButton) {
                                settings.visible = !settings.visible
                            } else if (mouse.button === Qt.MiddleButton) {
                                Wm.sendToTag(tag.tagIndex)
                            } else {
                                Wm.viewTag(tag.tagIndex, root.outputName)
                            }
                        }
                    }
                    ThemedToolTip {
                        id: workspaceTooltip
                        parent: tag
                        visible: pointer.containsMouse && tag.workspaceName !== ""
                        text: tag.workspaceName
                        delay: 350
                        popupType: Controls.Popup.Window
                        x: BarVisibility.verticalBar
                            ? (BarVisibility.barPosition === "left"
                                ? tag.width + 6 : -width - 6)
                            : (tag.width - width) / 2
                        y: BarVisibility.verticalBar
                            ? (tag.height - height) / 2
                            : BarVisibility.barPosition === "bottom"
                                ? -height - 6 : tag.height + 6
                    }
                }
            }
        }

        NavigationButton {
            symbol: BarVisibility.verticalBar ? "⌄" : "›"
            forward: true
        }
    }

    TagSettingsPopup {
        id: settings
        anchorItem: root
    }
}
