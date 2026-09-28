package main

import "core:encoding/json"
import "core:fmt"
import "core:os"
import "core:path/filepath"
import "core:strings"
import "core:time"

config_home :: proc() -> string {
    xdg_buf: [4096]u8
    if xdg := os.get_env_buf(xdg_buf[:], "XDG_CONFIG_HOME"); xdg != "" {
        return strings.clone(xdg)
    }
    home_buf: [4096]u8
    home := os.get_env_buf(home_buf[:], "HOME")
    if home == "" { return "" }
    return fmt.aprintf("%s/.config", home)
}

configure_icon_theme_environment :: proc() {
    state_dir_buf, xdg_state_buf, home_buf: [4096]u8
    state_dir := os.get_env_buf(state_dir_buf[:], "ANUSH_STATE_DIR")
    path := ""
    if state_dir != "" {
        path = fmt.tprintf("%s/shell-state.json", state_dir)
    } else if xdg_state := os.get_env_buf(
            xdg_state_buf[:], "XDG_STATE_HOME"); xdg_state != "" {
        path = fmt.tprintf("%s/anush/shell-state.json", xdg_state)
    } else if home := os.get_env_buf(home_buf[:], "HOME"); home != "" {
        path = fmt.tprintf("%s/.local/state/anush/shell-state.json", home)
    }
    if path == "" || !os.exists(path) { return }

    data, read_err := os.read_entire_file(path, context.temp_allocator)
    if read_err != nil { return }
    state: struct {
        theme: struct {
            iconTheme: string,
        },
    }
    if json.unmarshal(data, &state, allocator = context.temp_allocator) != nil ||
            state.theme.iconTheme == "" {
        return
    }
    _ = os.set_env("QS_ICON_THEME", state.theme.iconTheme)
}

user_config_dir :: proc() -> string {
    env_buf: [4096]u8
    if configured := os.get_env_buf(env_buf[:], "ANUSH_CONFIG_DIR"); configured != "" {
        return strings.clone(configured)
    }
    base := config_home()
    if base == "" { return "" }
    defer delete(base)
    return fmt.aprintf("%s/skarwm/anush", base)
}

seed_writable_config :: proc(root, target: string) {
    if target == "" { return }
    directories := [5]string{"dunst", "fastfetch", "kitty", "picom", "rofi"}
    for directory in directories {
        destination := fmt.aprintf("%s/%s", target, directory)
        defer delete(destination)
        if os.exists(destination) { continue }
        source := fmt.aprintf("%s/config/%s", root, directory)
        defer delete(source)
        if !os.exists(source) { continue }
        if err := os.copy_directory_all(destination, source); err != nil {
            fmt.eprintln("anushctl: cannot seed writable", directory, "config:", err)
        }
    }
}

ensure_fastfetch_config :: proc(config_dir: string) {
    source := fmt.aprintf("%s/fastfetch/config.jsonc", config_dir)
    defer delete(source)
    if !os.exists(source) { return }

    base := config_home()
    if base == "" { return }
    defer delete(base)
    directory := fmt.aprintf("%s/fastfetch", base)
    defer delete(directory)
    target := fmt.aprintf("%s/config.jsonc", directory)
    defer delete(target)

    if os.exists(target) && os.are_paths_identical(target, source) { return }

    if !os.exists(directory) {
        if err := os.make_directory_all(directory); err != nil {
            fmt.eprintln("anushctl: cannot create Fastfetch config directory:", err)
            return
        }
    }

    moved_existing := false
    backup := fmt.aprintf("%s/config.jsonc.pre-anush", directory)
    defer delete(backup)
    link_target, link_err := os.read_link(target, context.temp_allocator)
    if link_err == nil && link_target == source { return }
    target_present := os.exists(target) || link_err == nil
    managed_link := link_err == nil && os.exists(backup)
    if managed_link {
        if err := os.remove(target); err != nil {
            fmt.eprintln("anushctl: cannot update Fastfetch config link:", err)
            return
        }
    } else if target_present {
        if os.exists(backup) {
            fmt.eprintln("anushctl: Fastfetch config backup already exists at", backup,
                "; leaving", target, "unchanged")
            return
        }
        if err := os.rename(target, backup); err != nil {
            fmt.eprintln("anushctl: cannot preserve existing Fastfetch config:", err)
            return
        }
        moved_existing = true
    }

    if err := os.symlink(source, target); err != nil {
        fmt.eprintln("anushctl: cannot activate anush Fastfetch config:", err)
        if managed_link {
            _ = os.symlink(link_target, target)
        } else if moved_existing {
            _ = os.rename(backup, target)
        }
        return
    }
}

configure_shell_environment :: proc(root: string) {
    configure_icon_theme_environment()

    package_config := fmt.aprintf("%s/config", root)
    defer delete(package_config)
    _ = os.set_env("ANUSH_PACKAGE_CONFIG_DIR", package_config)

    config_dir := user_config_dir()
    defer if config_dir != "" { delete(config_dir) }
    if config_dir == "" { return }
    seed_writable_config(root, config_dir)
    _ = os.set_env("ANUSH_CONFIG_DIR", config_dir)

    kitty_config := fmt.aprintf("%s/kitty", config_dir)
    defer delete(kitty_config)
    _ = os.set_env("KITTY_CONFIG_DIRECTORY", kitty_config)
    ensure_fastfetch_config(config_dir)
}

shell_root :: proc() -> string {
    env_buf: [4096]u8
    if configured := os.get_env_buf(env_buf[:], "ANUSH_ROOT"); configured != "" {
        return strings.clone(configured)
    }

    return system_root()
}

root_is_complete :: proc(root: string) -> bool {
    if root == "" { return false }
    shell_file := fmt.aprintf("%s/shell/shell.qml", root)
    defer delete(shell_file)
    config_dir := fmt.aprintf("%s/config", root)
    defer delete(config_dir)
    scripts_dir := fmt.aprintf("%s/shell/scripts", root)
    defer delete(scripts_dir)
    return os.exists(shell_file) && os.exists(config_dir) && os.exists(scripts_dir)
}

system_root :: proc() -> string {
    system_buf: [4096]u8
    if configured := os.get_env_buf(system_buf[:], "ANUSH_SYSTEM_DIR"); configured != "" {
        return strings.clone(configured)
    }

    exe_dir, exe_err := os.get_executable_directory(context.allocator)
    if exe_err == nil {
        defer delete(exe_dir)

        // Development build: <checkout>/build/anushctl.
        checkout := filepath.dir(exe_dir)
        if root_is_complete(checkout) { return strings.clone(checkout) }

        // Installed binary: <prefix>/bin/anushctl -> <prefix>/share/anush.
        prefix := filepath.dir(exe_dir)
        installed, _ := filepath.join([]string{prefix, "share", "anush"})
        if root_is_complete(installed) { return installed }
        delete(installed)
    }

    standard_roots := [2]string{"/usr/share/anush", "/usr/local/share/anush"}
    for candidate in standard_roots {
        if root_is_complete(candidate) { return strings.clone(candidate) }
    }
    return ""
}

reload_shell :: proc() -> int {
    root, ready := prepare_shell_root()
    if !ready { return EXIT_RUNTIME }
    delete(root)
    return ipc_call("anush", "reload", nil)
}

prepare_shell_root :: proc() -> (string, bool) {
    root := shell_root()
    if root == "" || !root_is_complete(root) {
        fmt.eprintln("anushctl: could not find anush data; set ANUSH_SYSTEM_DIR")
        if root != "" { delete(root) }
        return "", false
    }
    return root, true
}

run_process :: proc(command: []string) -> (exit_code: int, stdout, stderr: []byte, started: bool) {
    state, out, err_out, err := os.process_exec(
        os.Process_Desc{command = command}, context.allocator)
    if err != nil {
        fmt.eprintln("anushctl: could not run", command[0], ":", err)
        return EXIT_RUNTIME, out, err_out, false
    }
    return state.exit_code, out, err_out, true
}

run_attached :: proc(command: []string, action: string) -> int {
    process, err := os.process_start(os.Process_Desc{
        command = command,
        stdin = os.stdin,
        stdout = os.stdout,
        stderr = os.stderr,
    })
    if err != nil {
        fmt.eprintln("anushctl: could not", action, ":", err)
        return EXIT_RUNTIME
    }
    state, wait_err := os.process_wait(process)
    if wait_err != nil {
        fmt.eprintln("anushctl:", action, "failed:", wait_err)
        return EXIT_RUNTIME
    }
    return state.exit_code
}

run_clipboard_daemon :: proc() -> int {
    root, ready := prepare_shell_root()
    if !ready { return EXIT_RUNTIME }
    defer delete(root)
    helper := fmt.aprintf("%s/shell/scripts/clipboard/clipboard-history", root)
    defer delete(helper)
    if !os.exists(helper) {
        fmt.eprintln("anushctl: clipboard helper is missing from", root)
        return EXIT_RUNTIME
    }
    return run_attached([]string{helper, "daemon"}, "start clipboard history")
}

restore_wallpaper :: proc() -> int {
    home_buf: [4096]u8
    home := os.get_env_buf(home_buf[:], "HOME")
    if home != "" {
        fehbg := fmt.aprintf("%s/.fehbg", home)
        defer delete(fehbg)
        if os.exists(fehbg) {
            return run_attached([]string{"sh", fehbg}, "restore the wallpaper")
        }
    }

    root, ready := prepare_shell_root()
    if !ready { return EXIT_RUNTIME }
    defer delete(root)
    wallpaper := fmt.aprintf(
        "%s/config/wallpaper/minimal.png", root)
    defer delete(wallpaper)
    if !os.exists(wallpaper) {
        fmt.eprintln("anushctl: default wallpaper is missing from", root)
        return EXIT_RUNTIME
    }
    return run_attached(
        []string{"feh", "--bg-fill", wallpaper}, "restore the wallpaper")
}

ipc_call :: proc(target, function: string, call_args: []string) -> int {
    root := shell_root()
    if root == "" {
        fmt.eprintln("anushctl: cannot resolve the anush shell directory")
        return EXIT_RUNTIME
    }
    defer delete(root)
    shell_dir, _ := filepath.join([]string{root, "shell"})
    defer delete(shell_dir)

    command := make([dynamic]string, 0, 9 + len(call_args))
    defer delete(command)
    append(&command, "qs", "-p", shell_dir, "ipc", "-n", "call", target, function)
    for arg in call_args { append(&command, arg) }

    code, out, err_out, started := run_process(command[:])
    defer delete(out)
    defer delete(err_out)
    if !started { return EXIT_RUNTIME }
    if code != 0 {
        if len(err_out) > 0 { fmt.eprint(string(err_out)) }
        fmt.eprintln("anushctl: anush shell is not running or did not accept the command")
        return EXIT_NOT_RUNNING
    }
    if len(out) > 0 { fmt.print(string(out)) }
    return EXIT_OK
}

restart_shell :: proc() -> int {
    root, ready := prepare_shell_root()
    if !ready { return EXIT_RUNTIME }
    defer delete(root)
    shell_dir, _ := filepath.join([]string{root, "shell"})
    defer delete(shell_dir)

    kill_code, kill_out, kill_err, started := run_process(
        []string{"qs", "-p", shell_dir, "kill", "-n"})
    delete(kill_out)
    defer delete(kill_err)
    if !started { return EXIT_RUNTIME }
    if kill_code != 0 {
        if len(kill_err) > 0 { fmt.eprint(string(kill_err)) }
        fmt.eprintln("anushctl: anush shell is not running")
        return EXIT_NOT_RUNNING
    }

    // The kill command acknowledges the request before the old instance has
    // necessarily removed its IPC registration. Launching immediately with
    // --no-duplicate can therefore succeed without creating a replacement.
    if !wait_for_shell(shell_dir, false, 30) {
        fmt.eprintln("anushctl: timed out waiting for anush to stop")
        return EXIT_RUNTIME
    }

    configure_shell_environment(root)
    code, out, err_out, launched := run_process(
        []string{"qs", "-d", "--no-duplicate", "-p", shell_dir})
    defer delete(out)
    defer delete(err_out)
    if !launched || code != 0 {
        if len(err_out) > 0 { fmt.eprint(string(err_out)) }
        fmt.eprintln("anushctl: failed to relaunch anush")
        return EXIT_RUNTIME
    }
    if !wait_for_shell(shell_dir, true, 50) {
        fmt.eprintln("anushctl: anush was launched but did not become ready")
        return EXIT_RUNTIME
    }
    fmt.println("anush restarted.")
    return EXIT_OK
}

shell_is_ready :: proc(shell_dir: string) -> bool {
    code, out, err_out, started := run_process([]string{
        "qs", "-p", shell_dir, "ipc", "-n", "call", "anush", "ping",
    })
    defer delete(out)
    defer delete(err_out)
    return started && code == 0
}

wait_for_shell :: proc(shell_dir: string, expected: bool, attempts: int) -> bool {
    for _ in 0..<attempts {
        if shell_is_ready(shell_dir) == expected { return true }
        time.sleep(100 * time.Millisecond)
    }
    return false
}

launch_shell :: proc() -> int {
    root, ready := prepare_shell_root()
    if !ready { return EXIT_RUNTIME }
    defer delete(root)
    shell_dir, _ := filepath.join([]string{root, "shell"})
    defer delete(shell_dir)

    configure_shell_environment(root)
    process, err := os.process_start(os.Process_Desc{
        command = []string{"qs", "--no-duplicate", "-p", shell_dir},
        stdin = os.stdin,
        stdout = os.stdout,
        stderr = os.stderr,
    })
    if err != nil {
        fmt.eprintln("anushctl: failed to launch anush:", err)
        return EXIT_RUNTIME
    }
    state, wait_err := os.process_wait(process)
    if wait_err != nil {
        fmt.eprintln("anushctl: failed while waiting for anush:", wait_err)
        return EXIT_RUNTIME
    }
    return state.exit_code
}
