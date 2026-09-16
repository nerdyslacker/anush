pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls as Controls
import "../.."

Popout {
    id: root

    cardWidth: 790
    cardHeight: content.implicitHeight + 2 * cardPadding
    alignRight: true

    component ToggleSwitch: Rectangle {
        id: control
        property bool checked: false
        signal toggled

        width: 34
        height: 18
        radius: Math.min(height / 2, Theme.radiusSmall)
        color: checked ? Theme.accent : Qt.alpha(Theme.fg, 0.15)
        Behavior on color {
            ColorAnimation {
                duration: 150
            }
        }

        Rectangle {
            x: control.checked ? parent.width - width - 2 : 2
            anchors.verticalCenter: parent.verticalCenter
            width: 14
            height: 14
            radius: Math.min(width / 2, Theme.radiusSmall)
            color: control.checked ? Theme.bg : Qt.alpha(Theme.fg, 0.7)
            Behavior on x {
                NumberAnimation {
                    duration: 150
                    easing.type: Easing.OutCubic
                }
            }
        }

        MouseArea {
            anchors.fill: parent
            onClicked: control.toggled()
        }
    }

    component CompactSetting: Rectangle {
        id: setting
        required property string iconText
        required property string title
        required property string detail
        property bool checked: false
        signal toggled

        height: 48
        radius: Theme.radiusMedium
        color: "transparent"
        border.width: 1
        border.color: Theme.gray5

        Text {
            id: settingIcon
            anchors.left: parent.left
            anchors.leftMargin: 8
            anchors.verticalCenter: parent.verticalCenter
            text: setting.iconText
            color: Theme.accent
            font.family: Theme.fontFamily
            font.pixelSize: 15
        }

        Column {
            anchors.left: settingIcon.right
            anchors.leftMargin: 7
            anchors.right: settingSwitch.left
            anchors.rightMargin: 7
            anchors.verticalCenter: parent.verticalCenter
            spacing: 0
            Text {
                text: setting.title
                color: Theme.fg
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSize - 1
            }
            Text {
                text: setting.detail
                color: Theme.brightBlack
                font.family: Theme.fontFamily
                font.pixelSize: Math.max(8, Theme.fontSize - 3)
            }
        }

        ToggleSwitch {
            id: settingSwitch
            anchors.right: parent.right
            anchors.rightMargin: 8
            anchors.verticalCenter: parent.verticalCenter
            checked: setting.checked
            onToggled: setting.toggled()
        }
    }

    component WidgetRow: Rectangle {
        id: widgetRow
        required property string widgetKey
        readonly property var info: BarVisibility.metadata(widgetKey)
        readonly property bool isEnabled: BarVisibility.enabled(widgetKey)
        readonly property bool mandatory: info && info.mandatory === true
        property bool dragging: false

        width: parent.width
        height: 36
        radius: Theme.radiusSmall
        color: dragging ? Qt.alpha(Theme.accent, 0.22) : Qt.alpha(Theme.fg, 0.045)
        border.width: 1
        border.color: dragging ? Theme.accent : Theme.gray5
        z: dragging ? 100 : 1
        opacity: dragging ? 0.82 : 1

        DragHandler {
            id: dragHandler
            target: dragProxy
            acceptedButtons: Qt.LeftButton
            onActiveChanged: {
                if (active) {
                    widgetRow.dragging = true;
                } else if (widgetRow.dragging) {
                    dragProxy.Drag.drop();
                    widgetRow.dragging = false;
                    dragProxy.x = 0;
                    dragProxy.y = 0;
                }
            }
        }

        // A free-moving proxy keeps the source row in its Column while giving
        // Qt's drag system real scene coordinates across all three sections.
        Item {
            id: dragProxy
            property string widgetKey: widgetRow.widgetKey
            x: 0
            y: 0
            width: widgetRow.width
            height: widgetRow.height
            z: 200

            Drag.active: widgetRow.dragging
            Drag.source: dragProxy
            Drag.keys: ["bar-widget"]
            Drag.hotSpot.x: width / 2
            Drag.hotSpot.y: height / 2
            Drag.supportedActions: Qt.MoveAction

            Rectangle {
                anchors.fill: parent
                radius: Theme.radiusSmall
                visible: widgetRow.dragging
                color: Theme.gray2
                border.width: 2
                border.color: Theme.accent
                Text {
                    anchors.centerIn: parent
                    text: widgetRow.info ? widgetRow.info.label : widgetRow.widgetKey
                    color: Theme.fg
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSize - 1
                }
            }
        }

        Text {
            id: handle
            anchors.left: parent.left
            anchors.leftMargin: 7
            anchors.verticalCenter: parent.verticalCenter
            text: "󰇙"
            color: widgetRow.dragging ? Theme.accent : Theme.gray6
            font.family: Theme.fontFamily
            font.pixelSize: 13
        }

        Text {
            id: widgetIcon
            anchors.left: handle.right
            anchors.leftMargin: 7
            anchors.verticalCenter: parent.verticalCenter
            text: widgetRow.info ? widgetRow.info.icon : ""
            color: widgetRow.isEnabled ? Theme.cyan : Theme.brightBlack
            font.family: Theme.fontFamily
            font.pixelSize: 15
        }

        Text {
            anchors.left: widgetIcon.right
            anchors.leftMargin: 7
            anchors.right: widgetRow.mandatory ? parent.right : widgetSwitch.left
            anchors.rightMargin: 7
            anchors.verticalCenter: parent.verticalCenter
            text: widgetRow.info ? widgetRow.info.label : widgetRow.widgetKey
            elide: Text.ElideRight
            color: widgetRow.isEnabled ? Theme.fg : Theme.brightBlack
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSize - 1
        }

        ToggleSwitch {
            id: widgetSwitch
            anchors.right: parent.right
            anchors.rightMargin: 7
            anchors.verticalCenter: parent.verticalCenter
            checked: widgetRow.isEnabled
            visible: !widgetRow.mandatory
            onToggled: BarVisibility.setEnabled(widgetRow.widgetKey, !widgetRow.isEnabled)
        }
    }

    component ClusterSection: Column {
        id: section
        required property string clusterName
        required property string heading
        width: (parent.width - 16) / 3
        spacing: 6

        Row {
            width: parent.width
            height: 24
            spacing: 7
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: section.clusterName === "left" ? "󰁍" : section.clusterName === "center" ? "󰘖" : "󰁔"
                color: Theme.accent
                font.family: Theme.fontFamily
                font.pixelSize: 15
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: section.heading
                color: Theme.fg
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSize
                font.bold: true
            }
        }

        Rectangle {
            id: dropPanel
            width: parent.width
            height: Math.max(64, rows.implicitHeight + 8)
            radius: Theme.radiusMedium
            color: dropArea.containsDrag ? Qt.alpha(Theme.accent, 0.09) : "transparent"
            border.width: 1
            border.color: dropArea.containsDrag ? Theme.accent : Theme.gray5
            Behavior on color {
                ColorAnimation {
                    duration: 100
                }
            }
            Behavior on border.color {
                ColorAnimation {
                    duration: 100
                }
            }

            Column {
                id: rows
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.margins: 4
                spacing: 4

                Repeater {
                    model: BarVisibility.cluster(section.clusterName)
                    WidgetRow {
                        required property string modelData
                        widgetKey: modelData
                    }
                }
            }

            Text {
                anchors.centerIn: parent
                visible: rows.children.length === 1
                text: "Drop widgets here"
                color: Theme.gray6
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSize - 2
            }

            DropArea {
                id: dropArea
                anchors.fill: parent
                keys: ["bar-widget"]
                onDropped: drop => {
                    const source = drop.source;
                    if (!source || source.widgetKey === undefined)
                        return;
                    const rowPitch = 40;
                    const index = Math.round(Math.max(0, drop.y - 4) / rowPitch);
                    BarVisibility.moveWidget(source.widgetKey, section.clusterName, index);
                    drop.acceptProposedAction();
                }
            }
        }
    }

    Column {
        id: content
        anchors.left: parent.left
        anchors.right: parent.right
        spacing: 9

        Text {
            text: "Bar layout"
            color: Theme.fg
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSize + 1
            font.bold: true
        }

        Text {
            text: "Drag widgets between sections or within a section to reorder them"
            color: Theme.brightBlack
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSize - 1
        }

        Row {
            id: barOptions
            width: parent.width
            height: 48
            spacing: 8

            Controls.ComboBox {
                id: positionSelector
                width: (barOptions.width - barOptions.spacing * 4) / 5
                height: parent.height
                textRole: "label"
                model: [
                    {
                        key: "top",
                        label: "Top"
                    },
                    {
                        key: "bottom",
                        label: "Bottom"
                    },
                    {
                        key: "left",
                        label: "Left"
                    },
                    {
                        key: "right",
                        label: "Right"
                    }
                ]
                currentIndex: ["top", "bottom", "left", "right"].indexOf(BarVisibility.barPosition)
                onActivated: index => BarVisibility.setBarPosition(positionSelector.model[index].key)

                delegate: Controls.ItemDelegate {
                    id: positionOption
                    required property int index
                    required property var modelData
                    width: positionSelector.width - 8
                    height: 30
                    highlighted: positionSelector.highlightedIndex === index

                    contentItem: Text {
                        leftPadding: 7
                        text: positionOption.modelData.label
                        color: positionOption.highlighted || positionOption.index === positionSelector.currentIndex ? Theme.accent : Theme.fg
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSize - 1
                        verticalAlignment: Text.AlignVCenter
                    }
                    background: Rectangle {
                        radius: Theme.radiusSmall
                        color: positionOption.highlighted ? Theme.gray3 : positionOption.index === positionSelector.currentIndex ? Qt.alpha(Theme.accent, 0.16) : "transparent"
                    }
                }

                popup: Controls.Popup {
                    y: positionSelector.height + 4
                    width: positionSelector.width
                    implicitHeight: positionList.contentHeight + 8
                    padding: 4

                    contentItem: ListView {
                        id: positionList
                        clip: true
                        implicitHeight: contentHeight
                        model: positionSelector.popup.visible ? positionSelector.delegateModel : null
                        currentIndex: positionSelector.highlightedIndex
                    }
                    background: Rectangle {
                        radius: Theme.radiusMedium
                        color: Theme.gray2
                        border.width: 1
                        border.color: Theme.gray5
                    }
                }

                contentItem: Text {
                    leftPadding: 10
                    rightPadding: 25
                    text: "Position · " + positionSelector.displayText
                    color: Theme.fg
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSize - 1
                    verticalAlignment: Text.AlignVCenter
                    elide: Text.ElideRight
                }

                indicator: Text {
                    x: positionSelector.width - width - 9
                    y: (positionSelector.height - height) / 2
                    text: positionSelector.popup.visible ? "󰅀" : "󰅂"
                    color: Theme.brightBlack
                    font.family: Theme.fontFamily
                    font.pixelSize: 13
                }

                background: Rectangle {
                    radius: Theme.radiusMedium
                    color: positionSelector.pressed ? Theme.gray4 : positionSelector.hovered ? Theme.gray3 : "transparent"
                    border.width: 1
                    border.color: positionSelector.popup.visible ? Theme.accent : Theme.gray5
                }
            }

            CompactSetting {
                width: (barOptions.width - barOptions.spacing * 4) / 5
                iconText: "󰍹"
                title: "Monitors"
                detail: BarVisibility.showOnAllMonitors ? "All" : "Main only"
                checked: BarVisibility.showOnAllMonitors
                onToggled: BarVisibility.setShowOnAllMonitors(!BarVisibility.showOnAllMonitors)
            }

            CompactSetting {
                width: (barOptions.width - barOptions.spacing * 4) / 5
                iconText: "󰘖"
                title: "Fit content"
                detail: BarVisibility.fitContent ? "Compact" : BarVisibility.verticalBar ? "Full height" : "Full width"
                checked: BarVisibility.fitContent
                onToggled: BarVisibility.setFitContent(!BarVisibility.fitContent)
            }

            CompactSetting {
                width: (barOptions.width - barOptions.spacing * 4) / 5
                iconText: "󰖝"
                title: "Floating"
                detail: BarVisibility.floating ? Theme.surfaceGap + " px inset" : "Flush"
                checked: BarVisibility.floating
                onToggled: BarVisibility.setFloating(!BarVisibility.floating)
            }

            CompactSetting {
                width: (barOptions.width - barOptions.spacing * 4) / 5
                iconText: "󰧞"
                title: "Sections"
                detail: BarVisibility.fitContent ? "Full bar only" : BarVisibility.separateSections ? "3 pillows" : "Joined"
                checked: BarVisibility.separateSections
                onToggled: BarVisibility.setSeparateSections(!BarVisibility.separateSections)
            }
        }

        Row {
            id: appearanceControls
            width: parent.width
            height: 40
            spacing: 14

            TweakSlider {
                width: (appearanceControls.width - appearanceControls.spacing * 2) / 3
                label: "Height"
                from: 28
                to: 80
                value: Theme.barHeight
                suffix: " px"
                applyFn: value => Theme.barHeight = value
                persistFn: value => Theme.persistBarHeight(value)
            }

            TweakSlider {
                width: (appearanceControls.width - appearanceControls.spacing * 2) / 3
                label: "Item scale"
                from: 0.7
                to: 2.0
                value: Theme.barUserScale
                isInt: false
                suffix: "×"
                applyFn: value => Theme.barUserScale = value
                persistFn: value => Theme.persistBarScale(value)
            }

            TweakSlider {
                width: (appearanceControls.width - appearanceControls.spacing * 2) / 3
                label: "Background opacity"
                from: 0
                to: 100
                value: Math.round(Theme.barBackgroundOpacity * 100)
                suffix: "%"
                applyFn: value => Theme.barBackgroundOpacity = value / 100
                persistFn: value => Theme.persistBarBackgroundOpacity(value / 100)
            }
        }

        Row {
            width: parent.width
            spacing: 8
            ClusterSection {
                clusterName: "left"
                heading: BarVisibility.verticalBar ? "Top" : "Left"
            }
            ClusterSection {
                clusterName: "center"
                heading: "Center"
            }
            ClusterSection {
                clusterName: "right"
                heading: BarVisibility.verticalBar ? "Bottom" : "Right"
            }
        }
    }
}
