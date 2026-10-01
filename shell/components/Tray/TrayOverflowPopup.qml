pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls as Controls
import "../.."
import Quickshell
import Quickshell.Services.SystemTray
import Quickshell.Widgets

// Compact access to tray items hidden from the bar. Placement is managed from
// the full tray popup, which remains available on the arrow's right click.
Popout {
    id: root

    property var items: []
    readonly property int cellSize: Math.round(30 * Theme.barScale)

    cardWidth: hiddenGrid.implicitWidth + 2 * cardPadding
    cardHeight: hiddenGrid.implicitHeight + 2 * cardPadding

    onItemsChanged: if (visible && items.length === 0) visible = false

    Grid {
        id: hiddenGrid
        anchors.centerIn: parent
        columns: Math.min(5, Math.max(1, root.items.length))
        spacing: 4

        Repeater {
            model: root.items

            MouseArea {
                id: trayItem
                required property SystemTrayItem modelData

                width: root.cellSize
                height: root.cellSize
                hoverEnabled: true
                acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton

                Rectangle {
                    anchors.fill: parent
                    radius: Theme.radiusSmall
                    color: trayItem.containsMouse ? Theme.gray3 : Theme.gray2
                    border.width: 1
                    border.color: trayItem.containsMouse ? Theme.accent : Theme.gray5
                }

                IconImage {
                    anchors.centerIn: parent
                    implicitSize: Math.round(16 * Theme.barScale)
                    source: trayItem.modelData.icon
                }

                QsMenuAnchor {
                    id: menuAnchor
                    menu: trayItem.modelData.menu
                    anchor.item: trayItem
                    anchor.rect.y: trayItem.height
                }

                onClicked: mouse => {
                    if (mouse.button === Qt.LeftButton) {
                        if (modelData.onlyMenu && modelData.hasMenu) {
                            menuAnchor.open()
                        } else {
                            modelData.activate()
                            root.visible = false
                        }
                    } else if (mouse.button === Qt.MiddleButton) {
                        modelData.secondaryActivate()
                        root.visible = false
                    } else if (modelData.hasMenu) {
                        menuAnchor.open()
                    }
                }

                Controls.ToolTip.visible: containsMouse
                Controls.ToolTip.delay: 450
                Controls.ToolTip.text: modelData.title || modelData.tooltipTitle
                    || modelData.id || "Tray application"
            }
        }
    }
}
