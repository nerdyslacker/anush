import QtQuick
import "../.."

BarModule {
    id: root

    property var barScreen

    icon: "󰎞"
    iconColor: NotepadState.status === "error"
        || NotepadState.status === "conflict" ? Theme.error
        : NotepadState.dirty ? Theme.warning : Theme.accent
    label: NotepadState.dirty ? "•" : ""

    onClicked: NotepadState.toggleForScreen(root.barScreen)
}
