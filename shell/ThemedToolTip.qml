import QtQuick
import QtQuick.Controls as Controls
import "."

Controls.ToolTip {
    id: root

    delay: 350
    padding: 8
    popupType: Controls.Popup.Window

    background: Rectangle {
        radius: Theme.radiusSmall
        color: Theme.surface
        border.width: 1
        border.color: Theme.outline
    }
    contentItem: Text {
        text: root.text
        color: Theme.foreground
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontSize - 1
        font.bold: true
        verticalAlignment: Text.AlignVCenter
    }
}
