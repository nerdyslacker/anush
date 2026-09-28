pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    readonly property string shellDir: {
        let value = String(Quickshell.shellDir ?? "");
        if (value.startsWith("file://"))
            value = value.slice(7);
        return value.replace(/\/$/, "");
    }
    readonly property string stateDir: {
        const configured = String(Quickshell.env("ANUSH_STATE_DIR") ?? "");
        if (configured !== "")
            return configured;
        const xdg = String(Quickshell.env("XDG_STATE_HOME") ?? "");
        if (xdg !== "")
            return xdg + "/anush";
        return String(Quickshell.env("HOME") ?? "") + "/.local/state/anush";
    }
    readonly property string scriptsDir: shellDir + "/scripts"
    readonly property string installedConfigPath: {
        const configured = String(Quickshell.env("ANUSH_DEFAULT_CONFIG") ?? "");
        return configured !== ""
            ? configured : shellDir + "/../config/defaults.json";
    }
    readonly property string userConfigPath: {
        const configured = String(Quickshell.env("ANUSH_USER_CONFIG") ?? "");
        if (configured !== "")
            return configured;
        const configDir = String(Quickshell.env("ANUSH_CONFIG_DIR") ?? "");
        if (configDir !== "")
            return configDir.replace(/\/$/, "") + "/config.json";
        const xdg = String(Quickshell.env("XDG_CONFIG_HOME") ?? "");
        if (xdg !== "")
            return xdg + "/skarwm/anush/config.json";
        return String(Quickshell.env("HOME") ?? "")
            + "/.config/skarwm/anush/config.json";
    }
    readonly property string legacyStateDir: {
        const configured = String(Quickshell.env("SKARWM_STATE_DIR") ?? "");
        return configured !== "" ? configured : String(Quickshell.env("HOME") ?? "") + "/.config/skarwm";
    }
    readonly property string filePath: stateDir + "/shell-state.json"
    property bool ready: false
    property var state: defaults()

    function defaults() {
        return {
            bar: {
                height: 34,
                scale: 1.0,
                backgroundOpacity: 1.0,
                widgets: {},
                clusters: {},
                showOnAllMonitors: true,
                position: "top",
                fitContent: false,
                floating: false,
                separateSections: false
            },
            windowList: {
                showWindowsFromAllMonitors: false
            },
            weather: {
                location: "",
                units: "c"
            },
            launcher: {
                icon: "",
                favorites: []
            },
            wallpaper: {
                directory: ""
            },
            keyboard: {
                layout: {}
            },
            tray: {
                hidden: []
            },
            tags: {
                count: 9,
                showNumbers: true,
                dynamicWorkspaces: false,
                limitVisibleTags: false,
                visibleTagLimit: 5
            },
            pomodoro: {
                endMs: 0,
                minutes: 25
            },
            notepad: {
                side: "right",
                extended: false
            },
            colorPicker: {
                current: "",
                history: []
            },
            theme: {
                accent: "orange",
                customAccent: "#6574A8",
                defaultAccent: "yellow",
                usePresetAccent: true,
                preset: "srcery-dark",
                iconTheme: "",
                cursorTheme: "",
                wallpaperEnabled: true,
                palette: null,
                cornerRadius: 0,
                mode: "dark"
            },
            windowManager: {
                gap: 8,
                decorations: false
            },
            desktop: {
                nightLight: false,
                showBatteryPercentage: true
            }
        };
    }

    function reloadEffective() {
        if (migration.running)
            return;
        configLoader.running = false;
        configLoader.command = [root.scriptsDir + "/config/load-config",
            root.installedConfigPath, root.userConfigPath, root.filePath];
        configLoader.running = true;
    }

    function updateSection(section, values) {
        if (!state[section] || !values || typeof values !== "object")
            return;
        const next = JSON.parse(JSON.stringify(state));
        for (const key in values)
            next[section][key] = values[key];
        const serialized = JSON.stringify(next);
        if (serialized === JSON.stringify(state))
            return;
        state = next;
        stateFile.setText(JSON.stringify(next, null, 2) + "\n");
    }

    Process {
        id: migration
        running: true
        command: [root.scriptsDir + "/state/migrate-state", root.filePath,
            root.installedConfigPath, root.legacyStateDir]
        onExited: exitCode => {
            if (exitCode !== 0)
                console.warn("shell state migration exited with", exitCode);
            root.reloadEffective();
        }
    }

    Process {
        id: configLoader
        running: false
        stdout: StdioCollector { id: configOutput }
        stderr: StdioCollector { id: configErrors }
        onExited: exitCode => {
            const diagnostics = configErrors.text.trim();
            if (diagnostics !== "")
                console.warn(diagnostics);
            if (exitCode !== 0) {
                root.state = root.defaults();
                root.ready = true;
                return;
            }
            try {
                root.state = JSON.parse(configOutput.text);
            } catch (error) {
                console.warn("effective shell config:", error);
                root.state = root.defaults();
            }
            root.ready = true;
        }
    }

    FileView {
        id: stateFile
        path: root.filePath
        watchChanges: true
        atomicWrites: true
        onFileChanged: reload()
        onLoaded: if (!migration.running) root.reloadEffective()
        onLoadFailed: if (!migration.running) root.reloadEffective()
    }

    // A user override is optional. Watching it here makes edits take effect
    // without turning it into a generated or package-managed file.
    FileView {
        path: root.userConfigPath
        watchChanges: true
        onFileChanged: reload()
        onLoaded: if (!migration.running) root.reloadEffective()
    }
}
