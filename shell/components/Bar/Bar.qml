import QtQuick
import "../.."
import Quickshell

// PanelWindow publishes the EWMH dock/strut that skarwm uses to reserve the
// bar's space. In fit-content mode the native window itself becomes compact,
// leaving the surrounding desktop outside its input region.
PanelWindow {
    id: root
    property var modelData
    readonly property bool vertical: BarVisibility.verticalBar
    readonly property bool compactHorizontal: BarVisibility.fitContent && !vertical
    readonly property bool compactVertical: BarVisibility.fitContent && vertical
    readonly property bool compact: compactHorizontal || compactVertical
    readonly property bool separated: BarVisibility.separateSections && !compact
    readonly property bool separatedHorizontal: separated && !vertical
    readonly property bool separatedVertical: separated && vertical
    readonly property real compactScreenMargin: 8
    readonly property int floatingGap: BarVisibility.floating ? Theme.surfaceGap : 0
    readonly property real screenLongExtent: vertical ? Number(modelData?.height ?? height) : Number(modelData?.width ?? width)
    readonly property real compactContentWidth: compactContent.implicitWidth + 12
    readonly property real compactContentHeight: compactVerticalContent.implicitHeight + 12
    readonly property real sectionEdgeOffset: BarVisibility.floating ? 0 : Theme.surfaceGap
    readonly property real maximumCompactExtent: Math.max(Theme.effectiveBarHeight, screenLongExtent > 0 ? screenLongExtent - 2 * compactScreenMargin : vertical ? compactContentHeight : compactContentWidth)
    readonly property real longExtent: vertical ? height : width
    readonly property var widgetSources: ({
            launcher: Qt.resolvedUrl("../Launcher/Launcher.qml"),
            tags: Qt.resolvedUrl("../Workspaces/Tags.qml"),
            windowList: Qt.resolvedUrl("../Workspaces/WindowList.qml"),
            layout: Qt.resolvedUrl("../Workspaces/LayoutButton.qml"),
            title: Qt.resolvedUrl("../Workspaces/Title.qml"),
            scratchpads: Qt.resolvedUrl("../Workspaces/Scratchpads.qml"),
            media: Qt.resolvedUrl("../Media/Media.qml"),
            weather: Qt.resolvedUrl("../Weather/Weather.qml"),
            metrics: Qt.resolvedUrl("../Metrics/Metrics.qml"),
            battery: Qt.resolvedUrl("../Battery/Battery.qml"),
            brightness: Qt.resolvedUrl("../Battery/Brightness.qml"),
            volume: Qt.resolvedUrl("../Audio/Volume.qml"),
            micIndicator: Qt.resolvedUrl("../Audio/MicMute.qml"),
            network: Qt.resolvedUrl("../Network/Network.qml"),
            bluetooth: Qt.resolvedUrl("../Network/Bluetooth.qml"),
            keyboard: Qt.resolvedUrl("../Keyboard/KeyboardLayout.qml"),
            clipboard: Qt.resolvedUrl("../Clipboard/Clipboard.qml"),
            notepad: Qt.resolvedUrl("../Notepad/Notepad.qml"),
            tray: Qt.resolvedUrl("../Tray/Tray.qml"),
            notifications: Qt.resolvedUrl("../Notifications/Bell.qml"),
            clock: Qt.resolvedUrl("../Session/Clock.qml"),
            capsLock: Qt.resolvedUrl("../Keyboard/CapsLock.qml"),
            screenshot: Qt.resolvedUrl("../Session/Screenshot.qml"),
            commands: Qt.resolvedUrl("../Session/Commands.qml")
        })
    screen: modelData
    anchors {
        top: BarVisibility.barPosition === "top" || (root.vertical && !root.compactVertical)
        bottom: BarVisibility.barPosition === "bottom" || (root.vertical && !root.compactVertical)
        left: BarVisibility.barPosition === "left" || (!root.vertical && !root.compactHorizontal)
        right: BarVisibility.barPosition === "right" || (!root.vertical && !root.compactHorizontal)
    }
    margins {
        top: BarVisibility.barPosition === "top" || (root.vertical && !root.compactVertical) ? root.floatingGap : 0
        bottom: BarVisibility.barPosition === "bottom" || (root.vertical && !root.compactVertical) ? root.floatingGap : 0
        left: BarVisibility.barPosition === "left" || (!root.vertical && !root.compactHorizontal) ? root.floatingGap : 0
        right: BarVisibility.barPosition === "right" || (!root.vertical && !root.compactHorizontal) ? root.floatingGap : 0
    }
    implicitWidth: compactHorizontal ? Math.min(maximumCompactExtent, Math.max(Theme.effectiveBarHeight, compactContentWidth)) : Theme.effectiveBarHeight
    implicitHeight: compactVertical ? Math.min(maximumCompactExtent, Math.max(Theme.effectiveBarHeight, compactContentHeight)) : Theme.effectiveBarHeight
    // Be explicit: Quickshell otherwise derives the X11 reservation from the
    // panel's height, which is the full screen dimension for side bars. The WM
    // adds its configured outer gap outside this physical reservation.
    exclusiveZone: Math.round((root.vertical ? root.width : root.height) + root.floatingGap)
    // Keep the native window surface ARGB. Giving PanelWindow a translucent
    // color can be flattened against black by X11 compositors; the child
    // rectangle below paints the requested opacity onto this clear surface.
    color: "transparent"
    visible: Theme.barStateReady && BarVisibility.showOnScreen(modelData)

    WindowOverview {
        anchorItem: panel
    }

    // Commands participates in the reorderable loaders, but its settings
    // popup must outlive those delegates. This stable proxy is positioned on
    // the Commands button whenever the popup opens.
    Item {
        id: barSettingsAnchor
        width: Theme.moduleHeight
        height: Theme.moduleHeight
    }

    BarSettingsPopup {
        id: persistentBarSettings
        anchorItem: barSettingsAnchor
    }

    // Modules provide their own compact upright representation on side bars.
    component WidgetLoader: Item {
        id: widgetSlot
        required property string widgetKey
        readonly property real naturalWidth: moduleLoader.item ? moduleLoader.item.implicitWidth : 0
        readonly property real naturalHeight: moduleLoader.item ? moduleLoader.item.implicitHeight : Theme.moduleHeight
        readonly property real moduleWidth: widgetKey === "title" ? Math.min(naturalWidth, root.screenLongExtent * 0.34) : naturalWidth
        readonly property bool itemShown: moduleLoader.status === Loader.Ready && moduleLoader.item && moduleLoader.item.visible

        // Stay visible while reading the loaded item's own visibility. Making
        // the parent depend on child.visible creates a false visibility loop.
        visible: moduleLoader.active
        width: itemShown ? moduleWidth : 0
        height: itemShown ? naturalHeight : 0

        Loader {
            id: moduleLoader
            anchors.centerIn: parent
            active: BarVisibility.enabled(widgetSlot.widgetKey)
            source: root.widgetSources[widgetSlot.widgetKey] ?? ""
            width: widgetSlot.moduleWidth
            height: widgetSlot.naturalHeight
            onLoaded: {
                if (widgetSlot.widgetKey === "windowList" && item)
                    item.barScreen = root.modelData;
                if (widgetSlot.widgetKey === "notepad" && item)
                    item.barScreen = root.modelData;
                if (widgetSlot.widgetKey === "commands" && item) {
                    item.barSettingsPopup = persistentBarSettings;
                    item.barSettingsAnchor = barSettingsAnchor;
                }
            }
        }
    }

    component WidgetCluster: Rectangle {
        id: cluster
        required property string clusterName
        readonly property var entries: BarVisibility.cluster(clusterName)
        readonly property real contentImplicitWidth: root.vertical ? verticalLayout.implicitWidth : horizontalLayout.implicitWidth
        readonly property real contentImplicitHeight: root.vertical ? verticalLayout.implicitHeight : horizontalLayout.implicitHeight
        readonly property bool contentPresent: root.vertical ? verticalLayout.implicitHeight > 0 : horizontalLayout.implicitWidth > 0
        readonly property real sectionPadding: root.separated && contentPresent ? 6 : 0
        implicitWidth: root.separatedVertical && contentPresent ? root.width : root.vertical ? contentImplicitWidth : contentImplicitWidth + 2 * sectionPadding
        implicitHeight: root.separatedHorizontal && contentPresent ? root.height : root.vertical ? contentImplicitHeight + 2 * sectionPadding : contentImplicitHeight
        width: implicitWidth
        height: implicitHeight
        radius: Theme.radiusMedium
        color: root.separated && contentPresent ? Qt.alpha(Theme.bg, Theme.barBackgroundOpacity) : "transparent"

        Row {
            id: horizontalLayout
            visible: !root.vertical
            spacing: 4
            x: cluster.sectionPadding
            y: (cluster.height - height) / 2

            Repeater {
                model: horizontalLayout.visible ? cluster.entries : []
                WidgetLoader {
                    required property string modelData
                    widgetKey: modelData
                }
            }
        }

        Column {
            id: verticalLayout
            visible: root.vertical
            spacing: 4
            x: (cluster.width - width) / 2
            y: cluster.sectionPadding

            Repeater {
                model: verticalLayout.visible ? cluster.entries : []
                WidgetLoader {
                    required property string modelData
                    widgetKey: modelData
                }
            }
        }
    }

    Rectangle {
        id: panel
        anchors.fill: parent
        clip: root.compact
        color: root.separated ? "transparent" : Qt.alpha(Theme.bg, Theme.barBackgroundOpacity)
        // The panel is flush with screen edges, so only round it when the
        // configured radius can be shown without changing its geometry.
        radius: Theme.radiusMedium

        // This single measurement row is the canonical natural width for all
        // three sections. Proxies mirror cluster implicit sizes without
        // loading any widget twice, so future widgets participate naturally.
        Row {
            id: compactContent
            // Keep the positioner active so its implicit width remains live;
            // the proxy items have no visual or pointer content.
            opacity: 0
            enabled: false
            spacing: 12

            Item {
                width: leftCluster.implicitWidth
                height: 1
                visible: width > 0
            }
            Item {
                width: centerCluster.implicitWidth
                height: 1
                visible: width > 0
            }
            Item {
                width: endCluster.implicitWidth
                height: 1
                visible: width > 0
            }
        }

        Column {
            id: compactVerticalContent
            opacity: 0
            enabled: false
            spacing: 12

            Item {
                width: 1
                height: leftCluster.implicitHeight
                visible: height > 0
            }
            Item {
                width: 1
                height: centerCluster.implicitHeight
                visible: height > 0
            }
            Item {
                width: 1
                height: endCluster.implicitHeight
                visible: height > 0
            }
        }

        Item {
            id: content
            anchors.fill: parent
            implicitWidth: root.compactContentWidth
            implicitHeight: root.compactContentHeight

            WidgetCluster {
                id: leftCluster
                clusterName: "left"
                x: root.vertical ? (parent.width - width) / 2 : root.separatedHorizontal ? root.sectionEdgeOffset : 6
                y: root.vertical ? root.separatedVertical ? root.sectionEdgeOffset : 6 : (parent.height - height) / 2
            }

            // Full-width mode keeps the middle group genuinely centered and
            // only nudges it around crowded edge groups. Compact mode places
            // each non-empty section in natural left-to-right order.
            WidgetCluster {
                id: centerCluster
                clusterName: "center"
                readonly property real gapStart: root.vertical ? leftCluster.y + leftCluster.height + 12 : leftCluster.x + leftCluster.width + 12
                readonly property real gapEnd: root.vertical ? endCluster.y - 12 : endCluster.x - 12
                readonly property real availableLength: Math.max(0, gapEnd - gapStart)
                width: root.compactHorizontal ? implicitWidth : root.vertical ? implicitWidth : Math.min(implicitWidth, availableLength)
                height: root.compactVertical ? implicitHeight : root.vertical ? Math.min(implicitHeight, availableLength) : implicitHeight
                clip: root.compactVertical ? false : root.vertical ? height < implicitHeight : width < implicitWidth
                x: root.vertical ? (parent.width - width) / 2 : root.compactHorizontal ? 6 + leftCluster.width + (leftCluster.width > 0 && width > 0 ? 12 : 0) : Math.max(gapStart, Math.min((parent.width - width) / 2, gapEnd - width))
                y: root.vertical ? root.compactVertical ? 6 + leftCluster.height + (leftCluster.height > 0 && height > 0 ? 12 : 0) : Math.max(gapStart, Math.min((parent.height - height) / 2, gapEnd - height)) : (parent.height - height) / 2
            }

            WidgetCluster {
                id: endCluster
                clusterName: "right"
                x: root.vertical ? (parent.width - width) / 2 : root.compactHorizontal ? centerCluster.width > 0 ? centerCluster.x + centerCluster.width + (width > 0 ? 12 : 0) : 6 + leftCluster.width + (leftCluster.width > 0 && width > 0 ? 12 : 0) : parent.width - width - (root.separatedHorizontal ? root.sectionEdgeOffset : 6)
                y: root.vertical ? root.compactVertical ? centerCluster.height > 0 ? centerCluster.y + centerCluster.height + (height > 0 ? 12 : 0) : 6 + leftCluster.height + (leftCluster.height > 0 && height > 0 ? 12 : 0) : parent.height - height - (root.separatedVertical ? root.sectionEdgeOffset : 6) : (parent.height - height) / 2
            }
        }
    }
}
