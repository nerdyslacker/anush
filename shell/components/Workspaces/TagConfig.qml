pragma Singleton

import QtQuick
import "../.."
import Quickshell

Singleton {
    id: root

    property int count: 9
    property bool showNumbers: true
    property bool dynamicWorkspaces: false

    function save(newCount, numbersVisible, dynamic) {
        count = Math.max(1, Math.min(20, Math.round(newCount)))
        showNumbers = numbersVisible
        dynamicWorkspaces = dynamic === true
        ShellState.updateSection("tags", {
            count: count,
            showNumbers: showNumbers,
            dynamicWorkspaces: dynamicWorkspaces
        })
    }

    function loadState() {
        const saved = ShellState.state.tags
        const savedCount = Number(saved.count)
        if (isFinite(savedCount))
            root.count = Math.max(1, Math.min(20, Math.round(savedCount)))
        root.showNumbers = saved.showNumbers !== false
        root.dynamicWorkspaces = saved.dynamicWorkspaces === true
    }

    Connections {
        target: ShellState
        function onStateChanged() { root.loadState() }
        function onReadyChanged() { if (ShellState.ready) root.loadState() }
    }

    Component.onCompleted: if (ShellState.ready) loadState()
}
