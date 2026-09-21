pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls as Controls
import "../.."

// Layout and appearance controls adapted to skarwm. Layout selection applies
// to the focused window/column; desktop gap and all visual choices persist.
Popout {
    id: root

    readonly property var accents: Theme.accentNames

    cardWidth: 360
    cardHeight: content.implicitHeight + 2 * cardPadding

    onVisibleChanged: if (visible) AppearanceService.refresh()

    Connections {
        target: ShellActions
        function onLayoutsRequested(action) {
            if (action === "toggle"
                    && ShellActions.ownsFocusedOutput(root.anchorItem))
                root.visible = !root.visible
        }
    }

    component SectionLabel: Text {
        color: Theme.accent
        font.family: Theme.fontFamily
        font.pixelSize: 12
        font.bold: true
        topPadding: 5
    }

    component SettingSwitch: Rectangle {
        id: control
        property bool checked: false
        signal toggled()

        width: 34
        height: 18
        radius: Math.min(height / 2, Theme.radiusSmall)
        color: checked ? Theme.activeBackground
            : Qt.alpha(Theme.foreground, 0.15)
        Behavior on color { ColorAnimation { duration: 150 } }

        Rectangle {
            x: control.checked ? parent.width - width - 2 : 2
            anchors.verticalCenter: parent.verticalCenter
            width: 14
            height: 14
            radius: Math.min(width / 2, Theme.radiusSmall)
            color: control.checked ? Theme.background
                : Qt.alpha(Theme.foreground, 0.7)
            Behavior on x {
                NumberAnimation { duration: 150; easing.type: Easing.OutCubic }
            }
        }

        MouseArea {
            anchors.fill: parent
            onClicked: control.toggled()
        }
    }

    component ActionButton: Rectangle {
        id: actionButton
        required property string label
        signal clicked()

        height: 32
        radius: Theme.radiusSmall
        color: !enabled ? Theme.surfaceSubtle
            : actionMouse.containsMouse ? Theme.surfaceVariant : Theme.surface
        border.width: 1
        border.color: actionMouse.containsMouse ? Theme.accent : Theme.outline
        opacity: enabled ? 1 : 0.55

        Text {
            anchors.centerIn: parent
            text: actionButton.label
            color: Theme.foreground
            font.family: Theme.fontFamily
            font.pixelSize: Math.max(9, Theme.fontSize - 1)
            font.bold: true
        }

        MouseArea {
            id: actionMouse
            anchors.fill: parent
            enabled: actionButton.enabled
            hoverEnabled: true
            onClicked: actionButton.clicked()
        }
    }

    component ThemeSelector: Controls.ComboBox {
        id: selector
        required property string selectedValue
        signal selected(string value)

        width: parent.width
        height: 34
        currentIndex: model.indexOf(selectedValue)
        displayText: selectedValue !== "" ? selectedValue : "Detecting system theme…"
        leftPadding: 10
        rightPadding: 34

        contentItem: Text {
            text: selector.displayText
            color: Theme.foreground
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSize
            verticalAlignment: Text.AlignVCenter
            elide: Text.ElideRight
        }

        indicator: Text {
            x: selector.width - width - 10
            anchors.verticalCenter: parent.verticalCenter
            text: "󰅀"
            color: Theme.accent
            font.family: Theme.iconFontFamily
            font.pixelSize: Theme.iconSizeSmall
        }

        background: Rectangle {
            radius: Theme.radiusSmall
            color: selector.pressed ? Theme.pressed : Theme.surface
            border.width: 1
            border.color: selector.popup.visible ? Theme.accent : Theme.outline
        }

        delegate: Controls.ItemDelegate {
            id: option
            required property var modelData
            required property int index
            width: selector.width
            height: 32
            highlighted: selector.highlightedIndex === index

            contentItem: Text {
                text: option.modelData
                color: option.highlighted ? Theme.selfg : Theme.foreground
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSize - 1
                verticalAlignment: Text.AlignVCenter
                elide: Text.ElideRight
            }
            background: Rectangle {
                color: option.highlighted ? Theme.activeBackground
                    : option.hovered ? Theme.hover : Theme.surface
            }
        }

        popup: Controls.Popup {
            y: selector.height + 3
            width: selector.width
            implicitHeight: Math.min(contentItem.implicitHeight + 2, 230)
            padding: 1

            contentItem: ListView {
                clip: true
                implicitHeight: contentHeight
                model: selector.popup.visible ? selector.delegateModel : null
                currentIndex: selector.highlightedIndex
                Controls.ScrollIndicator.vertical: Controls.ScrollIndicator {}
            }
            background: Rectangle {
                radius: Theme.radiusSmall
                color: Theme.surface
                border.width: 1
                border.color: Theme.outline
            }
        }

        onActivated: index => selected(String(model[index]))
    }

    Column {
        id: content
        anchors.left: parent.left
        anchors.right: parent.right
        spacing: 7

        SectionLabel { text: "Focused layout" }

        Grid {
            id: layoutGrid
            width: parent.width
            columns: 3
            spacing: 5

            Repeater {
                model: Wm.layouts

                Rectangle {
                    id: layoutTile
                    required property var modelData
                    required property int index
                    readonly property bool current: Wm.layoutIndex === index

                    width: (layoutGrid.width - 10) / 3
                    height: 52
                    radius: Theme.radiusSmall
                    color: current ? Theme.selbg
                        : layoutMouse.containsMouse ? Qt.alpha(Theme.fg, 0.12)
                        : Qt.alpha(Theme.fg, 0.05)
                    border.width: 1
                    border.color: current ? Theme.accent : Theme.gray5
                    Behavior on color { ColorAnimation { duration: 120 } }

                    Column {
                        anchors.centerIn: parent
                        spacing: 2
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: layoutTile.modelData.glyph
                            color: layoutTile.current ? Theme.selfg : Theme.cyan
                            font.family: Theme.iconFontFamily
                            font.pixelSize: Theme.iconSize
                        }
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: layoutTile.modelData.name
                            color: layoutTile.current ? Theme.selfg : Theme.fg
                            font.family: Theme.fontFamily
                            font.pixelSize: 10
                            font.bold: layoutTile.current
                        }
                    }

                    MouseArea {
                        id: layoutMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        onClicked: Wm.setLayout(layoutTile.index)
                    }
                }
            }
        }

        SectionLabel { text: "Desktop" }

        TweakSlider {
            label: "window gap"
            from: 0
            to: 40
            value: Wm.gaps
            suffix: " px"
            applyFn: value => Wm.setGaps(value, false)
            persistFn: value => Wm.persistGaps(value)
        }

        TweakSlider {
            label: "corner radius"
            from: 0
            to: 24
            value: Theme.cornerRadius
            suffix: " px"
            applyFn: value => Theme.cornerRadius = Math.max(0, Math.round(value))
            persistFn: value => Theme.persistCornerRadius(value)
        }

        Item {
            width: parent.width
            height: 25

            SectionLabel {
                text: "Theme preset"
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                topPadding: 0
            }

            Row {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                spacing: 7

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Dark"
                    color: Theme.light ? Theme.foregroundMuted : Theme.accent
                    font.family: Theme.fontFamily
                    font.pixelSize: Math.max(9, Theme.fontSize - 2)
                    font.bold: !Theme.light
                }

                SettingSwitch {
                    anchors.verticalCenter: parent.verticalCenter
                    checked: Theme.light
                    onToggled: Theme.persistThemeMode(
                        Theme.light ? "dark" : "light")
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Light"
                    color: Theme.light ? Theme.accent : Theme.foregroundMuted
                    font.family: Theme.fontFamily
                    font.pixelSize: Math.max(9, Theme.fontSize - 2)
                    font.bold: Theme.light
                }
            }
        }

        GridView {
            id: themeGrid
            width: parent.width
            height: cellHeight * 2
            cellWidth: (width - 8) / 3
            cellHeight: 57
            clip: true
            model: Theme.themePresets
            boundsBehavior: Flickable.StopAtBounds
            flickableDirection: Flickable.VerticalFlick

            Controls.ScrollBar.vertical: Controls.ScrollBar {
                id: themeScrollbar
                width: 8
                policy: themeGrid.contentHeight > themeGrid.height
                    ? Controls.ScrollBar.AsNeeded : Controls.ScrollBar.AlwaysOff
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
                    color: themeScrollbar.pressed ? Theme.brightOrange
                        : themeScrollbar.hovered ? Theme.orange : Theme.gray6
                    radius: Math.min(width / 2, Theme.radiusSmall)

                    Behavior on color { ColorAnimation { duration: 100 } }
                }
            }

            delegate: Item {
                id: themeCell
                required property var modelData
                width: themeGrid.cellWidth
                height: themeGrid.cellHeight

                Rectangle {
                    id: themeTile
                    readonly property bool current:
                        Theme.presetId === themeCell.modelData.id

                    anchors.fill: parent
                    anchors.rightMargin: 5
                    anchors.bottomMargin: 5
                    radius: Theme.radiusSmall
                    color: current ? Theme.activeBackground
                        : themeMouse.containsMouse ? Theme.gray3 : Theme.gray2
                    border.width: current ? 2 : 1
                    border.color: current ? Theme.activeBorder : Theme.gray5

                    Column {
                        anchors.centerIn: parent
                        spacing: 5

                        Row {
                            anchors.horizontalCenter: parent.horizontalCenter
                            spacing: 3
                            Repeater {
                                model: themeCell.modelData.preview
                                Rectangle {
                                    required property string modelData
                                    width: 20
                                    height: 12
                                    radius: Math.min(3, Theme.radiusSmall)
                                    color: modelData
                                    border.width: 1
                                    border.color: Qt.alpha(Theme.fg, 0.35)
                                }
                            }
                        }

                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            width: themeTile.width - 8
                            horizontalAlignment: Text.AlignHCenter
                            elide: Text.ElideRight
                            text: themeCell.modelData.name
                            color: themeTile.current ? Theme.selfg : Theme.fg
                            font.family: Theme.fontFamily
                            font.pixelSize: 9
                            font.bold: themeTile.current
                        }
                    }

                    MouseArea {
                        id: themeMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        onClicked: Theme.setThemePreset(themeCell.modelData.id)
                    }
                }
            }
        }

        SectionLabel { text: "Accent color" }

        Grid {
            id: accentGrid
            width: parent.width
            columns: 7
            spacing: 4

            Repeater {
                model: root.accents

                Rectangle {
                    id: swatch
                    required property string modelData
                    readonly property bool current:
                        Theme.accentName === modelData
                    readonly property color swatchColor:
                        Theme.mutedAccentColor(modelData)

                    width: (accentGrid.width - accentGrid.spacing * 6) / 7
                    height: 31
                    radius: Theme.radiusSmall
                    color: swatchMouse.containsMouse
                        ? Theme.gray3 : Theme.gray2
                    border.width: swatch.current ? 2 : 1
                    border.color: swatch.current
                        ? swatch.swatchColor : Theme.gray5

                    Rectangle {
                        anchors.fill: parent
                        anchors.margins: swatch.current ? 5 : 6
                        radius: Theme.radiusSmall
                        color: swatch.swatchColor
                        border.width: 1
                        border.color: Qt.alpha(Theme.fg, 0.35)
                    }

                    MouseArea {
                        id: swatchMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        onClicked: Theme.setAccent(swatch.modelData)
                    }
                }
            }
        }

        SectionLabel { text: "Icon theme" }

        ThemeSelector {
            selectedValue: AppearanceService.iconTheme
            model: AppearanceService.iconThemes
            onSelected: value => AppearanceService.setIconTheme(value)
        }

        Text {
            width: parent.width
            text: "Folder colors follow the accent when the selected theme supports it."
            color: Theme.foregroundMuted
            font.family: Theme.fontFamily
            font.pixelSize: Math.max(8, Theme.fontSize - 2)
            wrapMode: Text.WordWrap
        }

        SectionLabel { text: "Cursor theme" }

        ThemeSelector {
            selectedValue: AppearanceService.cursorTheme
            model: AppearanceService.cursorThemes
            onSelected: value => AppearanceService.setCursorTheme(value)
        }

        SectionLabel {
            text: "Application themes"
        }

        Row {
            width: parent.width
            spacing: 6

            ActionButton {
                width: (parent.width - parent.spacing) / 2
                label: "Apply GTK Themes"
                enabled: Theme.matugenThemeGenerated
                    && !Theme.applicationThemeApplying
                onClicked: Theme.applyApplicationTheme("gtk")
            }

            ActionButton {
                width: (parent.width - parent.spacing) / 2
                label: "Apply Qt Themes"
                enabled: Theme.matugenThemeGenerated
                    && !Theme.applicationThemeApplying
                onClicked: Theme.applyApplicationTheme("qt")
            }
        }

        Text {
            width: parent.width
            text: Theme.applicationThemeStatus !== ""
                ? Theme.applicationThemeStatus
                : Theme.matugenThemeGenerated
                    ? "Install adw-gtk-theme (adw-gtk3) for GTK theming. Qt applications need Qt5ct or Qt6ct."
                    : "Generate a wallpaper palette with Matugen to enable application themes."
            color: Theme.foregroundMuted
            font.family: Theme.fontFamily
            font.pixelSize: Math.max(8, Theme.fontSize - 2)
            wrapMode: Text.WordWrap
        }        
    }
}
