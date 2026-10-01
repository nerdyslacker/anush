pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls as Controls
import "../.."

Popout {
    id: root

    property int selectedSection: 0
    readonly property var sections: [
        { icon: "󰒓", label: "General", description: "Core layout, focus, input behavior, and window borders." },
        { icon: "󰏫", label: "Decorations", description: "WM-owned titlebars, frames, and their explicit color palette." },
        { icon: "󰔛", label: "Animations", description: "Time-based layout transitions and easing." },
        { icon: "󰐕", label: "Autostart", description: "Commands run once when skarwm starts.", addLabel: "Add command" },
        { icon: "󰌌", label: "Bindings", description: "Commands, WM actions, and workspace shortcuts.", addLabel: "Add binding" },
        { icon: "󰖲", label: "Rules", description: "Match windows and apply workspace, floating, or decoration behavior.", addLabel: "Add rule" },
        { icon: "󰖯", label: "Workspaces", description: "Default layouts and optional ultrawide output splits.", addLabel: "Add layout", secondAddLabel: "Add split" },
        { icon: "󰘦", label: "Advanced", description: "Unrecognized compatibility entries preserved verbatim.", addLabel: "Add entry" }
    ]
    readonly property var generalSettings: [
        { key: "mod_key", label: "Primary modifier", kind: "choice",
          choices: ["super", "Mod1", "Mod2", "Mod3", "Mod4", "Mod5", "Hyper", "Alt", "Shift", "Control"] },
        { key: "outer_gap", label: "Outer gap", kind: "number", suffix: "px" },
        { key: "inner_gap", label: "Inner gap", kind: "number", suffix: "px" },
        { key: "border_width", label: "Border width", kind: "number", suffix: "px" },
        { key: "corner_radius", label: "Client corner radius", kind: "number", suffix: "px" },
        { key: "preview_hover_delay_ms", label: "Scroll preview delay", kind: "number", suffix: "ms" },
        { key: "sel_outer_border", label: "Focused border", kind: "color" },
        { key: "norm_outer_border", label: "Normal border", kind: "color" },
        { key: "focus_follows_mouse", label: "Focus follows pointer", kind: "bool" }
    ]
    readonly property var decorationSettings: [
        { key: "decorations_enabled", label: "Native decorations", kind: "bool" },
        { key: "decoration_show_title", label: "Show window title", kind: "bool" },
        { key: "decoration_titlebar_height", label: "Titlebar height", kind: "number", suffix: "px" },
        { key: "decoration_border_width", label: "Frame border", kind: "number", suffix: "px" },
        { key: "decoration_resize_hit_width", label: "Resize hit area", kind: "number", suffix: "px" },
        { key: "decoration_color_source", label: "Color source", kind: "choice",
          choices: ["active-border", "accent", "explicit"] },
        { key: "decoration_accent", label: "Accent", kind: "color" },
        { key: "decoration_active_background", label: "Active background", kind: "color" },
        { key: "decoration_inactive_background", label: "Inactive background", kind: "color" },
        { key: "decoration_active_foreground", label: "Active foreground", kind: "color" },
        { key: "decoration_inactive_foreground", label: "Inactive foreground", kind: "color" },
        { key: "decoration_active_border", label: "Active frame border", kind: "color" },
        { key: "decoration_inactive_border", label: "Inactive frame border", kind: "color" }
    ]
    readonly property var animationSettings: [
        { key: "animations", label: "Layout animations", kind: "bool" },
        { key: "animation_duration_ms", label: "Duration", kind: "number", suffix: "ms" },
        { key: "animation_fps", label: "Frame rate", kind: "number", suffix: "fps" },
        { key: "animation_easing", label: "Easing", kind: "choice",
          choices: ["ease_out_cubic", "linear"] }
    ]
    cardWidth: 900
    cardHeight: 650
    closeOnOutside: false
    suspendOutsideClose: true

    onVisibleChanged: if (visible) SkarwmConfigService.refresh()

    function openCentered() {
        SkarwmConfigService.resetPending()
        const output = Wm.focusedOutput
        if (output?.rect)
            showCenteredInRect(output.rect.x, output.rect.y,
                output.rect.width, output.rect.height)
        else
            showAtAnchor()
    }

    function pageFor(index) {
        switch (index) {
        case 0: return settingsPage
        case 1: return decorationsPage
        case 2: return animationsPage
        case 3: return autostartPage
        case 4: return bindingsPage
        case 5: return rulesPage
        case 6: return workspacesPage
        default: return advancedPage
        }
    }

    function addForSection(index, secondary) {
        if (index === 3)
            SkarwmConfigService.addItem("autostart", "command")
        else if (index === 4)
            SkarwmConfigService.addItem("bindings",
                { type: "call", combo: "mod + key", value: "layout_next" })
        else if (index === 5)
            SkarwmConfigService.addItem("rules",
                { field: "class", pattern: "Application", effects: "floating" })
        else if (index === 6 && secondary)
            SkarwmConfigService.addItem("virtualScreens",
                { output: "DP-1", ratio: 75, offset: 0 })
        else if (index === 6)
            SkarwmConfigService.addItem("workspaceLayouts",
                { workspace: 1, layout: "scrolling-tile" })
        else if (index === 7)
            SkarwmConfigService.addItem("extras", "mousebind : …")
    }

    component StyledField: Controls.TextField {
        height: 34
        color: Theme.fg
        selectionColor: Theme.accent
        selectedTextColor: Theme.selfg
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontSize - 1
        leftPadding: 10
        rightPadding: 10
        background: Rectangle {
            radius: Theme.radiusSmall
            color: Theme.gray2
            border.width: 1
            border.color: parent.activeFocus ? Theme.accent : Theme.gray5
        }
    }

    component StyledCombo: Controls.ComboBox {
        id: combo
        height: 34
        contentItem: Text {
            leftPadding: 10; rightPadding: 25
            text: combo.displayText
            color: Theme.fg
            font.family: Theme.fontFamily; font.pixelSize: Theme.fontSize - 1
            verticalAlignment: Text.AlignVCenter; elide: Text.ElideRight
        }
        indicator: Text {
            x: combo.width - width - 9; y: (combo.height - height) / 2
            text: "󰅂"; color: Theme.brightBlack
            font.family: Theme.iconFontFamily; font.pixelSize: Theme.iconSizeSmall
        }
        background: Rectangle {
            radius: Theme.radiusSmall; color: Theme.gray2
            border.width: 1; border.color: combo.activeFocus ? Theme.accent : Theme.gray5
        }
        popup: Controls.Popup {
            y: combo.height + 3; width: combo.width; padding: 4
            implicitHeight: Math.min(230, options.contentHeight + 8)
            contentItem: ListView {
                id: options; clip: true
                model: combo.popup.visible ? combo.delegateModel : null
                currentIndex: combo.highlightedIndex
            }
            background: Rectangle {
                radius: Theme.radiusMedium; color: Theme.gray2
                border.width: 1; border.color: Theme.gray5
            }
        }
        delegate: Controls.ItemDelegate {
            id: choice
            required property var modelData
            width: combo.width - 8; height: 30; hoverEnabled: true
            contentItem: Text {
                text: String(choice.modelData); color: choice.hovered ? Theme.accent : Theme.fg
                font.family: Theme.fontFamily; font.pixelSize: Theme.fontSize - 1
                verticalAlignment: Text.AlignVCenter
            }
            background: Rectangle {
                radius: Theme.radiusSmall
                color: choice.hovered || choice.highlighted ? Theme.gray3 : "transparent"
            }
        }
    }

    component Toggle: Rectangle {
        id: toggle
        property bool checked: false
        signal toggled(bool value)
        width: 34; height: 18
        radius: Math.min(height / 2, Theme.radiusSmall)
        color: checked ? Theme.accent : Qt.alpha(Theme.fg, 0.15)
        Behavior on color { ColorAnimation { duration: 150 } }
        Rectangle {
            width: 14; height: 14
            radius: Math.min(width / 2, Theme.radiusSmall)
            anchors.verticalCenter: parent.verticalCenter
            x: toggle.checked ? parent.width - width - 2 : 2
            color: toggle.checked ? Theme.bg : Qt.alpha(Theme.fg, 0.7)
            Behavior on x {
                NumberAnimation { duration: 150; easing.type: Easing.OutCubic }
            }
        }
        MouseArea { anchors.fill: parent; onClicked: toggle.toggled(!toggle.checked) }
    }

    component SettingRows: Column {
        required property var definitions
        width: parent.width
        spacing: 6
        Repeater {
            model: parent.definitions
            Rectangle {
                id: settingRow
                required property var modelData
                width: parent.width; height: 42; radius: Theme.radiusSmall
                color: Theme.gray1; border.width: 1; border.color: Theme.gray4
                Text {
                    anchors.left: parent.left; anchors.leftMargin: 12
                    anchors.verticalCenter: parent.verticalCenter
                    width: 235; text: settingRow.modelData.label
                    color: Theme.fg; font.family: Theme.fontFamily; font.pixelSize: Theme.fontSize
                }
                Loader {
                    anchors.right: parent.right; anchors.rightMargin: 8
                    anchors.verticalCenter: parent.verticalCenter
                    width: 285
                    sourceComponent: settingRow.modelData.kind === "bool" ? boolEditor
                        : settingRow.modelData.kind === "choice" ? choiceEditor : textEditor
                }
                Component {
                    id: boolEditor
                    Item {
                        Toggle {
                            anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                            checked: SkarwmConfigService.pending.settings[settingRow.modelData.key] === true
                            onToggled: value => SkarwmConfigService.setSetting(settingRow.modelData.key, value)
                        }
                    }
                }
                Component {
                    id: choiceEditor
                    StyledCombo {
                        width: parent.width
                        model: settingRow.modelData.choices
                        currentIndex: settingRow.modelData.choices.indexOf(
                            String(SkarwmConfigService.pending.settings[settingRow.modelData.key] ?? ""))
                        onActivated: index => SkarwmConfigService.setSetting(
                            settingRow.modelData.key, settingRow.modelData.choices[index])
                    }
                }
                Component {
                    id: textEditor
                    Row {
                        spacing: 7
                        StyledField {
                            width: parent.width - colorPreview.width
                                - (colorPreview.visible ? 7 : 0)
                                - (suffix.visible ? suffix.width + 7 : 0)
                            text: String(SkarwmConfigService.pending.settings[settingRow.modelData.key] ?? "")
                            validator: settingRow.modelData.kind === "number"
                                ? intValidator : null
                            onEditingFinished: SkarwmConfigService.setSetting(
                                settingRow.modelData.key,
                                settingRow.modelData.kind === "number" ? Number(text) : text)
                        }
                        Rectangle {
                            id: colorPreview
                            visible: settingRow.modelData.kind === "color"
                            width: visible ? 34 : 0; height: 34
                            radius: Theme.radiusSmall
                            color: {
                                const value = String(SkarwmConfigService.pending.settings[
                                    settingRow.modelData.key] ?? "")
                                return /^#[0-9a-fA-F]{6}$/.test(value) ? value : "transparent"
                            }
                            border.width: 1; border.color: Theme.gray5
                        }
                        Text {
                            id: suffix; visible: String(settingRow.modelData.suffix ?? "") !== ""
                            anchors.verticalCenter: parent.verticalCenter
                            text: settingRow.modelData.suffix ?? ""
                            color: Theme.brightBlack; font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSize - 1
                        }
                        IntValidator { id: intValidator; bottom: -100000; top: 100000 }
                    }
                }
            }
        }
    }

    component AddButton: Rectangle {
        id: addButton
        property string label: "Add"
        signal activated()
        width: 110; height: 34; radius: Theme.radiusSmall
        color: addMouse.containsMouse ? Qt.alpha(Theme.accent, 0.25) : Theme.gray2
        border.width: 1; border.color: Theme.accent
        Text { anchors.centerIn: parent; text: "+  " + addButton.label; color: Theme.accent; font.family: Theme.fontFamily; font.pixelSize: Theme.fontSize - 1 }
        MouseArea { id: addMouse; anchors.fill: parent; hoverEnabled: true; onClicked: addButton.activated() }
    }

    component RemoveButton: Rectangle {
        id: removeButton
        signal activated()
        width: 32; height: 32; radius: Theme.radiusSmall
        color: removeMouse.containsMouse ? Qt.alpha(Theme.red, 0.22) : Theme.gray2
        Text { anchors.centerIn: parent; text: "󰆴"; color: Theme.red; font.family: Theme.iconFontFamily; font.pixelSize: Theme.iconSizeSmall }
        MouseArea { id: removeMouse; anchors.fill: parent; hoverEnabled: true; onClicked: removeButton.activated() }
    }

    Component {
        id: settingsPage
        Column {
            width: parent.width; spacing: 10
            SettingRows { definitions: root.generalSettings }
        }
    }
    Component {
        id: decorationsPage
        Column {
            width: parent.width; spacing: 10
            SettingRows { definitions: root.decorationSettings }
        }
    }
    Component {
        id: animationsPage
        Column {
            width: parent.width; spacing: 10
            SettingRows { definitions: root.animationSettings }
        }
    }

    Component {
        id: autostartPage
        Column {
            width: parent.width; spacing: 8
            Repeater {
                model: SkarwmConfigService.pending.autostart
                Row {
                    required property int index; required property var modelData
                    width: parent.width; spacing: 7
                    StyledField { width: parent.width - 39; text: String(modelData); placeholderText: "Shell command"; onEditingFinished: SkarwmConfigService.updateItem("autostart", index, text) }
                    RemoveButton { onActivated: SkarwmConfigService.removeItem("autostart", index) }
                }
            }
        }
    }

    Component {
        id: bindingsPage
        Column {
            width: parent.width; spacing: 8
            Repeater {
                model: SkarwmConfigService.pending.bindings
                Rectangle {
                    id: bindingRow
                    required property int index; required property var modelData
                    width: parent.width; height: 42; radius: Theme.radiusSmall
                    color: Theme.gray1; border.width: 1; border.color: Theme.gray4
                    Row {
                        anchors.fill: parent; anchors.margins: 5; spacing: 6
                        StyledCombo { width: 105; model: ["bind", "call", "workspace"]; currentIndex: model.indexOf(bindingRow.modelData.type); onActivated: i => SkarwmConfigService.updateItem("bindings", bindingRow.index, { type: model[i] }) }
                        StyledField { width: 200; text: bindingRow.modelData.combo; placeholderText: "mod + key"; onEditingFinished: SkarwmConfigService.updateItem("bindings", bindingRow.index, { combo: text }) }
                        StyledField { width: parent.width - 349; text: bindingRow.modelData.value; placeholderText: bindingRow.modelData.type === "bind" ? "Shell command" : "Action"; onEditingFinished: SkarwmConfigService.updateItem("bindings", bindingRow.index, { value: text }) }
                        RemoveButton { onActivated: SkarwmConfigService.removeItem("bindings", bindingRow.index) }
                    }
                }
            }
        }
    }

    Component {
        id: rulesPage
        Column {
            width: parent.width; spacing: 8
            Repeater {
                model: SkarwmConfigService.pending.rules
                Rectangle {
                    id: ruleRow
                    required property int index; required property var modelData
                    width: parent.width; height: 42; radius: Theme.radiusSmall
                    color: Theme.gray1; border.width: 1; border.color: Theme.gray4
                    Row {
                        anchors.fill: parent; anchors.margins: 5; spacing: 6
                        StyledCombo { width: 100; model: ["class", "instance", "title"]; currentIndex: model.indexOf(ruleRow.modelData.field); onActivated: i => SkarwmConfigService.updateItem("rules", ruleRow.index, { field: model[i] }) }
                        StyledField { width: 190; text: ruleRow.modelData.pattern; placeholderText: "Match text"; onEditingFinished: SkarwmConfigService.updateItem("rules", ruleRow.index, { pattern: text }) }
                        StyledField { width: parent.width - 334; text: ruleRow.modelData.effects; placeholderText: "floating workspace 3"; onEditingFinished: SkarwmConfigService.updateItem("rules", ruleRow.index, { effects: text }) }
                        RemoveButton { onActivated: SkarwmConfigService.removeItem("rules", ruleRow.index) }
                    }
                }
            }
        }
    }

    Component {
        id: workspacesPage
        Column {
            width: parent.width; spacing: 10
            Text { text: "Workspace layouts"; color: Theme.fg; font.family: Theme.fontFamily; font.bold: true }
            Repeater {
                model: SkarwmConfigService.pending.workspaceLayouts
                Row {
                    required property int index; required property var modelData
                    width: parent.width; spacing: 7
                    StyledField { width: 120; text: String(modelData.workspace); placeholderText: "Workspace"; onEditingFinished: SkarwmConfigService.updateItem("workspaceLayouts", index, { workspace: text }) }
                    StyledCombo { width: 260; model: ["scrolling-tile", "vertical-scrolling-tile", "dwindle", "monocle", "floating"]; currentIndex: model.indexOf(modelData.layout); onActivated: i => SkarwmConfigService.updateItem("workspaceLayouts", index, { layout: model[i] }) }
                    RemoveButton { onActivated: SkarwmConfigService.removeItem("workspaceLayouts", index) }
                }
            }
            Rectangle { width: parent.width; height: 1; color: Theme.gray5 }
            Text { text: "Virtual screens"; color: Theme.fg; font.family: Theme.fontFamily; font.bold: true }
            Repeater {
                model: SkarwmConfigService.pending.virtualScreens
                Row {
                    required property int index; required property var modelData
                    width: parent.width; spacing: 7
                    StyledField { width: 180; text: modelData.output; placeholderText: "Output (DP-1)"; onEditingFinished: SkarwmConfigService.updateItem("virtualScreens", index, { output: text }) }
                    StyledField { width: 110; text: String(modelData.ratio); placeholderText: "Ratio %"; onEditingFinished: SkarwmConfigService.updateItem("virtualScreens", index, { ratio: text }) }
                    StyledField { width: 110; text: String(modelData.offset); placeholderText: "Offset px"; onEditingFinished: SkarwmConfigService.updateItem("virtualScreens", index, { offset: text }) }
                    RemoveButton { onActivated: SkarwmConfigService.removeItem("virtualScreens", index) }
                }
            }
        }
    }

    Component {
        id: advancedPage
        Column {
            width: parent.width; spacing: 8
            Repeater {
                model: SkarwmConfigService.pending.extras
                Row {
                    required property int index; required property var modelData
                    width: parent.width; spacing: 7
                    StyledField { width: parent.width - 39; text: String(modelData); onEditingFinished: SkarwmConfigService.updateItem("extras", index, text) }
                    RemoveButton { onActivated: SkarwmConfigService.removeItem("extras", index) }
                }
            }
        }
    }

    Column {
        anchors.fill: parent
        spacing: 10

        Row {
            width: parent.width; height: 30
            Text {
                width: parent.width - closeButton.width
                text: "skarwm settings"
                color: Theme.fg; font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSize + 2; font.bold: true
            }
            Rectangle {
                id: closeButton
                width: 28; height: 28; radius: Theme.radiusSmall
                color: closeMouse.containsMouse ? Theme.gray4 : Theme.gray2
                Text { anchors.centerIn: parent; text: "󰅖"; color: Theme.brightBlack; font.family: Theme.iconFontFamily; font.pixelSize: Theme.iconSize }
                MouseArea { id: closeMouse; anchors.fill: parent; hoverEnabled: true; onClicked: { SkarwmConfigService.resetPending(); root.visible = false } }
            }
        }

        Row {
            width: parent.width; height: parent.height - 88; spacing: 12
            Rectangle {
                width: 178; height: parent.height; radius: Theme.radiusMedium
                color: Theme.gray1; border.width: 1; border.color: Theme.gray5
                Column {
                    anchors.fill: parent; anchors.margins: 6; spacing: 3
                    Repeater {
                        model: root.sections
                        Rectangle {
                            id: navItem
                            required property int index; required property var modelData
                            width: parent.width; height: 39; radius: Theme.radiusSmall
                            color: root.selectedSection === index ? Qt.alpha(Theme.accent, 0.2)
                                : navMouse.containsMouse ? Theme.gray3 : "transparent"
                            Row {
                                anchors.left: parent.left; anchors.leftMargin: 10
                                anchors.verticalCenter: parent.verticalCenter; spacing: 9
                                Text { text: navItem.modelData.icon; color: root.selectedSection === navItem.index ? Theme.accent : Theme.brightBlack; font.family: Theme.iconFontFamily; font.pixelSize: Theme.iconSizeSmall }
                                Text { text: navItem.modelData.label; color: root.selectedSection === navItem.index ? Theme.accent : Theme.fg; font.family: Theme.fontFamily; font.pixelSize: Theme.fontSize - 1; font.bold: root.selectedSection === navItem.index }
                            }
                            MouseArea { id: navMouse; anchors.fill: parent; hoverEnabled: true; onClicked: root.selectedSection = navItem.index }
                        }
                    }
                }
            }
            Rectangle {
                id: pagePanel
                width: parent.width - 190; height: parent.height
                radius: Theme.radiusMedium; color: Theme.gray1
                border.width: 1; border.color: Theme.gray5

                Item {
                    id: pageHeader
                    anchors.left: parent.left; anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.leftMargin: 12; anchors.rightMargin: 12
                    height: 54

                    Text {
                        anchors.left: parent.left
                        anchors.right: headerActions.left
                        anchors.rightMargin: 12
                        anchors.verticalCenter: parent.verticalCenter
                        text: String(root.sections[root.selectedSection]?.description ?? "")
                        color: Theme.brightBlack
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSize - 1
                        wrapMode: Text.WordWrap
                    }

                    Row {
                        id: headerActions
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 7
                        AddButton {
                            visible: String(root.sections[root.selectedSection]?.secondAddLabel ?? "") !== ""
                            label: root.sections[root.selectedSection]?.secondAddLabel ?? ""
                            onActivated: root.addForSection(root.selectedSection, true)
                        }
                        AddButton {
                            visible: String(root.sections[root.selectedSection]?.addLabel ?? "") !== ""
                            label: root.sections[root.selectedSection]?.addLabel ?? ""
                            onActivated: root.addForSection(root.selectedSection, false)
                        }
                    }
                }

                Rectangle {
                    anchors.left: parent.left; anchors.right: parent.right
                    anchors.top: pageHeader.bottom
                    height: 1; color: Theme.gray5
                }

                Flickable {
                    id: configFlick
                    anchors.left: parent.left; anchors.right: parent.right
                    anchors.top: pageHeader.bottom; anchors.bottom: parent.bottom
                    anchors.margins: 10
                    clip: true
                    contentWidth: width
                    contentHeight: pageLoader.implicitHeight
                    boundsBehavior: Flickable.StopAtBounds

                    Controls.ScrollBar.vertical: Controls.ScrollBar {
                        id: configScrollBar
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
                            color: configScrollBar.pressed ? Theme.brightOrange
                                : configScrollBar.hovered ? Theme.orange : Theme.gray6
                        }
                    }

                    Loader {
                        id: pageLoader
                        width: configFlick.width - (configScrollBar.visible ? 12 : 0)
                        sourceComponent: root.pageFor(root.selectedSection)
                    }
                }
                Text {
                    visible: SkarwmConfigService.loading
                    anchors.centerIn: parent; text: "Loading configuration…"
                    color: Theme.brightBlack; font.family: Theme.fontFamily
                }
            }
        }

        Row {
            width: parent.width; height: 38; spacing: 8; layoutDirection: Qt.RightToLeft
            Rectangle {
                width: 145; height: 38; radius: Theme.radiusMedium
                color: saveMouse.containsMouse ? Theme.brightOrange : Theme.accent
                opacity: SkarwmConfigService.saving || SkarwmConfigService.loading ? 0.55 : 1
                Text { anchors.centerIn: parent; text: SkarwmConfigService.saving ? "Saving…" : "Save & Reload"; color: Theme.selfg; font.family: Theme.fontFamily; font.pixelSize: Theme.fontSize; font.bold: true }
                MouseArea { id: saveMouse; anchors.fill: parent; enabled: parent.opacity === 1; hoverEnabled: true; onClicked: SkarwmConfigService.saveAndReload() }
            }
            Rectangle {
                width: 100; height: 38; radius: Theme.radiusMedium
                color: cancelMouse.containsMouse ? Theme.gray3 : Theme.gray2
                border.width: 1; border.color: Theme.gray5
                Text { anchors.centerIn: parent; text: "Cancel"; color: Theme.fg; font.family: Theme.fontFamily; font.pixelSize: Theme.fontSize }
                MouseArea { id: cancelMouse; anchors.fill: parent; hoverEnabled: true; onClicked: { SkarwmConfigService.resetPending(); root.visible = false } }
            }
            Text {
                width: parent.width - 261; anchors.verticalCenter: parent.verticalCenter
                text: SkarwmConfigService.error !== "" ? SkarwmConfigService.error
                    : SkarwmConfigService.status !== "" ? SkarwmConfigService.status
                    : String(SkarwmConfigService.pending.path ?? "")
                color: SkarwmConfigService.error !== "" ? Theme.red : Theme.brightBlack
                elide: Text.ElideMiddle; font.family: Theme.fontFamily; font.pixelSize: Theme.fontSize - 1
            }
        }
    }
}
