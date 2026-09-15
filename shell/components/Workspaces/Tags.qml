pragma ComponentBehavior: Bound

import QtQuick
import "../.."

Rectangle {
    id: root
    readonly property int visibleTagCount: TagConfig.dynamicWorkspaces
        ? Wm.dynamicTagCount : Math.max(TagConfig.count, Wm.tagCount)

    implicitWidth: BarVisibility.verticalBar ? Theme.moduleHeight
        : tagGrid.implicitWidth + 8
    implicitHeight: BarVisibility.verticalBar ? tagGrid.implicitHeight + 8
        : Theme.moduleHeight
    radius: Math.min(height / 2, Theme.radiusMedium)
    color: Theme.barSurface(0.07)
    border.width: 1
    border.color: Theme.gray5

    WheelHandler {
        onWheel: event => Wm.cycleTag(
            event.angleDelta.y > 0 ? -1 : 1, root.visibleTagCount)
    }

    Grid {
        id: tagGrid
        anchors.centerIn: parent
        columns: BarVisibility.verticalBar ? 1
            : root.visibleTagCount
        spacing: 4

        Repeater {
            model: root.visibleTagCount
            Rectangle {
                id: tag
                required property int index
                readonly property bool selected: Wm.isSelected(index)
                readonly property bool occupied: Wm.isOccupied(index)
                readonly property bool urgent: Wm.isUrgent(index)
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
                    visible: TagConfig.showNumbers
                    text: tag.index + 1
                    color: tag.selected || tag.urgent
                        ? Theme.accentForeground
                        : Qt.alpha(Theme.foreground, tag.occupied ? 0.62 : 0.34)
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSize - 1
                    font.bold: tag.selected
                }

                Rectangle {
                    visible: !TagConfig.showNumbers
                    anchors.centerIn: parent
                    width: tag.selected || tag.urgent ? 5 : 4
                    height: width
                    radius: width / 2
                    color: tag.selected || tag.urgent
                        ? Theme.accentForeground
                        : Qt.alpha(Theme.fg, tag.occupied ? 0.50 : 0.24)
                }
                MouseArea {
                    anchors.fill: parent
                    acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton
                    onClicked: mouse => {
                        if (mouse.button === Qt.RightButton) {
                            settings.visible = !settings.visible
                        } else if (mouse.button === Qt.MiddleButton) {
                            Wm.sendToTag(tag.index)
                        } else {
                            Wm.viewTag(tag.index)
                        }
                    }
                }
            }
        }
    }

    TagSettingsPopup {
        id: settings
        anchorItem: root
    }
}
