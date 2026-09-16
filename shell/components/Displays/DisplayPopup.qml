pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls as Controls
import "../.."

Popout {
    id: root

    property string selectedName: ""
    readonly property var selected: DisplayConfigurationService.output(selectedName)
    readonly property var enabledOutputs: DisplayConfigurationService.pendingOutputs.filter(o => o.enabled)
    readonly property real minimumX: enabledOutputs.length
        ? Math.min(...enabledOutputs.map(o => o.x)) : 0
    readonly property real minimumY: enabledOutputs.length
        ? Math.min(...enabledOutputs.map(o => o.y)) : 0
    readonly property real maximumX: enabledOutputs.length
        ? Math.max(...enabledOutputs.map(o => o.x + logicalWidth(o))) : 1
    readonly property real maximumY: enabledOutputs.length
        ? Math.max(...enabledOutputs.map(o => o.y + logicalHeight(o))) : 1
    readonly property real previewScale: Math.min(0.16,
        (arrangement.width - 40) / Math.max(1, maximumX - minimumX),
        (arrangement.height - 64) / Math.max(1, maximumY - minimumY))

    cardWidth: 780
    cardHeight: 610
    onVisibleChanged: if (visible) {
        DisplayConfigurationService.refresh()
        if (selectedName === "" && DisplayConfigurationService.pendingOutputs.length)
            selectedName = DisplayConfigurationService.pendingOutputs[0].name
    }

    function openCentered() {
        DisplayConfigurationService.resetPending()
        if (!DisplayConfigurationService.output(selectedName)
                && DisplayConfigurationService.pendingOutputs.length)
            selectedName = DisplayConfigurationService.pendingOutputs[0].name
        const output = Wm.focusedOutput
        if (output?.rect)
            showCenteredInRect(output.rect.x, output.rect.y,
                output.rect.width, output.rect.height)
        else
            showAtAnchor()
    }
    function logicalWidth(output) {
        if (!output) return 1
        const rotated = output.transform === "left" || output.transform === "right"
        return (rotated ? output.height : output.width) / Math.max(0.5, output.scale)
    }
    function logicalHeight(output) {
        if (!output) return 1
        const rotated = output.transform === "left" || output.transform === "right"
        return (rotated ? output.width : output.height) / Math.max(0.5, output.scale)
    }
    function resolutions(output) {
        if (!output) return []
        const seen = ({})
        const result = []
        for (const mode of output.modes) {
            const key = mode.width + "x" + mode.height
            if (!seen[key]) {
                seen[key] = true
                result.push({ text: mode.width + " × " + mode.height, value: key })
            }
        }
        return result
    }
    function rates(output) {
        if (!output) return []
        return output.modes.filter(m => m.width === output.width && m.height === output.height)
            .map(m => m.refreshRate)
    }
    function setResolution(value) {
        if (!selected) return
        const parts = value.split("x")
        const width = Number(parts[0]), height = Number(parts[1])
        const modes = selected.modes.filter(m => m.width === width && m.height === height)
        const preferred = modes.find(m => m.preferred) ?? modes[0]
        if (preferred) DisplayConfigurationService.updateOutput(selected.name, {
            width: width, height: height, refreshRate: preferred.refreshRate
        })
    }
    function moveOutput(output, x, y) {
        let nx = Math.round(x), ny = Math.round(y)
        const width = logicalWidth(output), height = logicalHeight(output)
        const threshold = 32
        let closestX = threshold + 1, closestY = threshold + 1
        let snappedX = nx, snappedY = ny
        for (const other of enabledOutputs) {
            if (other.name === output.name) continue
            const ow = logicalWidth(other), oh = logicalHeight(other)
            const verticallyOverlaps = ny < other.y + oh && ny + height > other.y
            const horizontallyOverlaps = nx < other.x + ow && nx + width > other.x

            if (verticallyOverlaps) {
                for (const candidate of [other.x - width, other.x + ow]) {
                    const distance = Math.abs(nx - candidate)
                    if (distance < closestX) {
                        closestX = distance
                        snappedX = Math.round(candidate)
                    }
                }
            }
            if (horizontallyOverlaps) {
                for (const candidate of [other.y - height, other.y + oh]) {
                    const distance = Math.abs(ny - candidate)
                    if (distance < closestY) {
                        closestY = distance
                        snappedY = Math.round(candidate)
                    }
                }
            }
        }
        if (closestX <= threshold) nx = snappedX
        if (closestY <= threshold) ny = snappedY
        DisplayConfigurationService.positionOutput(output.name, nx, ny)
    }

    Connections {
        target: DisplayConfigurationService
        function onPendingOutputsChanged() {
            if (!DisplayConfigurationService.output(root.selectedName)
                    && DisplayConfigurationService.pendingOutputs.length)
                root.selectedName = DisplayConfigurationService.pendingOutputs[0].name
        }
    }

    component SettingCombo: Controls.ComboBox {
        id: combo
        height: 36
        textRole: "text"
        contentItem: Text {
            leftPadding: 10; rightPadding: 24
            text: combo.displayText
            color: Theme.fg
            font.family: Theme.fontFamily; font.pixelSize: Theme.fontSize - 1
            verticalAlignment: Text.AlignVCenter; elide: Text.ElideRight
        }
        indicator: Text {
            x: combo.width - width - 9; y: (combo.height - height) / 2
            text: "󰅂"; color: Theme.brightBlack
            font.family: Theme.fontFamily; font.pixelSize: 12
        }
        background: Rectangle {
            radius: Theme.radiusMedium; color: Theme.gray2
            border.width: 1; border.color: combo.activeFocus ? Theme.accent : Theme.gray5
        }
        popup: Controls.Popup {
            y: combo.height + 3; width: combo.width
            implicitHeight: Math.min(220, list.contentHeight + 8); padding: 4
            contentItem: ListView {
                id: list; clip: true; model: combo.popup.visible ? combo.delegateModel : null
                currentIndex: combo.highlightedIndex
            }
            background: Rectangle {
                radius: Theme.radiusMedium; color: Theme.gray2
                border.width: 1; border.color: Theme.gray5
            }
        }
        delegate: Controls.ItemDelegate {
            id: optionDelegate
            required property var modelData
            width: combo.width - 8; height: 30
            hoverEnabled: true
            contentItem: Text {
                text: typeof modelData === "object" ? modelData.text : String(modelData)
                color: optionDelegate.hovered || optionDelegate.highlighted ? Theme.accent : Theme.fg
                font.family: Theme.fontFamily; font.pixelSize: Theme.fontSize - 1
                verticalAlignment: Text.AlignVCenter
            }
            background: Rectangle {
                radius: Theme.radiusSmall
                color: optionDelegate.hovered || optionDelegate.highlighted ? Theme.gray3 : "transparent"
            }
        }
    }

    Column {
        anchors.fill: parent
        spacing: 10
        Row {
            width: parent.width; height: 28
            Text { width: parent.width - closeSettings.width; text: "Display settings"; color: Theme.fg; font.family: Theme.fontFamily; font.pixelSize: Theme.fontSize + 2; font.bold: true }
            Rectangle {
                id: closeSettings
                width: 28; height: 28; radius: Theme.radiusSmall
                color: closeSettingsMouse.containsMouse ? Theme.gray4 : Theme.gray2
                Text { anchors.centerIn: parent; text: "󰅖"; color: Theme.brightBlack; font.family: Theme.fontFamily; font.pixelSize: 15 }
                MouseArea { id: closeSettingsMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.visible = false }
            }
        }
        Rectangle {
            id: arrangement
            width: parent.width; height: 245
            radius: Theme.radiusMedium; color: Theme.gray1
            border.width: 1; border.color: Theme.gray5
            Text {
                anchors.left: parent.left; anchors.leftMargin: 12
                anchors.top: parent.top; anchors.topMargin: 10
                text: root.enabledOutputs.length > 1
                    ? "Drag each display freely to arrange its position"
                    : "Connect another display to arrange it"
                color: Theme.brightBlack
                font.family: Theme.fontFamily; font.pixelSize: Theme.fontSize - 1
            }
            Repeater {
                model: root.enabledOutputs
                Item {
                    id: monitorPosition
                    required property var modelData
                    property real dragStartX: 0
                    property real dragStartY: 0
                    x: 20 + (modelData.x - root.minimumX) * root.previewScale
                    y: 44 + (modelData.y - root.minimumY) * root.previewScale
                    width: Math.max(70, root.logicalWidth(modelData) * root.previewScale)
                    height: Math.max(44, root.logicalHeight(modelData) * root.previewScale)
                    z: monitorMouse.drag.active ? 10 : 1
                    Rectangle {
                        id: monitor
                        width: parent.width; height: parent.height
                        radius: Theme.radiusSmall
                        color: monitorPosition.modelData.name === root.selectedName
                            ? Qt.alpha(Theme.accent, 0.25) : Theme.gray3
                        border.width: monitorPosition.modelData.name === root.selectedName ? 2 : 1
                        border.color: monitorPosition.modelData.name === root.selectedName
                            ? Theme.accent : Theme.gray6
                        Column {
                            anchors.centerIn: parent
                            Text { anchors.horizontalCenter: parent.horizontalCenter; text: monitorPosition.modelData.name; color: Theme.fg; font.family: Theme.fontFamily; font.pixelSize: Theme.fontSize; font.bold: true }
                            Text { anchors.horizontalCenter: parent.horizontalCenter; text: monitorPosition.modelData.width + "×" + monitorPosition.modelData.height; color: Theme.brightBlack; font.family: Theme.fontFamily; font.pixelSize: Theme.fontSize - 2 }
                        }
                        MouseArea {
                            id: monitorMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: pressed ? Qt.ClosedHandCursor : Qt.OpenHandCursor
                            drag.target: monitor
                            drag.axis: Drag.XAndYAxis
                            drag.threshold: 3
                            onPressed: {
                                root.selectedName = monitorPosition.modelData.name
                                monitorPosition.dragStartX = monitorPosition.modelData.x
                                monitorPosition.dragStartY = monitorPosition.modelData.y
                            }
                            onReleased: {
                                const nextX = monitorPosition.dragStartX
                                    + monitor.x / root.previewScale
                                const nextY = monitorPosition.dragStartY
                                    + monitor.y / root.previewScale
                                monitor.x = 0
                                monitor.y = 0
                                root.moveOutput(monitorPosition.modelData, nextX, nextY)
                            }
                            onCanceled: {
                                monitor.x = 0
                                monitor.y = 0
                            }
                        }
                    }
                }
            }
        }
        Row {
            width: parent.width; height: 230; spacing: 12
            Column {
                width: 170; height: parent.height; spacing: 5
                Text { text: "Connected"; color: Theme.brightBlack; font.family: Theme.fontFamily; font.pixelSize: Theme.fontSize - 1 }
                Repeater {
                    model: DisplayConfigurationService.pendingOutputs
                    Rectangle {
                        required property var modelData
                        width: 170; height: 38; radius: Theme.radiusSmall
                        color: modelData.name === root.selectedName ? Qt.alpha(Theme.accent, 0.18) : Theme.gray2
                        border.width: 1; border.color: modelData.name === root.selectedName ? Theme.accent : Theme.gray5
                        Text { anchors.fill: parent; anchors.leftMargin: 10; verticalAlignment: Text.AlignVCenter; text: modelData.name; color: modelData.enabled ? Theme.fg : Theme.brightBlack; font.family: Theme.fontFamily; font.pixelSize: Theme.fontSize }
                        MouseArea { anchors.fill: parent; onClicked: root.selectedName = modelData.name }
                    }
                }
            }
            Column {
                width: parent.width - 182; spacing: 7
                Text { text: root.selected ? "Selected: " + root.selected.name : "Select a display"; color: Theme.fg; font.family: Theme.fontFamily; font.pixelSize: Theme.fontSize; font.bold: true }
                Grid {
                    visible: root.selected !== null
                    columns: 2; columnSpacing: 8; rowSpacing: 7
                    Text { width: 105; height: 36; verticalAlignment: Text.AlignVCenter; text: "Resolution"; color: Theme.brightBlack; font.family: Theme.fontFamily; font.pixelSize: Theme.fontSize }
                    SettingCombo { width: 300; model: root.resolutions(root.selected); currentIndex: model.findIndex(item => item.value === (root.selected ? root.selected.width + "x" + root.selected.height : "")); onActivated: index => root.setResolution(model[index].value) }
                    Text { width: 105; height: 36; verticalAlignment: Text.AlignVCenter; text: "Refresh rate"; color: Theme.brightBlack; font.family: Theme.fontFamily; font.pixelSize: Theme.fontSize }
                    SettingCombo { width: 300; model: root.rates(root.selected).map(rate => ({ text: Number(rate).toFixed(2).replace(/\.00$/, "") + " Hz", value: rate })); currentIndex: model.findIndex(item => root.selected && Math.abs(item.value - root.selected.refreshRate) < 0.001); onActivated: index => DisplayConfigurationService.updateOutput(root.selected.name, { refreshRate: model[index].value }) }
                    Text { width: 105; height: 36; verticalAlignment: Text.AlignVCenter; text: "Scale"; color: Theme.brightBlack; font.family: Theme.fontFamily; font.pixelSize: Theme.fontSize }
                    SettingCombo { width: 300; model: [1, 1.25, 1.5, 1.75, 2].map(v => ({ text: v.toFixed(2).replace(/0$/, ""), value: v })); currentIndex: model.findIndex(item => root.selected && item.value === root.selected.scale); onActivated: index => DisplayConfigurationService.updateOutput(root.selected.name, { scale: model[index].value }) }
                    Text { width: 105; height: 36; verticalAlignment: Text.AlignVCenter; text: "Orientation"; color: Theme.brightBlack; font.family: Theme.fontFamily; font.pixelSize: Theme.fontSize }
                    SettingCombo { width: 300; model: [{text:"Landscape",value:"normal"},{text:"Portrait left",value:"left"},{text:"Portrait right",value:"right"},{text:"Landscape flipped",value:"inverted"}]; currentIndex: model.findIndex(item => root.selected && item.value === root.selected.transform); onActivated: index => DisplayConfigurationService.updateOutput(root.selected.name, { transform: model[index].value }) }
                    Text { width: 105; height: 32; verticalAlignment: Text.AlignVCenter; text: "Options"; color: Theme.brightBlack; font.family: Theme.fontFamily; font.pixelSize: Theme.fontSize }
                    Row {
                        width: 300; height: 32; spacing: 6
                        Repeater {
                            model: [
                                { text: "Enabled", active: root.selected?.enabled === true, kind: "enabled" },
                                { text: "Primary", active: root.selected?.primary === true, kind: "primary" },
                                { text: "Mirror", active: String(root.selected?.mirrorOf ?? "") !== "", kind: "mirror" }
                            ]
                            Rectangle {
                                required property var modelData
                                width: 94; height: 32; radius: Theme.radiusSmall
                                color: modelData.active ? Qt.alpha(Theme.accent, 0.22) : Theme.gray2
                                border.width: 1; border.color: modelData.active ? Theme.accent : Theme.gray5
                                opacity: modelData.kind === "primary" && !DisplayConfigurationService.supportsPrimary
                                    || modelData.kind === "mirror" && (!DisplayConfigurationService.supportsMirroring
                                        || DisplayConfigurationService.pendingOutputs.length < 2) ? 0.45 : 1
                                Text { anchors.centerIn: parent; text: modelData.text; color: modelData.active ? Theme.accent : Theme.fg; font.family: Theme.fontFamily; font.pixelSize: Theme.fontSize - 1 }
                                MouseArea {
                                    anchors.fill: parent
                                    enabled: parent.opacity === 1
                                    onClicked: {
                                        if (modelData.kind === "enabled")
                                            DisplayConfigurationService.updateOutput(root.selected.name, { enabled: !root.selected.enabled })
                                        else if (modelData.kind === "primary")
                                            DisplayConfigurationService.setPrimary(root.selected.name)
                                        else {
                                            const target = DisplayConfigurationService.pendingOutputs.find(
                                                output => output.name !== root.selected.name && output.enabled)
                                            DisplayConfigurationService.updateOutput(root.selected.name, {
                                                mirrorOf: root.selected.mirrorOf ? "" : String(target?.name ?? "")
                                            })
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
        Row {
            width: parent.width; height: 38; spacing: 8; layoutDirection: Qt.RightToLeft
            Rectangle {
                width: 100; height: 38; radius: Theme.radiusMedium
                color: applyMouse.containsMouse ? Theme.brightOrange : Theme.accent
                Text { anchors.centerIn: parent; text: DisplayConfigurationService.applying ? "Applying…" : "Apply"; color: Theme.selfg; font.family: Theme.fontFamily; font.pixelSize: Theme.fontSize; font.bold: true }
                MouseArea { id: applyMouse; anchors.fill: parent; enabled: !DisplayConfigurationService.applying; hoverEnabled: true; onClicked: DisplayConfigurationService.apply() }
            }
            Rectangle {
                width: 100; height: 38; radius: Theme.radiusMedium; color: cancelMouse.containsMouse ? Theme.gray3 : Theme.gray2; border.width: 1; border.color: Theme.gray5
                Text { anchors.centerIn: parent; text: "Cancel"; color: Theme.fg; font.family: Theme.fontFamily; font.pixelSize: Theme.fontSize }
                MouseArea { id: cancelMouse; anchors.fill: parent; hoverEnabled: true; onClicked: { DisplayConfigurationService.resetPending(); root.visible = false } }
            }
            Text { width: parent.width - 216; anchors.verticalCenter: parent.verticalCenter; text: DisplayConfigurationService.error; color: Theme.red; elide: Text.ElideRight; font.family: Theme.fontFamily; font.pixelSize: Theme.fontSize - 1 }
        }
    }

    Rectangle {
        anchors.fill: parent
        visible: DisplayConfigurationService.confirmationPending
        z: 50; radius: Theme.radiusLarge; color: Theme.bg
        border.width: 2; border.color: Theme.brightOrange
        Column {
            anchors.centerIn: parent; width: Math.min(430, parent.width - 40); spacing: 14
            Text { width: parent.width; horizontalAlignment: Text.AlignHCenter; text: "Keep these display settings?"; color: Theme.fg; font.family: Theme.fontFamily; font.pixelSize: Theme.fontSize + 3; font.bold: true }
            Text { width: parent.width; horizontalAlignment: Text.AlignHCenter; text: "Reverting in " + DisplayConfigurationService.secondsRemaining + " seconds…"; color: Theme.brightBlack; font.family: Theme.fontFamily; font.pixelSize: Theme.fontSize }
            Row {
                anchors.horizontalCenter: parent.horizontalCenter; spacing: 8
                Repeater {
                    model: [{text:"Revert",keep:false},{text:"Keep",keep:true}]
                    Rectangle {
                        required property var modelData
                        width: 110; height: 38; radius: Theme.radiusMedium
                        color: modelData.keep ? Theme.accent : Theme.gray2
                        border.width: 1; border.color: modelData.keep ? Theme.accent : Theme.gray5
                        Text { anchors.centerIn: parent; text: modelData.text; color: modelData.keep ? Theme.selfg : Theme.fg; font.family: Theme.fontFamily; font.pixelSize: Theme.fontSize; font.bold: modelData.keep }
                        MouseArea { anchors.fill: parent; onClicked: modelData.keep ? DisplayConfigurationService.keep() : DisplayConfigurationService.revert() }
                    }
                }
            }
        }
    }
}
