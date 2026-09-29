pragma ComponentBehavior: Bound

import QtQuick
import "../.."

Item {
    id: root
    property color dotColor: Theme.fg
    property bool disconnected: false
    property bool warning: false
    implicitWidth: Theme.iconSize
    implicitHeight: Theme.iconSize

    readonly property real dot: Math.max(2, width * 0.23)
    readonly property real middle: (width - dot) / 2
    readonly property real end: width - dot

    component Mark: Rectangle {
        width: root.dot
        height: width
        radius: width / 2
        color: root.dotColor
    }

    Mark { x: 0; y: 0; opacity: 0.28 }
    Mark { x: root.middle; y: 0; opacity: 0.28 }
    Mark { x: root.end; y: 0; opacity: 0.28 }
    Mark { x: 0; y: root.middle }
    Mark { x: root.middle; y: root.middle }
    Mark { x: root.end; y: root.middle }
    Mark { x: 0; y: root.end; opacity: 0.28 }
    Mark { x: root.middle; y: root.end }
    Mark { x: root.end; y: root.end; opacity: 0.28 }

    Rectangle {
        visible: root.disconnected
        anchors.centerIn: parent
        width: parent.width * 1.2
        height: 2
        radius: 1
        color: root.dotColor
        rotation: -45
    }

    Rectangle {
        visible: root.warning
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        width: Math.max(7, parent.width * 0.42)
        height: width
        radius: width / 2
        color: Theme.warning
        border.width: 1
        border.color: Theme.bg
        Text {
            anchors.centerIn: parent
            text: "!"
            color: Theme.bg
            font.family: Theme.fontFamily
            font.bold: true
            font.pixelSize: Math.max(6, parent.height - 2)
        }
    }
}
