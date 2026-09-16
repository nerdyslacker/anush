pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import "../.."

Singleton {
    id: root

    readonly property string dataRoot: {
        const configured = String(Quickshell.env("ANUSH_DATA_DIR") ?? "")
        if (configured !== "")
            return configured.replace(/\/$/, "")
        const xdg = String(Quickshell.env("XDG_DATA_HOME") ?? "")
        if (xdg !== "")
            return xdg.replace(/\/$/, "") + "/anush"
        return String(Quickshell.env("HOME") ?? "") + "/.local/share/anush"
    }
    readonly property string configuredFile: String(
        Quickshell.env("ANUSH_NOTES_FILE") ?? "")
    readonly property string configuredDirectory: String(
        Quickshell.env("ANUSH_NOTEPAD_DIR") ?? "")
    readonly property string notesDirectory: {
        if (configuredDirectory !== "")
            return configuredDirectory.replace(/\/$/, "")
        if (configuredFile !== "") {
            const separator = configuredFile.lastIndexOf("/")
            return separator > 0 ? configuredFile.slice(0, separator) : "."
        }
        return dataRoot + "/notepad"
    }
    readonly property string legacyFilePath: configuredFile === ""
        ? dataRoot + "/notes.md" : ""
    readonly property string helperPath: ShellState.scriptsDir + "/notepad-storage"

    // Keep a stable first tab visible while the backing directory is listed
    // and, on first run, note-1.md is created.
    property var files: [{
            name: "note-1.md",
            title: "Note 1",
            path: notesDirectory + "/note-1.md",
            empty: true
        }]
    property int activeIndex: 0
    property bool initialPlaceholder: true
    property bool listingStarted: false
    property string primaryFilePath: ""
    property string activeFilePath: ""
    property string text: ""
    property string savedText: ""
    property string pendingText: ""
    property string pendingFilePath: ""
    property int pendingActiveIndex: -1
    property int pendingCloseIndex: -1
    property bool pendingCreate: false
    property bool ready: false
    property bool dirty: false
    property bool saving: false
    property bool externalConflict: false
    property string errorMessage: ""
    property bool openAfterSave: false
    property var removalQueue: []
    property string removalPath: ""

    property bool opened: false
    property string activeScreenName: ""
    property string side: "right"
    property bool extended: false

    readonly property string status: errorMessage !== "" ? "error"
        : externalConflict ? "conflict"
        : !ready ? "loading"
        : saving ? "saving"
        : dirty ? "unsaved"
        : "saved"
    readonly property var activeFile: activeIndex >= 0 && activeIndex < files.length
        ? files[activeIndex] : null

    function initialize() {
        loadSettings()
        if (!listingStarted) {
            listingStarted = true
            listProcess.running = true
        }
    }

    function loadSettings() {
        if (!ShellState.ready)
            return
        const saved = ShellState.state.notepad
        side = saved.side === "left" ? "left" : "right"
        extended = saved.extended === true
    }

    function setSide(value) {
        const next = value === "left" ? "left" : "right"
        if (side === next)
            return
        side = next
        ShellState.updateSection("notepad", { side: side, extended: extended })
    }

    function toggleExtended() {
        extended = !extended
        ShellState.updateSection("notepad", { side: side, extended: extended })
    }

    function screenName(screen) {
        return String(screen?.name ?? "")
    }

    function matchesScreen(screen) {
        if (!screen)
            return false
        const requested = activeScreenName
        if (requested !== "")
            return screenName(screen) === requested
        return Quickshell.screens.length > 0 && screen === Quickshell.screens[0]
    }

    function toggleForScreen(screen) {
        const requested = screenName(screen)
        if (opened && (activeScreenName === requested || requested === "")) {
            close()
            return
        }
        activeScreenName = requested
        opened = true
    }

    function toggleDefault() {
        if (opened) {
            close()
            return
        }
        const screen = Quickshell.screens.length > 0 ? Quickshell.screens[0] : null
        toggleForScreen(screen)
    }

    function close() {
        saveNow()
        opened = false
    }

    function setText(value) {
        const next = String(value ?? "")
        if (next === text)
            return
        text = next
        dirty = text !== savedText
        errorMessage = ""
        if (dirty && !externalConflict)
            saveDebounce.restart()
        else
            saveDebounce.stop()
    }

    function saveNow(forceConflictOverwrite = false) {
        saveDebounce.stop()
        if (!ready || saving || !dirty || activeFilePath === ""
                || (externalConflict && !forceConflictOverwrite))
            return
        pendingText = text
        pendingFilePath = activeFilePath
        saving = true
        errorMessage = ""
        saveProcess.running = true
    }

    function activate(index) {
        if (index < 0 || index >= files.length || index === activeIndex)
            return
        if (saving) {
            pendingCreate = false
            pendingCloseIndex = -1
            pendingActiveIndex = index
            return
        }
        if (dirty) {
            pendingCreate = false
            pendingCloseIndex = -1
            pendingActiveIndex = index
            saveNow()
            return
        }
        activateDirect(index)
    }

    function activateDirect(index) {
        activeIndex = index
        activeFilePath = String(files[index].path)
        text = ""
        savedText = ""
        dirty = false
        ready = false
        externalConflict = false
        errorMessage = ""
    }

    function markFileEmpty(path, empty) {
        const next = files.slice()
        for (let i = 0; i < next.length; ++i) {
            if (String(next[i].path) !== String(path))
                continue
            const updated = ({})
            for (const key in next[i])
                updated[key] = next[i][key]
            updated.empty = empty
            next[i] = updated
            files = next
            return
        }
    }

    function createNote() {
        if (createProcess.running)
            return
        if (saving) {
            pendingActiveIndex = -1
            pendingCloseIndex = -1
            pendingCreate = true
            return
        }
        if (dirty) {
            pendingActiveIndex = -1
            pendingCloseIndex = -1
            pendingCreate = true
            saveNow()
            return
        }
        createProcess.running = true
    }

    function closeTab(index) {
        if (files.length <= 1 || index < 0 || index >= files.length)
            return
        if (index !== activeIndex) {
            closeTabDirect(index)
            return
        }
        if (saving) {
            pendingCreate = false
            pendingActiveIndex = -1
            pendingCloseIndex = index
            return
        }
        if (dirty) {
            pendingCreate = false
            pendingActiveIndex = -1
            pendingCloseIndex = index
            saveNow()
            return
        }
        closeTabDirect(index)
    }

    function closeTabDirect(index) {
        const closingActive = index === activeIndex
        const closedFile = files[index]
        const next = files.slice()
        next.splice(index, 1)
        files = next
        if (!closingActive) {
            if (index < activeIndex)
                activeIndex--
        } else {
            activateDirect(Math.min(index, next.length - 1))
        }
        if (closedFile.empty === true
                && String(closedFile.path) !== primaryFilePath)
            queueRemoval(String(closedFile.path))
    }

    function queueRemoval(path) {
        removalQueue = removalQueue.concat([path])
        if (!removeProcess.running)
            startNextRemoval()
    }

    function startNextRemoval() {
        if (removalQueue.length === 0)
            return
        removalPath = removalQueue[0]
        removalQueue = removalQueue.slice(1)
        removeProcess.running = true
    }

    function continuePendingAction() {
        if (pendingCloseIndex >= 0) {
            const index = pendingCloseIndex
            pendingCloseIndex = -1
            closeTabDirect(index)
            return
        }
        if (pendingCreate) {
            pendingCreate = false
            createProcess.running = true
            return
        }
        if (pendingActiveIndex >= 0) {
            const index = pendingActiveIndex
            pendingActiveIndex = -1
            activateDirect(index)
        }
    }

    function reloadFromDisk() {
        if (dirty || saving) {
            externalConflict = true
            saveDebounce.stop()
            return
        }
        noteFile.reload()
    }

    function openExternally() {
        if (activeFilePath === "")
            return
        if (externalConflict) {
            Quickshell.execDetached(["xdg-open", activeFilePath])
            return
        }
        if (dirty || saving) {
            openAfterSave = true
            saveNow()
            return
        }
        Quickshell.execDetached(["xdg-open", activeFilePath])
    }

    function finishOpenRequest() {
        if (!openAfterSave)
            return
        openAfterSave = false
        Quickshell.execDetached(["xdg-open", activeFilePath])
    }

    IpcHandler {
        target: "notepad"
        function toggle(): void { root.toggleDefault() }
        function close(): void { root.close() }
        function newNote(): void { root.createNote() }
        function save(): void { root.saveNow(true) }
    }

    Connections {
        target: ShellState
        function onReadyChanged() { if (ShellState.ready) root.loadSettings() }
        function onStateChanged() { root.loadSettings() }
    }

    Timer {
        id: saveDebounce
        interval: 800
        onTriggered: root.saveNow()
    }

    Process {
        id: listProcess
        command: root.legacyFilePath !== ""
            ? [root.helperPath, "list", root.notesDirectory, root.legacyFilePath]
            : [root.helperPath, "list", root.notesDirectory]
        stdout: StdioCollector { id: listOutput }
        stderr: StdioCollector { id: listError }
        onExited: exitCode => {
            if (exitCode !== 0) {
                root.ready = true
                root.errorMessage = listError.text.trim() || "Could not list notes"
                return
            }
            let listed = []
            try {
                listed = JSON.parse(listOutput.text)
            } catch (error) {
                root.ready = true
                root.errorMessage = "Could not read note list: " + error
                return
            }
            if (listed.length === 0) {
                createProcess.running = true
                return
            }
            root.files = listed
            root.initialPlaceholder = false
            let initialIndex = 0
            if (root.configuredFile !== "") {
                for (let i = 0; i < listed.length; ++i)
                    if (listed[i].path === root.configuredFile)
                        initialIndex = i
            }
            root.primaryFilePath = String(listed[initialIndex].path)
            root.activateDirect(initialIndex)
        }
    }

    Process {
        id: createProcess
        command: [root.helperPath, "create", root.notesDirectory]
        stdout: StdioCollector { id: createOutput }
        stderr: StdioCollector { id: createError }
        onExited: exitCode => {
            if (exitCode !== 0) {
                root.errorMessage = createError.text.trim() || "Could not create note"
                return
            }
            try {
                const created = JSON.parse(createOutput.text)
                const next = root.initialPlaceholder
                    ? [created] : root.files.concat([created])
                root.files = next
                root.initialPlaceholder = false
                if (root.primaryFilePath === "")
                    root.primaryFilePath = String(created.path)
                root.activateDirect(next.length - 1)
            } catch (error) {
                root.errorMessage = "Could not read new note: " + error
            }
        }
    }

    FileView {
        id: noteFile
        path: root.activeFilePath
        watchChanges: true
        onLoaded: {
            if (root.dirty || root.saving) {
                root.externalConflict = true
                return
            }
            root.text = text()
            root.savedText = root.text
            root.markFileEmpty(root.activeFilePath, root.text.length === 0)
            root.ready = true
            root.errorMessage = ""
            root.externalConflict = false
        }
        onLoadFailed: error => {
            root.ready = true
            root.errorMessage = "Could not read note: " + FileViewError.toString(error)
        }
        onFileChanged: root.reloadFromDisk()
    }

    Process {
        id: saveProcess
        command: [root.helperPath, "save", root.pendingFilePath]
        stdinEnabled: true
        stderr: StdioCollector { id: saveError }
        onStarted: write(JSON.stringify(root.pendingText) + "\n")
        onExited: exitCode => {
            root.saving = false
            if (exitCode !== 0) {
                root.dirty = true
                root.openAfterSave = false
                root.errorMessage = saveError.text.trim() || "Could not save note"
                return
            }
            if (root.activeFilePath === root.pendingFilePath) {
                root.savedText = root.pendingText
                root.dirty = root.text !== root.savedText
                root.externalConflict = false
            }
            root.markFileEmpty(root.pendingFilePath, root.pendingText.length === 0)
            root.errorMessage = ""
            if (root.dirty) {
                saveDebounce.restart()
                return
            }
            if (root.openAfterSave)
                root.finishOpenRequest()
            root.continuePendingAction()
        }
    }

    Process {
        id: removeProcess
        command: [root.helperPath, "remove", root.removalPath]
        stderr: StdioCollector { id: removeError }
        onExited: exitCode => {
            if (exitCode !== 0)
                root.errorMessage = removeError.text.trim()
                    || "Could not remove empty note"
            Qt.callLater(() => root.startNextRemoval())
        }
    }

    Component.onDestruction: saveNow()
}
