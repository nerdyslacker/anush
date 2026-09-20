pragma Singleton

import QtQuick
import "../.."
import Quickshell

// Normalizes skarwm's event-driven window snapshot and resolves desktop
// entries once per WM_CLASS identity. Delegates remain presentation-only.
Singleton {
    id: root

    property var entries: []
    property var iconCache: ({})
    property bool showWindowsFromAllMonitors: false

    function identity(win) {
        return (String(win.class ?? "") + "|" + String(win.instance ?? "")).toLowerCase();
    }

    function desktopEntry(win) {
        const candidates = [String(win.class ?? ""), String(win.instance ?? "")];
        for (const candidate of candidates) {
            if (candidate === "")
                continue;
            const entry = DesktopEntries.heuristicLookup(candidate);
            if (entry)
                return entry;
        }
        return null;
    }

    function iconInfo(win) {
        const key = identity(win);
        const cached = iconCache[key];
        if (cached !== undefined)
            return cached;

        const desktop = desktopEntry(win);
        const info = {
            desktopFileId: desktop ? String(desktop.id ?? "") : "",
            appName: desktop ? String(desktop.name ?? "") : "",
            iconSource: desktop && String(desktop.icon ?? "") !== ""
                ? Quickshell.iconPath(String(desktop.icon), true) : ""
        };
        const next = ({});
        for (const cachedKey in iconCache)
            next[cachedKey] = iconCache[cachedKey];
        next[key] = info;
        iconCache = next;
        return info;
    }

    function rebuild() {
        const normalized = [];
        for (const win of Wm.windows) {
            if (!win || win.dock === true || win.scratchpad === true || win.workspace === null || win.workspace === undefined || win.output === null || win.output === undefined)
                continue;
            const icon = iconInfo(win);
            const appId = String(win.class || win.instance || "");
            const groupKey = icon.desktopFileId !== "" ? "desktop:" + icon.desktopFileId.toLowerCase() : appId !== "" ? "wmclass:" + appId.toLowerCase() : "window:" + String(win.id);
            normalized.push({
                id: win.id,
                title: String(win.title || win.class || win.instance || "Untitled window"),
                appId: appId,
                groupKey: groupKey,
                desktopFileId: icon.desktopFileId,
                appName: icon.appName,
                iconSource: icon.iconSource,
                workspace: Number(win.workspace),
                output: String(win.output),
                active: win.focused === true,
                urgent: win.urgent === true,
                minimized: win.minimized === true,
                fullscreen: win.fullscreen === true
            });
        }
        entries = normalized;
    }

    function windowsFor(outputName, workspace) {
        const wantedOutput = String(outputName ?? "");
        const wantedWorkspace = Number(workspace);
        if (wantedOutput === "" || !Number.isFinite(wantedWorkspace))
            return [];
        return entries.filter(entry => entry.workspace === wantedWorkspace && (showWindowsFromAllMonitors || entry.output === wantedOutput));
    }

    function groupsFor(outputName, workspace) {
        const windows = windowsFor(outputName, workspace);
        const groups = [];
        const indexes = ({});
        for (const win of windows) {
            let index = indexes[win.groupKey];
            if (index === undefined) {
                index = groups.length;
                indexes[win.groupKey] = index;
                groups.push({
                    key: win.groupKey,
                    appName: win.appName || win.appId || win.title,
                    iconSource: win.iconSource,
                    windows: [],
                    active: false,
                    urgent: false,
                    minimized: true
                });
            }
            const group = groups[index];
            group.windows.push(win);
            group.active = group.active || win.active;
            group.urgent = group.urgent || win.urgent;
            group.minimized = group.minimized && win.minimized;
        }
        return groups;
    }

    function setShowWindowsFromAllMonitors(enabled) {
        showWindowsFromAllMonitors = enabled === true;
        ShellState.updateSection("windowList", {
            showWindowsFromAllMonitors: showWindowsFromAllMonitors
        });
    }

    function loadState() {
        showWindowsFromAllMonitors = ShellState.state.windowList.showWindowsFromAllMonitors === true;
    }

    Connections {
        target: Wm
        function onWindowsChanged() {
            root.rebuild();
        }
    }

    Connections {
        target: DesktopEntries
        function onApplicationsChanged() {
            root.iconCache = ({});
            root.rebuild();
        }
    }

    Connections {
        target: ShellState
        function onStateChanged() {
            root.loadState();
        }
        function onReadyChanged() {
            if (ShellState.ready)
                root.loadState();
        }
    }

    Component.onCompleted: {
        if (ShellState.ready)
            loadState();
        rebuild();
    }
}
