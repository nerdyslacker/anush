package main

import "core:fmt"
import "core:os"
import "core:path/filepath"

VERSION :: "0.1.0"

EXIT_OK          :: 0
EXIT_RUNTIME     :: 1
EXIT_USAGE       :: 2
EXIT_NOT_RUNNING :: 3

usage :: proc() {
    fmt.println(`anushctl - control the Anush desktop shell

Usage: anushctl COMMAND [ARGUMENTS]

Runtime commands:
  start                          Launch Anush
  status                         Show shell and protocol status
  reload                         Hard-reload the running shell configuration
  restart                        Stop and relaunch the shell
  lock                           Lock the session with Betterlockscreen
  launcher toggle               Toggle the application launcher
  clipboard toggle|daemon       Toggle history or run its capture daemon
  sidebar toggle                Toggle the Notepad sidebar
  notes toggle|new|save|close    Control Notepad
  popup network|bluetooth        Open a connectivity popup
  wallpaper set FILE             Set the desktop wallpaper
  wallpaper random|restore       Pick a random or restore the last wallpaper
  theme mode light|dark          Change the shell colour mode

Compositor integration:
  install skarwm                 Add Anush startup and key bindings
  remove skarwm                  Remove the managed integration block

Other:
  help, -h, --help               Show this help
  version, -v, --version         Show the version

Exit codes: 0 success, 1 runtime failure, 2 invalid usage, 3 shell not running.`)
}

usage_error :: proc(message: string) -> int {
    fmt.eprintln("anushctl:", message)
    fmt.eprintln("Try 'anushctl --help' for usage.")
    return EXIT_USAGE
}

run_cli :: proc(args: []string) -> int {
    if len(args) == 0 {
        usage()
        return EXIT_USAGE
    }

    switch args[0] {
    case "help", "-h", "--help":
        usage()
        return EXIT_OK
    case "version", "-v", "--version":
        fmt.printf("anushctl %s\n", VERSION)
        return EXIT_OK
    case "status":
        if len(args) != 1 { return usage_error("status takes no arguments") }
        return ipc_call("anush", "status", nil)
    case "start":
        if len(args) != 1 { return usage_error("start takes no arguments") }
        return launch_shell()
    case "reload":
        if len(args) != 1 { return usage_error("reload takes no arguments") }
        return ipc_call("anush", "reload", nil)
    case "restart":
        if len(args) != 1 { return usage_error("restart takes no arguments") }
        return restart_shell()
    case "lock":
        if len(args) != 1 { return usage_error("lock takes no arguments") }
        return run_attached([]string{"betterlockscreen", "-l"}, "lock the session")
    case "launcher":
        if len(args) != 2 || args[1] != "toggle" {
            return usage_error("expected: launcher toggle")
        }
        return ipc_call("launcher", "toggleCentered", nil)
    case "clipboard":
        if len(args) != 2 {
            return usage_error("expected: clipboard toggle|daemon")
        }
        switch args[1] {
        case "toggle": return ipc_call("clipboard", "toggle", nil)
        case "daemon": return run_clipboard_daemon()
        case: return usage_error("expected: clipboard toggle|daemon")
        }
    case "sidebar":
        if len(args) != 2 || args[1] != "toggle" {
            return usage_error("expected: sidebar toggle")
        }
        return ipc_call("notepad", "toggle", nil)
    case "notes", "notepad":
        if len(args) != 2 {
            return usage_error("expected: notes toggle|new|save|close")
        }
        switch args[1] {
        case "toggle": return ipc_call("notepad", "toggle", nil)
        case "new":    return ipc_call("notepad", "newNote", nil)
        case "save":   return ipc_call("notepad", "save", nil)
        case "close":  return ipc_call("notepad", "close", nil)
        case: return usage_error("expected: notes toggle|new|save|close")
        }
    case "popup":
        if len(args) != 2 {
            return usage_error("expected: popup network|bluetooth")
        }
        switch args[1] {
        case "network":   return ipc_call("network", "open", nil)
        case "bluetooth": return ipc_call("bluetooth", "open", nil)
        case: return usage_error("expected: popup network|bluetooth")
        }
    case "wallpaper":
        if len(args) == 2 && args[1] == "random" {
            return ipc_call("wallpapers", "random", nil)
        }
        if len(args) == 2 && args[1] == "restore" {
            return restore_wallpaper()
        }
        if len(args) != 3 || args[1] != "set" {
            return usage_error("expected: wallpaper set FILE | wallpaper random|restore")
        }
        path, err := filepath.abs(args[2])
        if err != nil || !os.exists(path) {
            return usage_error("wallpaper file does not exist")
        }
        defer delete(path)
        return ipc_call("wallpapers", "set", []string{path})
    case "theme":
        if len(args) != 3 || args[1] != "mode" ||
                (args[2] != "light" && args[2] != "dark") {
            return usage_error("expected: theme mode light|dark")
        }
        return ipc_call("anush", "themeMode", []string{args[2]})
    case "install", "remove":
        if len(args) != 2 || args[1] != "skarwm" {
            return usage_error("expected: install|remove skarwm")
        }
        if args[0] == "install" { return install_skarwm() }
        return remove_skarwm()
    case:
        fmt.eprintf("anushctl: unknown command '%s'\n", args[0])
        fmt.eprintln("Try 'anushctl --help' for usage.")
        return EXIT_USAGE
    }
}
