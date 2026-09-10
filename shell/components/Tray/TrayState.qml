pragma Singleton

import QtQuick
import "../.."
import Quickshell

// Persistent placement for StatusNotifier items. IDs come from the SNI
// protocol and remain stable when an application recreates its tray item.
Singleton {
    id: root

    property var hiddenIds: []
    property bool ready: false

    function itemKey(item) {
        if (!item)
            return ""
        const id = String(item.id ?? "")
        if (id !== "")
            return "id:" + id
        return "title:" + String(item.title ?? "")
    }

    function isHidden(item) {
        return hiddenIds.indexOf(itemKey(item)) !== -1
    }

    function setHidden(item, hidden) {
        const key = itemKey(item)
        if (key === "")
            return
        const next = hiddenIds.slice()
        const index = next.indexOf(key)
        if (hidden && index === -1)
            next.push(key)
        else if (!hidden && index !== -1)
            next.splice(index, 1)
        else
            return
        hiddenIds = next
        ShellState.updateSection("tray", { hidden: next })
    }

    function loadState() {
        const saved = ShellState.state.tray.hidden
        root.hiddenIds = Array.isArray(saved)
            ? saved.filter(value => typeof value === "string") : []
        root.ready = true
    }

    Connections {
        target: ShellState
        function onStateChanged() { root.loadState() }
        function onReadyChanged() { if (ShellState.ready) root.loadState() }
    }

    Component.onCompleted: if (ShellState.ready) loadState()
}
