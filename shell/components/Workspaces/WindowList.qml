pragma ComponentBehavior: Bound

import QtQuick
import Quickshell.Widgets
import "../.."

// One tags-style wrapper contains one icon per application. Multi-window
// groups open a picker; single-window groups focus directly.
Rectangle {
    id: root

    property var barScreen
    readonly property string outputName: String(barScreen?.name ?? "")
    readonly property int workspace: {
        for (const output of Wm.outputs)
            if (String(output.name) === outputName)
                return Number(output.current_workspace);
        return -1;
    }
    readonly property var appGroups: WindowListState.groupsFor(outputName, workspace)
    property string selectedGroupKey: ""
    readonly property var selectedGroup: {
        for (const group of appGroups)
            if (group.key === selectedGroupKey)
                return group;
        return null;
    }
    readonly property real itemExtent: Theme.moduleHeight - 4
    readonly property real itemSpacing: Math.round(3 * Theme.barScale)
    readonly property real naturalContentExtent: appGroups.length > 0 ? appGroups.length * itemExtent + (appGroups.length - 1) * itemSpacing : 0
    readonly property real screenExtent: BarVisibility.verticalBar ? Number(barScreen?.height ?? 0) : Number(barScreen?.width ?? 0)
    readonly property real maximumContentExtent: Math.max(itemExtent, screenExtent > 0 ? Math.round(screenExtent * 0.32) : naturalContentExtent)
    readonly property real contentExtent: Math.min(naturalContentExtent, maximumContentExtent)

    visible: appGroups.length > 0
    implicitWidth: BarVisibility.verticalBar ? Theme.moduleHeight : contentExtent + 4
    implicitHeight: BarVisibility.verticalBar ? contentExtent + 4 : Theme.moduleHeight
    radius: Math.min(height / 2, Theme.radiusMedium)
    color: Theme.barSurface(0.04)
    border.width: 1
    border.color: Theme.gray5

    function openSettings() {
        groupPopup.visible = false;
        settings.visible = !settings.visible;
    }

    function activateGroup(group, anchor) {
        settings.visible = false;
        if (group.windows.length === 1) {
            if (!group.windows[0].active)
                Wm.focusWindow(group.windows[0].id);
            return;
        }
        selectedGroupKey = group.key;
        groupPopup.anchorItem = anchor;
        groupPopup.showAtAnchor();
    }

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.RightButton
        onClicked: root.openSettings()
    }

    component ApplicationIcon: Item {
        id: iconButton
        required property var modelData
        width: root.itemExtent
        height: root.itemExtent

        Rectangle {
            anchors.fill: parent
            radius: Math.min(height / 2, Theme.radiusSmall)
            color: iconMouse.pressed ? Theme.barSurface(0.18) : iconMouse.containsMouse ? Theme.barSurface(0.12) : "transparent"
            border.width: iconButton.modelData.urgent ? 1 : 0
            border.color: Theme.error
            opacity: iconButton.modelData.minimized ? 0.55 : 1

            Behavior on color {
                ColorAnimation {
                    duration: 120
                }
            }
            Behavior on opacity {
                NumberAnimation {
                    duration: 120
                }
            }

            IconImage {
                anchors.centerIn: parent
                implicitSize: Theme.iconSize
                source: iconButton.modelData.iconSource
            }

            Rectangle {
                visible: iconButton.modelData.windows.length > 1
                anchors.right: parent.right
                anchors.top: parent.top
                width: 12
                height: 12
                radius: Math.min(width / 2, Theme.radiusSmall)
                color: Qt.alpha(iconButton.modelData.active ? Theme.accent : Theme.gray5, 0.8)

                Text {
                    anchors.centerIn: parent
                    text: iconButton.modelData.windows.length > 9 ? "9+" : iconButton.modelData.windows.length
                    color: iconButton.modelData.active ? Theme.accentForeground : Theme.fg
                    font.family: Theme.fontFamily
                    font.pixelSize: 8
                    font.bold: true
                }
            }

            Rectangle {
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 1
                width: iconButton.modelData.active ? Math.round(parent.width * 0.55) : 4
                height: iconButton.modelData.active ? 2 : 0
                radius: Math.min(height / 2, Theme.radiusSmall)
                color: iconButton.modelData.urgent ? Theme.error : Theme.accent
                Behavior on width {
                    NumberAnimation {
                        duration: 140
                    }
                }
                Behavior on height {
                    NumberAnimation {
                        duration: 140
                    }
                }
            }
        }

        MouseArea {
            id: iconMouse
            anchors.fill: parent
            hoverEnabled: true
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            onClicked: mouse => {
                if (mouse.button === Qt.RightButton)
                    root.openSettings();
                else
                    root.activateGroup(iconButton.modelData, iconButton);
            }
        }
    }

    Flickable {
        id: horizontalList
        visible: !BarVisibility.verticalBar
        anchors.centerIn: parent
        width: root.contentExtent
        height: root.itemExtent
        contentWidth: windowRow.implicitWidth
        contentHeight: height
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        flickableDirection: Flickable.HorizontalFlick

        Row {
            id: windowRow
            spacing: root.itemSpacing
            Repeater {
                model: horizontalList.visible ? root.appGroups : []
                ApplicationIcon {}
            }
        }

        WheelHandler {
            onWheel: event => horizontalList.contentX = Math.max(0, Math.min(horizontalList.contentWidth - horizontalList.width, horizontalList.contentX - event.angleDelta.y / 2))
        }
    }

    Flickable {
        id: verticalList
        visible: BarVisibility.verticalBar
        anchors.centerIn: parent
        width: root.itemExtent
        height: root.contentExtent
        contentWidth: width
        contentHeight: windowColumn.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        flickableDirection: Flickable.VerticalFlick

        Column {
            id: windowColumn
            spacing: root.itemSpacing
            Repeater {
                model: verticalList.visible ? root.appGroups : []
                ApplicationIcon {}
            }
        }
    }

    WindowListSettingsPopup {
        id: settings
        anchorItem: root
    }

    WindowGroupPopup {
        id: groupPopup
        group: root.selectedGroup
    }
}
