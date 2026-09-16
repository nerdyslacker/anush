//@ pragma UseQApplication
import QtQuick
import Quickshell

ShellRoot {
    // Keep IPC and autosave alive even when the Notepad bar button is disabled.
    Component.onCompleted: NotepadState.initialize()

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
