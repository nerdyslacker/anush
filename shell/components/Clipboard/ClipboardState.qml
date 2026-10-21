pragma Singleton

import QtQuick
import "../.."
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    readonly property bool widgetEnabled: BarVisibility.enabled("clipboard")
    readonly property bool providerReady: ShellState.ready
    readonly property string providerName: {
        const override = String(Quickshell.env("ANUSH_CLIPBOARD_PROVIDER") ?? "")
        const configured = String(ShellState.state.clipboard?.provider ?? "clipmenu")
        const requested = (override !== "" ? override : configured).toLowerCase()
        return requested === "minni" ? "minni" : "clipmenu"
    }
    readonly property bool usingMinni: providerName === "minni"
    readonly property string pasteShortcut: {
        const configured = String(
            ShellState.state.clipboard?.pasteShortcut ?? "auto").toLowerCase()
        return ["auto", "shift+insert", "ctrl+shift+v", "ctrl+v"].indexOf(
            configured) !== -1 ? configured : "auto"
    }
    readonly property var entries: usingMinni ? minni.entries : clipmenuEntries
    readonly property bool available: usingMinni ? minni.available : clipmenuAvailable
    readonly property bool busy: usingMinni
        ? minni.busy || minni.actionBusy : clipmenuBusy
    readonly property bool paused: usingMinni && minni.paused
    readonly property bool backendAvailable: !usingMinni || minni.backendAvailable
    readonly property bool supportsImages: usingMinni && minni.supportsImages
    readonly property string errorCode: usingMinni ? minni.errorCode : ""
    readonly property string errorMessage: usingMinni
        ? minni.errorMessage : clipmenuErrorMessage

    property var clipmenuEntries: []
    property bool clipmenuAvailable: false
    property bool clipmenuBusy: false
    property string clipmenuErrorMessage: ""
    property string rawHistory: ""
    property var previewPaths: ({})
    property var previewErrors: ({})

    signal popupRequested()
    signal restoreFinished(bool ok)

    function helperCommand(action) {
        return "exec '" + Theme.scriptsDir + "/clipboard/clipboard-history' " + action
    }

    function parseHistory(raw) {
        const parsed = []
        const rows = raw.split("\n")
        for (const row of rows) {
            if (row === "")
                continue

            // clipmenu v7 prefixes stable list indexes; v6 emits only the
            // preview. Selection uses display order, so both formats work.
            let preview = row.replace(/^\[\s*\d+\]\s+/, "")
            let lineCount = 1
            const countMatch = preview.match(/ \((\d+) lines\)$/)
            if (countMatch) {
                lineCount = Number(countMatch[1])
                preview = preview.slice(0, preview.length - countMatch[0].length)
            }
            parsed.push({
                id: "clipmenu-" + parsed.length,
                row: parsed.length,
                text: preview,
                preview_text: preview,
                lineCount: lineCount,
                kind: "text",
                mime_type: "text/plain",
                pinned: false
            })
        }
        clipmenuEntries = parsed
    }

    function refresh() {
        if (usingMinni) {
            minni.refresh(minni.query)
        } else if (widgetEnabled && clipmenuAvailable && !clipmenuBusy
                && !listProcess.running) {
            clipmenuBusy = true
            listProcess.running = true
        }
    }

    function search(query) {
        if (usingMinni)
            minni.refresh(query)
    }

    function restore(entry) {
        if (usingMinni && entry)
            minni.copy(String(entry.id))
    }

    function togglePinned(entry) {
        if (!usingMinni || !entry)
            return
        if (entry.pinned === true)
            minni.unpin(String(entry.id))
        else
            minni.pin(String(entry.id))
    }

    function remove(entry) {
        if (usingMinni && entry)
            minni.remove(String(entry.id))
    }

    function clear(scope) {
        if (!widgetEnabled || !available || busy)
            return
        if (usingMinni) {
            minni.clear(scope === "all" ? "all" : "unpinned")
        } else {
            clipmenuBusy = true
            clearProcess.running = true
        }
    }

    function togglePaused() {
        if (!usingMinni)
            return
        if (minni.paused)
            minni.resume()
        else
            minni.pause()
    }

    function requestPreview(itemId) {
        if (usingMinni && !previewPaths[itemId])
            minni.requestPreview(itemId)
    }

    function previewPath(itemId) {
        return String(previewPaths[itemId] ?? "")
    }

    function previewError(itemId) {
        return String(previewErrors[itemId] ?? "")
    }

    IpcHandler {
        target: "clipboard"
        // "show" collides with the qs ipc inspection subcommand in
        // Quickshell 0.3. Keep the callable name unambiguous.
        function toggle(): void { root.popupRequested() }
    }

    MinniProvider {
        id: minni
        enabled: root.providerReady && root.widgetEnabled && root.usingMinni
    }

    Connections {
        target: minni
        function onPreviewReady(itemId, path) {
            const next = Object.assign({}, root.previewPaths)
            next[itemId] = "file://" + encodeURI(path)
            root.previewPaths = next
        }
        function onPreviewFailed(itemId, errorCode) {
            const next = Object.assign({}, root.previewErrors)
            next[itemId] = errorCode
            root.previewErrors = next
        }
        function onActionFinished(action, ok) {
            if (action === "copy")
                root.restoreFinished(ok)
        }
    }

    Process {
        id: toolProbe
        command: ["sh", "-c",
            "command -v clipmenu >/dev/null 2>&1 "
            + "&& command -v clipmenud >/dev/null 2>&1 "
            + "&& command -v clipdel >/dev/null 2>&1"]
        running: root.providerReady && root.widgetEnabled && !root.usingMinni
        onExited: exitCode => {
            root.clipmenuAvailable = exitCode === 0
            if (root.clipmenuAvailable)
                root.refresh()
            else
                root.clipmenuErrorMessage = "Install clipmenu to enable clipboard history."
        }
    }

    Process {
        id: listProcess
        command: ["sh", "-c", root.helperCommand("list")]
        stderr: StdioCollector {}
        stdout: StdioCollector {
            onStreamFinished: {
                if (text !== root.rawHistory) {
                    root.rawHistory = text
                    root.parseHistory(text)
                }
                root.clipmenuErrorMessage = ""
            }
        }
        onExited: exitCode => {
            root.clipmenuBusy = false
            if (exitCode !== 0)
                root.clipmenuErrorMessage = "clipmenud is not running yet."
        }
    }

    Process {
        id: clearProcess
        command: ["sh", "-c", root.helperCommand("clear")]
        stderr: StdioCollector {}
        onExited: exitCode => {
            root.clipmenuBusy = false
            if (exitCode !== 0) {
                root.clipmenuErrorMessage = "Could not clear clipboard history."
            } else {
                root.clipmenuEntries = []
                root.clipmenuErrorMessage = ""
            }
            root.rawHistory = ""
            root.refresh()
        }
    }

    Timer {
        interval: 1000
        repeat: true
        running: root.providerReady && root.widgetEnabled && !root.usingMinni
            && root.clipmenuAvailable
        onTriggered: root.refresh()
    }
}
