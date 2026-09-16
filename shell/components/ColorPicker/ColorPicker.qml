import QtQuick
import "../.."

BarModule {
    id: root

    icon: ""
    iconColor: ColorPickerState.currentColor !== ""
        ? ColorPickerState.currentColor : Theme.magenta
    compactIconColor: iconColor

    onClicked: mouse => {
        if (mouse.button === Qt.RightButton) {
            pickerPopup.toggleAtAnchor()
            return
        }
        if (mouse.button === Qt.LeftButton) {
            pickerPopup.visible = false
            ColorPickerState.pick()
        }
    }

    ColorPickerPopup {
        id: pickerPopup
        anchorItem: root
    }
}
