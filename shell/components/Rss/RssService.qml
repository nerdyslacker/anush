pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import "../.."

// One bounded feed cache and refresh owner for every bar instance. Nothing is
// fetched and no timer runs while the RSS widget is disabled.
Singleton {
    id: root

    readonly property bool widgetEnabled: BarVisibility.enabled("rss")
    readonly property string helperPath: ShellState.scriptsDir + "/rss/rss-reader"
    readonly property string statePath: ShellState.stateDir + "/rss-items.json"

    property bool initialized: false
    property bool popupVisible: false
    property bool loading: false
    property bool refreshQueued: false
    property var feeds: []
    property var articles: []
    property var feedErrors: []
    property string error: ""
    property string lastUpdated: ""
    property int unreadCount: 0
    property int refreshMinutes: 15
    property int maxItems: 100
    property string _output: ""
    property string _operation: ""
    property var pendingReadIds: []
    property bool pendingMarkAll: false

    readonly property var unreadArticles: articles.filter(article => article.read !== true)
    readonly property string tooltip: feeds.length === 0 ? "RSS reader · no feeds configured"
        : unreadCount === 0 ? feeds.length + " feeds · all caught up"
        : unreadCount + (unreadCount === 1 ? " unread article" : " unread articles")

    function normalizedFeeds(value) {
        if (!Array.isArray(value)) return []
        const result = []
        const seen = ({})
        for (const raw of value) {
            if (!raw) continue
            const url = String(raw.url ?? "").trim()
            if (!/^https?:\/\/[^\s]+$/i.test(url)) continue
            const key = url.toLowerCase().replace(/\/$/, "")
            if (seen[key]) continue
            seen[key] = true
            result.push({
                name: String(raw.name ?? "").trim(),
                url: url
            })
            if (result.length >= 100) break
        }
        return result
    }

    function loadSettings() {
        const saved = ShellState.state.rss ?? ({})
        const nextFeeds = normalizedFeeds(saved.feeds)
        const nextMinutes = Math.max(1, Math.min(1440,
            Math.round(Number(saved.refreshMinutes) || 15)))
        const nextMax = Math.max(10, Math.min(500,
            Math.round(Number(saved.maxItems) || 100)))
        const feedsChanged = JSON.stringify(feeds) !== JSON.stringify(nextFeeds)
        feeds = nextFeeds
        refreshMinutes = nextMinutes
        maxItems = nextMax
        if (widgetEnabled && !initialized)
            initialize()
        else if (widgetEnabled && feedsChanged)
            refresh()
    }

    function initialize() {
        if (!widgetEnabled || initialized || readerProcess.running)
            return
        initialized = true
        runReader("snapshot", [statePath, String(maxItems)])
    }

    function requestPayload() {
        return JSON.stringify({ feeds: feeds, maxItems: maxItems }) + "\n"
    }

    function runReader(operation, arguments) {
        if (!widgetEnabled || readerProcess.running)
            return false
        _operation = operation
        _output = ""
        error = ""
        readerProcess.command = [helperPath, operation].concat(arguments ?? [])
        readerProcess.running = true
        return true
    }

    function refresh() {
        if (!widgetEnabled)
            return
        if (!initialized) {
            initialize()
            refreshQueued = true
            return
        }
        if (readerProcess.running) {
            refreshQueued = true
            return
        }
        loading = runReader("refresh", [statePath])
    }

    function acceptResult(contents, exitCode) {
        let result = null
        try {
            result = JSON.parse(String(contents ?? ""))
        } catch (parseError) {
            error = "RSS reader returned invalid data."
            return
        }
        if (exitCode !== 0 || result.ok !== true) {
            error = String(result.error ?? "Could not update RSS feeds.")
            return
        }
        let nextArticles = Array.isArray(result.articles) ? result.articles : []
        let nextUnreadCount = Math.max(0, Number(result.unreadCount) || 0)
        if (_operation === "snapshot" && feeds.length === 0) {
            nextArticles = []
            nextUnreadCount = 0
        }
        if (pendingMarkAll) {
            nextArticles = nextArticles.map(article =>
                Object.assign({}, article, { read: true }))
            nextUnreadCount = 0
        } else if (pendingReadIds.length > 0) {
            const pending = pendingReadIds
            for (const article of nextArticles) {
                if (article.read !== true
                        && pending.indexOf(String(article.id)) >= 0)
                    nextUnreadCount = Math.max(0, nextUnreadCount - 1)
            }
            nextArticles = nextArticles.map(article => pending.indexOf(
                String(article.id)) >= 0
                    ? Object.assign({}, article, { read: true }) : article)
        }
        articles = nextArticles
        unreadCount = nextUnreadCount
        feedErrors = Array.isArray(result.errors) ? result.errors : []
        lastUpdated = String(result.lastUpdated ?? lastUpdated)
        if (_operation === "refresh" && Number(result.newCount) > 0)
            Wm.showNotice(Number(result.newCount)
                + (Number(result.newCount) === 1
                    ? " new RSS article" : " new RSS articles"), false)
    }

    function markRead(article) {
        if (!article || article.read === true)
            return
        const next = articles.slice()
        for (let index = 0; index < next.length; ++index) {
            if (String(next[index].id) === String(article.id)) {
                next[index] = Object.assign({}, next[index], { read: true })
                break
            }
        }
        articles = next
        unreadCount = Math.max(0, unreadCount - 1)
        if (pendingReadIds.indexOf(String(article.id)) < 0)
            pendingReadIds = pendingReadIds.concat([String(article.id)])
        flushReadState()
    }

    function markAllRead() {
        if (unreadCount === 0)
            return
        articles = articles.map(article => Object.assign({}, article, { read: true }))
        unreadCount = 0
        pendingMarkAll = true
        pendingReadIds = []
        flushReadState()
    }

    function flushReadState() {
        if (!widgetEnabled || readerProcess.running)
            return
        if (pendingMarkAll) {
            pendingMarkAll = false
            runReader("mark-all-read", [statePath, String(maxItems)])
        } else if (pendingReadIds.length > 0) {
            const identifier = pendingReadIds[0]
            pendingReadIds = pendingReadIds.slice(1)
            runReader("mark-read", [statePath, identifier, String(maxItems)])
        }
    }

    function openArticle(article) {
        if (!article)
            return
        markRead(article)
        const url = String(article.url ?? "")
        if (/^https?:\/\//i.test(url))
            Quickshell.execDetached(["xdg-open", url])
    }

    function saveSettings(nextFeeds, nextRefreshMinutes, nextMaxItems) {
        const cleanFeeds = normalizedFeeds(nextFeeds)
        const minutes = Math.max(1, Math.min(1440,
            Math.round(Number(nextRefreshMinutes) || 15)))
        const maximum = Math.max(10, Math.min(500,
            Math.round(Number(nextMaxItems) || 100)))
        ShellState.updateSection("rss", {
            feeds: cleanFeeds,
            refreshMinutes: minutes,
            maxItems: maximum
        })
        feeds = cleanFeeds
        refreshMinutes = minutes
        maxItems = maximum
        refresh()
    }

    Connections {
        target: ShellState
        function onStateChanged() { root.loadSettings() }
        function onReadyChanged() { if (ShellState.ready) root.loadSettings() }
    }

    Connections {
        target: BarVisibility
        function onWidgetsChanged() {
            if (root.widgetEnabled) {
                root.initialize()
                root.flushReadState()
                if (root.feeds.length > 0)
                    root.refresh()
            } else {
                if (root._operation === "snapshot" || root._operation === "refresh")
                    readerProcess.running = false
                root.loading = false
                root.refreshQueued = false
            }
        }
    }

    Component.onCompleted: if (ShellState.ready) loadSettings()

    Process {
        id: readerProcess
        stdout: StdioCollector { onStreamFinished: root._output = text }
        onStarted: {
            if (root._operation === "refresh")
                write(root.requestPayload())
        }
        onExited: exitCode => {
            const operation = root._operation
            root.loading = false
            const cancelledForLifecycle = !root.widgetEnabled
                && (operation === "snapshot" || operation === "refresh")
            if (!cancelledForLifecycle)
                root.acceptResult(root._output, exitCode)
            if (operation === "snapshot" && root.widgetEnabled
                    && root.feeds.length > 0)
                root.refreshQueued = true
            if ((root.pendingMarkAll || root.pendingReadIds.length > 0)
                    && root.widgetEnabled) {
                Qt.callLater(() => root.flushReadState())
            } else if (root.refreshQueued && root.widgetEnabled) {
                root.refreshQueued = false
                Qt.callLater(() => root.refresh())
            }
        }
    }

    Timer {
        interval: root.refreshMinutes * 60 * 1000
        repeat: true
        running: root.widgetEnabled && root.initialized && root.feeds.length > 0
        onTriggered: root.refresh()
    }
}
