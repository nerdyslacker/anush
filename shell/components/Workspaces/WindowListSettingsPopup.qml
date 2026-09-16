import QtQuick
import "../.."

Popout {
    id: root

    cardWidth: 330
    cardHeight: 58 + 2 * cardPadding

    Connections {
        target: ShellState
        function onStateChanged() {
            root.visible = false;
        }
    }

    Rectangle {
        anchors.fill: parent
        radius: Theme.radiusMedium
        color: "transparent"

        Text {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            text: "Show windows from all monitors"
            color: Theme.fg
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSize
        }

        Rectangle {
            id: toggle
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            width: 34
            height: 18
            radius: Math.min(height / 2, Theme.radiusSmall)
            color: WindowListState.showWindowsFromAllMonitors ? Theme.accent : Qt.alpha(Theme.fg, 0.15)

            Rectangle {
                x: WindowListState.showWindowsFromAllMonitors ? parent.width - width - 2 : 2
                anchors.verticalCenter: parent.verticalCenter
                width: 14
                height: 14
                radius: Math.min(width / 2, Theme.radiusSmall)
                color: WindowListState.showWindowsFromAllMonitors ? Theme.bg : Qt.alpha(Theme.fg, 0.7)
                Behavior on x {
                    NumberAnimation {
                        duration: 150
                        easing.type: Easing.OutCubic
                    }
                }
            }

            Behavior on color {
                ColorAnimation {
                    duration: 150
                }
            }
        }

        MouseArea {
            anchors.fill: parent
            onClicked: WindowListState.setShowWindowsFromAllMonitors(!WindowListState.showWindowsFromAllMonitors)
        }
    }
}
