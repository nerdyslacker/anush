pragma Singleton

import QtQuick
import Quickshell

// Keeps one shell popup active while retaining named coordination events for
// related views such as Network, Bluetooth, and Hotspot.
Singleton {
    signal opening(string name, var owner)
    property var activePopup: null

    function activate(owner) {
        if (activePopup === owner)
            return
        const previous = activePopup
        activePopup = owner
        if (previous && previous.visible)
            previous.visible = false
    }

    function deactivate(owner) {
        if (activePopup === owner)
            activePopup = null
    }

    function requestOpen(name, owner) {
        opening(name, owner)
    }
}
