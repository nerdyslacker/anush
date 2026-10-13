import QtQuick
import ".."
import Quickshell

WindowManagerBackend {
    id: root

    name: "mock"
    connected: active
    capabilities: ({
        screens: true,
        perScreenWorkspaces: true,
        workspaces: true,
        renameWorkspace: false,
        windows: true,
        windowTitles: true,
        windowAppIdentity: true,
        focusWindow: true,
        closeWindow: true,
        moveWindowToWorkspace: true,
        moveWindowToScreen: true,
        scratchpad: false,
        virtualScreens: false,
        decorationStyling: false,
        windowRadius: false,
        eventStream: true,
        layouts: false,
        gaps: false,
        reload: false,
        sessionControl: false,
        keybindings: false,
        configurationEditor: false
    })
    screens: [
        {
            id: "mock-left", name: "Mock Left",
            geometry: { x: 0, y: 0, width: 1920, height: 1080 },
            workarea: { x: 0, y: 34, width: 1920, height: 1046 },
            focused: true, physicalOutput: "mock-left", virtual: false
        },
        {
            id: "mock-right", name: "Mock Right",
            geometry: { x: 1920, y: 0, width: 1920, height: 1080 },
            workarea: { x: 1920, y: 34, width: 1920, height: 1046 },
            focused: false, physicalOutput: "mock-right", virtual: false
        }
    ]
    workspaces: [
        { id: "1", name: "1", index: 0, screenId: "mock-left", active: true, focused: true, visible: true, occupied: true, urgent: false },
        { id: "2", name: "2", index: 1, screenId: "mock-left", active: false, focused: false, visible: false, occupied: true, urgent: true },
        { id: "3", name: "3", index: 2, screenId: "mock-right", active: true, focused: false, visible: true, occupied: true, urgent: false },
        { id: "4", name: "4", index: 3, screenId: "mock-right", active: false, focused: false, visible: false, occupied: true, urgent: false }
    ]
    windows: [
        { id: "101", title: "Terminal", appId: "kitty", class: "kitty", instance: "kitty", workspaceId: "1", screenId: "mock-left", focused: true, urgent: false, floating: false, fullscreen: false, maximized: null, scratchpad: false },
        { id: "102", title: "Editor", appId: "code", class: "Code", instance: "code", workspaceId: "1", screenId: "mock-left", focused: false, urgent: false, floating: false, fullscreen: false, maximized: null, scratchpad: false },
        { id: "103", title: "Urgent chat", appId: "signal", class: "Signal", instance: "signal", workspaceId: "2", screenId: "mock-left", focused: false, urgent: true, floating: false, fullscreen: false, maximized: null, scratchpad: false },
        { id: "104", title: "Browser", appId: "firefox", class: "firefox", instance: "Navigator", workspaceId: "3", screenId: "mock-right", focused: false, urgent: false, floating: false, fullscreen: false, maximized: null, scratchpad: false },
        { id: "105", title: "Music", appId: "spotify", class: "Spotify", instance: "spotify", workspaceId: "3", screenId: "mock-right", focused: false, urgent: false, floating: false, fullscreen: false, maximized: null, scratchpad: false },
        { id: "106", title: "Files", appId: "thunar", class: "Thunar", instance: "thunar", workspaceId: "4", screenId: "mock-right", focused: false, urgent: false, floating: false, fullscreen: false, maximized: null, scratchpad: false },
        { id: "107", title: "Floating utility", appId: "pavucontrol", class: "Pavucontrol", instance: "pavucontrol", workspaceId: "4", screenId: "mock-right", focused: false, urgent: false, floating: true, fullscreen: false, maximized: null, scratchpad: false },
        { id: "108", title: "Fullscreen preview", appId: "mpv", class: "mpv", instance: "mpv", workspaceId: "2", screenId: "mock-left", focused: false, urgent: false, floating: false, fullscreen: true, maximized: null, scratchpad: false }
    ]

    function replaceAt(values, index, replacement) {
        const next = values.slice()
        next[index] = Object.assign({}, values[index], replacement)
        return next
    }

    function switchWorkspace(id, screenId) {
        const wanted = String(id)
        const screen = String(screenId ?? "")
        const target = workspaces.findIndex(ws => ws.id === wanted
            && (screen === "" || ws.screenId === screen))
        if (target < 0) return false
        workspaces = workspaces.map((ws, index) => Object.assign({}, ws, {
            active: ws.screenId === workspaces[target].screenId
                ? index === target : ws.active,
            visible: ws.screenId === workspaces[target].screenId
                ? index === target : ws.visible,
            focused: index === target
        }))
        changed()
        return true
    }

    function focusWindow(id) {
        const wanted = String(id)
        const target = windows.findIndex(win => win.id === wanted)
        if (target < 0) return false
        windows = windows.map((win, index) => Object.assign({}, win, {
            focused: index === target
        }))
        switchWorkspace(windows[target].workspaceId, windows[target].screenId)
        changed()
        return true
    }

    function closeWindow(id) {
        const wanted = String(id)
        const next = windows.filter(win => win.id !== wanted)
        if (next.length === windows.length) return false
        windows = next
        changed()
        return true
    }

    function moveWindowToWorkspace(windowId, workspaceId) {
        const windowIndex = windows.findIndex(win => win.id === String(windowId))
        const workspace = workspaces.find(ws => ws.id === String(workspaceId))
        if (windowIndex < 0 || !workspace) return false
        windows = replaceAt(windows, windowIndex, {
            workspaceId: workspace.id, screenId: workspace.screenId
        })
        changed()
        return true
    }

    function moveWindowToScreen(windowId, screenId) {
        const workspace = workspaces.find(ws => ws.screenId === String(screenId)
            && ws.visible === true)
        return workspace ? moveWindowToWorkspace(windowId, workspace.id) : false
    }

    function sendFocusedWindowToWorkspace(workspaceId) {
        const focused = windows.find(win => win.focused === true)
        return focused ? moveWindowToWorkspace(focused.id, workspaceId) : false
    }
}
