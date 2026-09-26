pragma Singleton

import QtQuick
import "../.."
import Quickshell

Singleton {
    id: root

    property int count: 9
    property bool showNumbers: true
    property bool dynamicWorkspaces: false
    property bool limitVisibleTags: false
    property int visibleTagLimit: 5

    function save(newCount, numbersVisible, dynamic, limitEnabled, newLimit) {
        count = Math.max(1, Math.min(20, Math.round(newCount)))
        showNumbers = numbersVisible
        dynamicWorkspaces = dynamic === true
        limitVisibleTags = limitEnabled === true
        visibleTagLimit = Math.max(1, Math.min(20, Math.round(newLimit)))
        ShellState.updateSection("tags", {
            count: count,
            showNumbers: showNumbers,
            dynamicWorkspaces: dynamicWorkspaces,
            limitVisibleTags: limitVisibleTags,
            visibleTagLimit: visibleTagLimit
        })
    }

    function loadState() {
        const saved = ShellState.state.tags
        const savedCount = Number(saved.count)
        if (isFinite(savedCount))
            root.count = Math.max(1, Math.min(20, Math.round(savedCount)))
        root.showNumbers = saved.showNumbers !== false
        root.dynamicWorkspaces = saved.dynamicWorkspaces === true
        root.limitVisibleTags = saved.limitVisibleTags === true
        const savedLimit = Number(saved.visibleTagLimit)
        if (isFinite(savedLimit))
            root.visibleTagLimit = Math.max(1, Math.min(20, Math.round(savedLimit)))
    }

    Connections {
        target: ShellState
        function onStateChanged() { root.loadState() }
        function onReadyChanged() { if (ShellState.ready) root.loadState() }
    }

    Component.onCompleted: if (ShellState.ready) loadState()
}
