pragma ComponentBehavior: Bound

import QtQuick
import Quickshell.Widgets
import "../.."

Popout {
    id: root

    property var group: null
    readonly property var windowEntries: group && Array.isArray(group.windows) ? group.windows : []

    cardWidth: 360
    cardHeight: Math.min(420, 34 + windowEntries.length * 44 + Math.max(0, windowEntries.length - 1) * 4 + 2 * cardPadding)

    onGroupChanged: {
        if (visible && windowEntries.length < 2)
            visible = false;
    }

    Column {
        anchors.fill: parent
        spacing: 8

        Row {
            width: parent.width
            height: 26
            spacing: 9

            IconImage {
                anchors.verticalCenter: parent.verticalCenter
                implicitSize: 20
                source: root.group ? root.group.iconSource : ""
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width - 29
                text: root.group ? root.group.appName : "Windows"
                color: Theme.fg
                elide: Text.ElideRight
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSize
                font.bold: true
            }
        }

        ListView {
            id: windowList
            width: parent.width
            height: parent.height - y
            spacing: 4
            clip: true
            model: root.windowEntries

            delegate: Rectangle {
                id: windowRow
                required property var modelData

                width: windowList.width
                height: 44
                radius: Theme.radiusSmall
                color: rowMouse.pressed ? Theme.pressed : rowMouse.containsMouse ? Theme.hover : "transparent"
                border.width: modelData.active || modelData.urgent ? 1 : 0
                border.color: modelData.urgent ? Theme.error : Theme.accent

                Behavior on color {
                    ColorAnimation {
                        duration: 100
                    }
                }

                IconImage {
                    id: rowIcon
                    anchors.left: parent.left
                    anchors.leftMargin: 8
                    anchors.verticalCenter: parent.verticalCenter
                    implicitSize: Theme.iconSize
                    source: windowRow.modelData.iconSource
                    opacity: windowRow.modelData.minimized ? 0.55 : 1
                }

                Column {
                    anchors.left: rowIcon.right
                    anchors.leftMargin: 9
                    anchors.right: parent.right
                    anchors.rightMargin: 8
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 1

                    Text {
                        width: parent.width
                        text: windowRow.modelData.title
                        color: Theme.fg
                        elide: Text.ElideRight
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSize
                    }

                    Text {
                        width: parent.width
                        text: windowRow.modelData.output + (windowRow.modelData.active ? " · Active" : "")
                        color: windowRow.modelData.active ? Theme.accent : Theme.foregroundMuted
                        elide: Text.ElideRight
                        font.family: Theme.fontFamily
                        font.pixelSize: Math.max(8, Theme.fontSize - 2)
                    }
                }

                MouseArea {
                    id: rowMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    onClicked: {
                        if (!windowRow.modelData.active)
                            Wm.focusWindow(windowRow.modelData.id);
                        root.visible = false;
                    }
                }
            }
        }
    }
}
