pragma ComponentBehavior: Bound

import QtQuick
import "../.."

Item {
    id: root

    property var layoutData: null
    property color masterColor: Theme.cyan
    property color paneColor: Qt.alpha(Theme.fg, 0.38)
    readonly property string layout: diagramFor(layoutData)
    readonly property var shapes: ({
        tiled: [[0, 0, .5, 1], [.5, 0, .5, .5], [.5, .5, .3, .5], [.8, .5, .2, .5]],
        monocle: [[0, 0, 1, 1]],
        tall: [[0, 0, .58, 1], [.58, 0, .42, .5], [.58, .5, .42, .5]],
        rtall: [[.42, 0, .58, 1], [0, 0, .42, .5], [0, .5, .42, .5]],
        wide: [[0, 0, 1, .58], [0, .58, .5, .42], [.5, .58, .5, .42]],
        rwide: [[0, .42, 1, .58], [0, 0, .5, .42], [.5, 0, .5, .42]],
        splitHorizontal: [[0, 0, .5, 1], [.5, 0, .5, 1]],
        splitVertical: [[0, 0, 1, .5], [0, .5, 1, .5]],
        grid: [[0, 0, .5, .5], [.5, 0, .5, .5], [0, .5, .5, .5], [.5, .5, .5, .5]],
        rgrid: [[.5, .5, .5, .5], [0, .5, .5, .5], [.5, 0, .5, .5], [0, 0, .5, .5]],
        even: [[0, 0, .25, 1], [.25, 0, .25, 1], [.5, 0, .25, 1], [.75, 0, .25, 1]],
        tabbed: [[0, 0, .32, .24], [0, .26, 1, .74], [.34, 0, .31, .24], [.67, 0, .33, .24]],
        stacking: [[.04, 0, .92, .31], [.04, .345, .92, .31], [.04, .69, .92, .31]],
        dwindle: [[0, 0, .52, 1], [.52, 0, .48, .52], [.52, .52, .25, .48], [.77, .52, .23, .48]],
        floating: [[.02, .18, .62, .7], [.36, .02, .61, .66], [.2, .42, .58, .56]]
    })

    function diagramFor(value) {
        const command = String(value?.command ?? "").toLowerCase()
        const name = String(value?.name ?? "").toLowerCase()
        const combined = command + " " + name
        if (command === "splith" || name === "split horizontal")
            return "splitHorizontal"
        if (command === "splitv" || name === "split vertical")
            return "splitVertical"
        if (combined.includes("float") || command === "><>") return "floating"
        if (combined.includes("tab")) return "tabbed"
        if (combined.includes("stack")) return "stacking"
        if (combined.includes("monocle") || combined.includes("max")
                || command === "[m]") return "monocle"
        if (combined.includes("dwindle") || combined.includes("fibonacci"))
            return "dwindle"
        if (combined.includes("rgrid")) return "rgrid"
        if (combined.includes("grid")) return "grid"
        if (combined.includes("even")) return "even"
        if (combined.includes("rtall")) return "rtall"
        if (combined.includes("rwide")) return "rwide"
        if (combined.includes("wide") || combined.includes("horizontal")
                || combined.includes("vertical-scrolling")) return "wide"
        if (combined.includes("tall") || combined.includes("vertical")
                || command === "[]=") return "tall"
        return "tiled"
    }

    Repeater {
        model: 4

        Rectangle {
            required property int index
            readonly property var panes: root.shapes[root.layout]
                ?? root.shapes.tiled
            readonly property var geometry:
                panes[Math.min(index, panes.length - 1)]
            readonly property real inset: 0.75

            x: geometry[0] * root.width + inset
            y: geometry[1] * root.height + inset
            width: geometry[2] * root.width - 2 * inset
            height: geometry[3] * root.height - 2 * inset
            radius: 2
            color: index === 0 ? root.masterColor : root.paneColor
            opacity: index < panes.length ? 1 : 0

            Behavior on x { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
            Behavior on y { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
            Behavior on width { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
            Behavior on height { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
            Behavior on opacity { NumberAnimation { duration: 180 } }
            Behavior on color { ColorAnimation { duration: 250 } }
        }
    }
}
