pragma Singleton

import QtQuick
import Quickshell

// Small, opt-in coordinator for popups which must be mutually exclusive.
// Existing independent popups keep their current behaviour; connectivity
// popups announce themselves here so Network and Bluetooth cannot overlap.
Singleton {
    signal opening(string name, var owner)

    function requestOpen(name, owner) {
        opening(name, owner)
    }
}
