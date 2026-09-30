pragma ComponentBehavior: Bound

import QtQuick
import "../.."
import QtQuick.Controls as Controls

Popout {
    id: root

    cardWidth: 480
    cardHeight: 680

    property string groupDraft: ""
    property string errorText: ""
    property int focusAttempts: 0
    property var selectedLayouts: []
    property var selectedVariants: []
    property string expandedLayout: ""
    readonly property var filteredLayouts: {
        const query = searchInput.text.trim().toLowerCase()
        if (query === "")
            return KeyboardState.availableLayouts
        return KeyboardState.availableLayouts.filter(layout =>
            layout.code.toLowerCase().indexOf(query) !== -1
                || layout.name.toLowerCase().indexOf(query) !== -1
                || (layout.variants ?? []).some(variant =>
                    variant.code.toLowerCase().indexOf(query) !== -1
                    || variant.name.toLowerCase().indexOf(query) !== -1))
    }

    readonly property var shortcutPresets: [
        { label: "Alt+Shift", value: "grp:alt_shift_toggle" },
        { label: "Super+Space", value: "grp:win_space_toggle" },
        { label: "Ctrl+Shift", value: "grp:ctrl_shift_toggle" },
        { label: "Caps Lock", value: "grp:caps_toggle" },
        { label: "None", value: "" }
    ]

    function focusSearch() {
        if (!visible)
            return
        if (_backingWindow)
            _backingWindow.requestActivate()
        searchInput.forceActiveFocus()
    }

    function openSettings() {
        errorText = ""
        syncInputs()
        visible = true
    }

    function syncInputs() {
        selectedLayouts = KeyboardState.layouts.slice()
        const values = KeyboardState.variants.slice(0, selectedLayouts.length)
        while (values.length < selectedLayouts.length)
            values.push("")
        selectedVariants = values
        expandedLayout = ""
        searchInput.text = ""
        groupDraft = KeyboardState.groupOption
        customInput.text = groupDraft
        if (selectedLayouts.length > KeyboardState.maximumGroups)
            errorText = "XKB supports at most " + KeyboardState.maximumGroups
                + " switchable layout/variant entries."
        else if (KeyboardState.configurationError !== "")
            errorText = KeyboardState.configurationError
    }

    function toggleLayout(code) {
        const layouts = selectedLayouts.slice()
        const variants = selectedVariants.slice()
        if (layouts.indexOf(code) === -1) {
            if (layouts.length >= KeyboardState.maximumGroups) {
                errorText = "XKB supports at most "
                    + KeyboardState.maximumGroups + " switchable entries."
                return
            }
            layouts.push(code)
            variants.push("")
            if (KeyboardState.variantsFor(code).length > 0)
                expandedLayout = code
        } else {
            for (let index = layouts.length - 1; index >= 0; --index) {
                if (layouts[index] === code) {
                    layouts.splice(index, 1)
                    variants.splice(index, 1)
                }
            }
            if (expandedLayout === code)
                expandedLayout = ""
        }
        selectedLayouts = layouts
        selectedVariants = variants.slice(0, layouts.length)
        errorText = ""
    }

    function selectedVariantCodes(code) {
        const result = []
        for (let index = 0; index < selectedLayouts.length; ++index) {
            if (selectedLayouts[index] === code)
                result.push(String(selectedVariants[index] ?? ""))
        }
        return result
    }

    function isVariantSelected(code, variant) {
        for (let index = 0; index < selectedLayouts.length; ++index) {
            if (selectedLayouts[index] === code
                    && String(selectedVariants[index] ?? "") === variant)
                return true
        }
        return false
    }

    function selectionOrders(code) {
        const result = []
        for (let index = 0; index < selectedLayouts.length; ++index) {
            if (selectedLayouts[index] === code)
                result.push(index + 1)
        }
        return result
    }

    function variantSummary(code) {
        return selectedVariantCodes(code).map(value => value === ""
            ? "Default" : value).join(", ")
    }

    function variantChoices(layout) {
        const choices = [{ code: "", name: "Default" }]
            .concat(layout.variants ?? [])
        for (const selected of selectedVariantCodes(layout.code)) {
            if (selected !== ""
                    && !choices.some(item => item.code === selected))
                choices.push({ code: selected,
                    name: selected + " (configured)" })
        }
        return choices
    }

    function toggleVariant(layoutCode, variantCode) {
        const layouts = selectedLayouts.slice()
        const variants = selectedVariants.slice()
        let selectedIndex = -1
        for (let index = 0; index < layouts.length; ++index) {
            if (layouts[index] === layoutCode
                    && String(variants[index] ?? "") === variantCode) {
                selectedIndex = index
                break
            }
        }
        if (selectedIndex === -1) {
            // Choosing the first named variant replaces the implicit Default
            // entry. This avoids consuming two XKB groups unintentionally.
            if (variantCode !== "") {
                for (let index = layouts.length - 1; index >= 0; --index) {
                    if (layouts[index] === layoutCode
                            && String(variants[index] ?? "") === "") {
                        layouts.splice(index, 1)
                        variants.splice(index, 1)
                        break
                    }
                }
            }
            if (layouts.length >= KeyboardState.maximumGroups) {
                errorText = "XKB supports at most "
                    + KeyboardState.maximumGroups + " switchable entries."
                return
            }
            layouts.push(layoutCode)
            variants.push(variantCode)
        } else {
            layouts.splice(selectedIndex, 1)
            variants.splice(selectedIndex, 1)
        }
        selectedLayouts = layouts
        selectedVariants = variants
        errorText = ""
    }

    function saveSettings() {
        if (!KeyboardState.saveConfiguration(selectedLayouts.join(","),
                                             selectedVariants.join(","),
                                             customInput.text)) {
            errorText = KeyboardState.configurationError !== ""
                ? KeyboardState.configurationError : "Add at least one layout."
            return
        }
        visible = false
    }

    onVisibleChanged: {
        if (visible) {
            focusAttempts = 0
            Qt.callLater(() => root.focusSearch())
            focusRetry.start()
        }
    }

    Timer {
        id: focusRetry
        interval: 50
        repeat: true
        onTriggered: {
            root.focusAttempts++
            root.focusSearch()
            if (root.focusAttempts >= 4)
                stop()
        }
    }

    Text {
        id: heading
        anchors.left: parent.left
        anchors.top: parent.top
        text: "Keyboard settings"
        color: Theme.fg
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontSize + 2
        font.bold: true
    }

    Text {
        id: selectedLabel
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: heading.bottom
        anchors.topMargin: 14
        elide: Text.ElideRight
        text: "Selected (in order): " + (root.selectedLayouts.length > 0
            ? root.selectedLayouts.map((code, index) => code.toUpperCase()
                + (String(root.selectedVariants[index] ?? "") !== ""
                    ? " (" + root.selectedVariants[index] + ")" : "")).join(" → ")
            : "none")
        color: Theme.brightBlack
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontSize - 1
    }

    Rectangle {
        id: searchBox
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: selectedLabel.bottom
        anchors.topMargin: 5
        height: 36
        radius: Theme.radiusSmall
        color: Theme.gray2
        border.width: 1
        border.color: searchInput.activeFocus ? Theme.accent : Theme.gray5

        Row {
            anchors.fill: parent
            anchors.leftMargin: 10
            anchors.rightMargin: 10
            spacing: 8

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: "󰍉"
                color: Theme.accent
                font.family: Theme.iconFontFamily
                font.pixelSize: Theme.iconSize
            }

            TextInput {
                id: searchInput
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width - 30
                clip: true
                color: Theme.fg
                selectionColor: Theme.selbg
                selectedTextColor: Theme.selfg
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSize

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: searchInput.text.length === 0
                    text: "Search available languages or layout codes"
                    color: Theme.brightBlack
                    font: searchInput.font
                }
            }
        }
    }

    ListView {
        id: layoutList
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: searchBox.bottom
        anchors.topMargin: 6
        height: 320
        clip: true
        spacing: 2
        model: root.filteredLayouts

        Text {
            anchors.centerIn: parent
            visible: layoutList.count === 0
            text: KeyboardState.availableLayouts.length === 0
                ? "XKB layout catalogue was not found"
                : "No matching layouts"
            color: Theme.brightBlack
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSize
        }

        delegate: Rectangle {
            id: layoutRow
            required property var modelData

            width: layoutList.width - 14
            readonly property var variantOptions: root.variantChoices(modelData)
            readonly property bool hasVariants: (modelData.variants ?? []).length > 0
            readonly property bool expanded: hasVariants
                && root.expandedLayout === modelData.code
            height: 34 + (expanded ? variantOptions.length * 30 + 4 : 0)
            radius: Theme.radiusSmall
            readonly property bool selected:
                root.selectedLayouts.indexOf(modelData.code) !== -1
            color: selected ? Qt.alpha(Theme.accent, 0.22)
                : (layoutMouse.containsMouse ? Theme.gray3 : Theme.gray2)
            border.width: 1
            border.color: selected ? Theme.accent : Theme.gray5

            Rectangle {
                id: layoutCheckbox
                anchors.left: parent.left
                anchors.leftMargin: 9
                anchors.top: parent.top
                anchors.topMargin: 9
                width: 16
                height: 16
                radius: Theme.radiusSmall
                color: layoutRow.selected ? Theme.accent : "transparent"
                border.width: 1
                border.color: layoutRow.selected ? Theme.brightOrange : Theme.gray6

                Text {
                    anchors.centerIn: parent
                    visible: layoutRow.selected
                    text: "✓"
                    color: Theme.selfg
                    font.pixelSize: 12
                    font.bold: true
                }
            }

            Text {
                anchors.left: parent.left
                anchors.leftMargin: 34
                anchors.right: orderText.left
                anchors.rightMargin: 8
                anchors.top: parent.top
                anchors.topMargin: 8
                text: layoutRow.modelData.name + "  (" + layoutRow.modelData.code + ")"
                    + (layoutRow.selected
                        ? " · " + root.variantSummary(layoutRow.modelData.code) : "")
                elide: Text.ElideRight
                color: Theme.fg
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSize
            }

            Text {
                id: orderText
                anchors.right: expandButton.visible ? expandButton.left : parent.right
                anchors.rightMargin: 10
                anchors.top: parent.top
                anchors.topMargin: 8
                text: layoutRow.selected
                    ? root.selectionOrders(layoutRow.modelData.code).join(",") : ""
                color: Theme.accent
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSize
                font.bold: true
            }

            MouseArea {
                id: layoutMouse
                anchors.left: parent.left
                anchors.right: expandButton.visible ? expandButton.left : parent.right
                anchors.top: parent.top
                height: 34
                hoverEnabled: true
                onClicked: root.toggleLayout(layoutRow.modelData.code)
            }

            Rectangle {
                id: expandButton
                visible: layoutRow.hasVariants
                anchors.right: parent.right
                anchors.rightMargin: 5
                anchors.top: parent.top
                anchors.topMargin: 3
                width: 28
                height: 28
                radius: Theme.radiusSmall
                color: expandMouse.containsMouse ? Theme.gray4 : "transparent"

                Text {
                    anchors.centerIn: parent
                    text: layoutRow.expanded ? "󰅀" : "󰅂"
                    color: Theme.accent
                    font.family: Theme.iconFontFamily
                    font.pixelSize: Theme.iconSizeSmall
                }

                MouseArea {
                    id: expandMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    onClicked: root.expandedLayout = layoutRow.expanded
                        ? "" : layoutRow.modelData.code
                }
            }

            Column {
                visible: layoutRow.expanded
                anchors.left: parent.left
                anchors.leftMargin: 24
                anchors.right: parent.right
                anchors.rightMargin: 5
                anchors.top: parent.top
                anchors.topMargin: 36
                spacing: 2

                Repeater {
                    model: layoutRow.expanded ? layoutRow.variantOptions : []

                    Rectangle {
                        id: variantRow
                        required property var modelData
                        width: parent.width
                        height: 28
                        radius: Theme.radiusSmall
                        readonly property bool selected: root.isVariantSelected(
                            layoutRow.modelData.code, modelData.code)
                        color: selected ? Qt.alpha(Theme.accent, 0.18)
                            : variantMouse.containsMouse ? Theme.gray3 : "transparent"

                        Rectangle {
                            anchors.left: parent.left
                            anchors.leftMargin: 7
                            anchors.verticalCenter: parent.verticalCenter
                            width: 14
                            height: 14
                            radius: Theme.radiusSmall
                            color: variantRow.selected ? Theme.accent : "transparent"
                            border.width: 1
                            border.color: variantRow.selected
                                ? Theme.brightOrange : Theme.gray6

                            Text {
                                anchors.centerIn: parent
                                visible: variantRow.selected
                                text: "✓"
                                color: Theme.selfg
                                font.pixelSize: 10
                                font.bold: true
                            }
                        }

                        Text {
                            anchors.left: parent.left
                            anchors.leftMargin: 29
                            anchors.right: parent.right
                            anchors.rightMargin: 7
                            anchors.verticalCenter: parent.verticalCenter
                            text: variantRow.modelData.name
                                + (variantRow.modelData.code !== ""
                                    ? "  (" + variantRow.modelData.code + ")" : "")
                            elide: Text.ElideRight
                            color: variantRow.selected ? Theme.accent : Theme.fg
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSize - 1
                        }

                        MouseArea {
                            id: variantMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            onClicked: root.toggleVariant(
                                layoutRow.modelData.code, variantRow.modelData.code)
                        }
                    }
                }
            }
        }

        Controls.ScrollBar.vertical: Controls.ScrollBar {
            id: layoutScroll
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
                color: layoutScroll.pressed ? Theme.brightOrange
                    : layoutScroll.hovered ? Theme.orange : Theme.gray6
            }
        }
    }

    Text {
        id: shortcutLabel
        anchors.left: parent.left
        anchors.top: layoutList.bottom
        anchors.topMargin: 12
        text: "Switch shortcut"
        color: Theme.brightBlack
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontSize - 1
    }

    Flow {
        id: presetFlow
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: shortcutLabel.bottom
        anchors.topMargin: 5
        spacing: 6

        Repeater {
            model: root.shortcutPresets

            Rectangle {
                required property var modelData
                width: presetText.implicitWidth + 18
                height: 30
                radius: Theme.radiusSmall
                readonly property bool selected: customInput.text.trim() === modelData.value
                color: selected ? Theme.accent
                    : (presetMouse.containsMouse ? Theme.gray3 : Theme.gray2)
                border.width: 1
                border.color: selected ? Theme.brightOrange : Theme.gray5

                Text {
                    id: presetText
                    anchors.centerIn: parent
                    text: parent.modelData.label
                    color: parent.selected ? Theme.selfg : Theme.fg
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSize - 1
                }

                MouseArea {
                    id: presetMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    onClicked: {
                        root.groupDraft = parent.modelData.value
                        customInput.text = root.groupDraft
                    }
                }
            }
        }
    }

    Text {
        id: optionLabel
        anchors.left: parent.left
        anchors.top: presetFlow.bottom
        anchors.topMargin: 12
        text: "XKB group option"
        color: Theme.brightBlack
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontSize - 1
    }

    Rectangle {
        id: optionBox
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: optionLabel.bottom
        anchors.topMargin: 5
        height: 36
        radius: Theme.radiusSmall
        color: Theme.gray2
        border.width: 1
        border.color: customInput.activeFocus ? Theme.accent : Theme.gray5

        TextInput {
            id: customInput
            anchors.fill: parent
            anchors.leftMargin: 10
            anchors.rightMargin: 10
            verticalAlignment: TextInput.AlignVCenter
            clip: true
            color: Theme.fg
            selectionColor: Theme.selbg
            selectedTextColor: Theme.selfg
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSize
            Keys.onReturnPressed: root.saveSettings()
        }
    }

    Text {
        anchors.left: parent.left
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 7
        text: root.errorText
        visible: text !== ""
        color: Theme.red
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontSize - 1
    }

    Row {
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        spacing: 8

        Repeater {
            model: [
                { label: "Cancel", primary: false },
                { label: "Apply", primary: true }
            ]

            Rectangle {
                required property var modelData
                width: 82
                height: 34
                radius: Theme.radiusSmall
                color: modelData.primary ? Theme.accent
                    : (actionMouse.containsMouse ? Theme.gray3 : Theme.gray2)
                border.width: 1
                border.color: modelData.primary ? Theme.brightOrange : Theme.gray5

                Text {
                    anchors.centerIn: parent
                    text: parent.modelData.label
                    color: parent.modelData.primary ? Theme.selfg : Theme.fg
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSize
                    font.bold: parent.modelData.primary
                }

                MouseArea {
                    id: actionMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    onClicked: {
                        if (parent.modelData.primary)
                            root.saveSettings()
                        else
                            root.visible = false
                    }
                }
            }
        }
    }
}
