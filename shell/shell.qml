//@ pragma UseQApplication
import QtQuick
import Quickshell

ShellRoot {
    readonly property var barScreens: BarVisibility.showOnAllMonitors
        ? Quickshell.screens
        : Quickshell.screens.length > 0 ? [Quickshell.screens[0]] : []

    Timer {
        id: screenHotplugReload
        interval: 350
        onTriggered: Quickshell.reload(true)
    }

    Connections {
        target: Wm
        function onPhysicalOutputConnected() {
            screenHotplugReload.restart()
        }
        function onPhysicalOutputDisconnected() {
            screenHotplugReload.stop()
        }
    }

    // IPC control stays available, but optional widget services are started by
    // their widgets so a disabled widget has no background lifecycle.
    Component.onCompleted: {
        ShellControl.protocolVersion
        ShellActions.protocolVersion
    }

    Keybindings {}
    Notice {}
    Reminder {}

    Variants {
        model: barScreens
        Bar {}
    }

    Variants {
        model: BarVisibility.enabled("notepad") ? barScreens : []
        NotepadSidebar {}
    }
}
