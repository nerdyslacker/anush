//@ pragma UseQApplication
import QtQuick
import Quickshell

ShellRoot {
    // Keep global actions alive even when their bar buttons are disabled.
    Component.onCompleted: {
        ShellControl.protocolVersion
        NotepadState.initialize()
        ColorPickerState.initialize()
    }

    Keybindings {}
    Notice {}
    Reminder {}

    Variants {
        model: Quickshell.screens
        Bar {}
    }

    Variants {
        model: Quickshell.screens
        NotepadSidebar {}
    }
}
