import QtQuick
import Quickshell

Scope {
    id: root

    property string name: "unknown"
    property bool active: false
    property bool connected: false
    readonly property string connectionState: !active ? "inactive"
        : connected ? "connected" : "disconnected"
    property var capabilities: ({})
    property var screens: []
    property var workspaces: []
    property var windows: []
    property var layouts: []

    signal changed()
    signal actionFailed(string action, string reason)
    signal overviewCommand(string action)
    signal uiEvent(var event)
    signal physicalOutputConnected()
    signal physicalOutputDisconnected()

    function start() {}
    function stop() {}
    function refresh() {}

    function unsupported(action) {
        actionFailed(action, name + " does not support " + action)
        return false
    }

    function switchWorkspace(id, screenId) {
        return unsupported("switchWorkspace")
    }
    function focusWindow(id) { return unsupported("focusWindow") }
    function focusScreen(id) { return unsupported("focusScreen") }
    function moveWindowToWorkspace(windowId, workspaceId) {
        return unsupported("moveWindowToWorkspace")
    }
    function moveWindowToScreen(windowId, screenId) {
        return unsupported("moveWindowToScreen")
    }
    function closeWindow(id) { return unsupported("closeWindow") }
    function sendFocusedWindowToWorkspace(workspaceId) {
        return unsupported("moveWindowToWorkspace")
    }
    function setLayout(command) { return unsupported("setLayout") }
    function setGaps(value) { return unsupported("setGaps") }
    function setDecorationsEnabled(enabled) {
        return unsupported("setDecorationsEnabled")
    }
    function addReminder(minutes, message) {
        return unsupported("addReminder")
    }
    function reloadWindowManager() {
        return unsupported("reloadWindowManager")
    }
    function quitWindowManager() {
        return unsupported("quitWindowManager")
    }
    function showKeybindings() {
        return unsupported("showKeybindings")
    }
    function sendToScratchpad(id) { return unsupported("sendToScratchpad") }
    function toggleScratchpad(register) {
        return unsupported("toggleScratchpad")
    }
    function setDecorationStyle(style) {
        return unsupported("setDecorationStyle")
    }
}
