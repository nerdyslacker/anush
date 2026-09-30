//@ pragma UseQApplication
import QtQuick
import Quickshell

ShellRoot {
    Timer {
        id: screenHotplugReload
        interval: 350
        onTriggered: Quickshell.reload(true)
    }

    Connections {
        target: Wm
        function onPhysicalOutputsChanged() {
            screenHotplugReload.restart()
        }
    }

    // Keep global actions alive even when their bar buttons are disabled.
    Component.onCompleted: {
        ShellControl.protocolVersion
        ShellActions.protocolVersion
        NotepadState.initialize()
        ColorPickerState.initialize()
        TailscaleService.initialize()
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
