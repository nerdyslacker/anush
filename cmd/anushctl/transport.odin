package main

import "core:encoding/json"
import "core:fmt"
import "core:os"
import "core:path/filepath"
import "core:strings"
import "core:time"

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

configure_shell_environment :: proc(root: string) {
    configure_icon_theme_environment()

    config_buf: [4096]u8
    if configured := os.get_env_buf(
            config_buf[:], "ANUSH_CONFIG_DIR"); configured != "" {
        kitty_config := fmt.aprintf("%s/kitty", configured)
        defer delete(kitty_config)
        _ = os.set_env("KITTY_CONFIG_DIRECTORY", kitty_config)
        return
    }

    kitty_config := fmt.aprintf("%s/config/kitty", root)
    defer delete(kitty_config)
    _ = os.set_env("KITTY_CONFIG_DIRECTORY", kitty_config)
}

shell_root :: proc() -> string {
    env_buf: [4096]u8
    if configured := os.get_env_buf(env_buf[:], "ANUSH_ROOT"); configured != "" {
        return strings.clone(configured)
    }

    base := config_home()
    if base == "" { return "" }
    defer delete(base)
    return fmt.aprintf("%s/anush", base)
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

ensure_script_permissions :: proc(root: string) -> bool {
    scripts_dir := fmt.aprintf("%s/shell/scripts", root)
    defer delete(scripts_dir)
    if !os.exists(scripts_dir) { return true }

    script_mode := os.Permissions{
        .Read_User, .Write_User, .Execute_User,
        .Read_Group, .Execute_Group,
        .Read_Other, .Execute_Other,
    }
    walker := os.walker_create(scripts_dir)
    defer os.walker_destroy(&walker)
    for info in os.walker_walk(&walker) {
        if info.type != .Regular { continue }
        if err := os.chmod(info.fullpath, script_mode); err != nil {
            fmt.eprintln("anushctl: cannot make helper executable:",
                info.fullpath, ":", err)
            return false
        }
    }
    if failed_path, err := os.walker_error(&walker); err != nil {
        fmt.eprintln("anushctl: cannot inspect shell helpers:",
            failed_path, ":", err)
        return false
    }
    return true
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

refresh_managed_files :: proc(target, source: string) -> bool {
    if source == "" || !root_is_complete(source) ||
            os.are_paths_identical(target, source) {
        return true
    }

    source_shell := fmt.aprintf("%s/shell", source)
    defer delete(source_shell)
    target_shell := fmt.aprintf("%s/shell", target)
    defer delete(target_shell)
    if err := os.copy_directory_all(target_shell, source_shell); err != nil {
        fmt.eprintln("anushctl: cannot refresh managed shell files:", err)
        return false
    }
    if !ensure_script_permissions(target) { return false }

    source_assets := fmt.aprintf("%s/assets", source)
    defer delete(source_assets)
    if os.exists(source_assets) {
        target_assets := fmt.aprintf("%s/assets", target)
        defer delete(target_assets)
        if err := os.copy_directory_all(target_assets, source_assets); err != nil {
            fmt.eprintln("anushctl: cannot refresh managed assets:", err)
            return false
        }
    }

    // Presets are managed data even though they live under config/ so users
    // can inspect and extend them. Refresh bundled files without touching
    // unrelated desktop configuration or user-added preset JSON files.
    source_presets := fmt.aprintf("%s/config/themes/presets", source)
    defer delete(source_presets)
    if os.exists(source_presets) {
        target_presets := fmt.aprintf("%s/config/themes/presets", target)
        defer delete(target_presets)
        if err := os.copy_directory_all(target_presets, source_presets); err != nil {
            fmt.eprintln("anushctl: cannot refresh managed theme presets:", err)
            return false
        }
    }

    // Matugen integration is also managed application data. Keep it current
    // without replacing the rest of the user's config directory.
    source_matugen := fmt.aprintf("%s/config/matugen", source)
    defer delete(source_matugen)
    if os.exists(source_matugen) {
        target_matugen := fmt.aprintf("%s/config/matugen", target)
        defer delete(target_matugen)
        if err := os.copy_directory_all(target_matugen, source_matugen); err != nil {
            fmt.eprintln("anushctl: cannot refresh managed Matugen config:", err)
            return false
        }
    }
    return true
}

prepare_shell_root :: proc() -> (string, bool) {
    target := shell_root()
    if target == "" {
        fmt.eprintln("anushctl: HOME and XDG_CONFIG_HOME are unset; set ANUSH_ROOT")
        return "", false
    }
    if root_is_complete(target) {
        // ANUSH_ROOT is an explicit source/checkout selection and must not be
        // overwritten. Default user installations receive managed code
        // updates while their config/ directory remains untouched.
        env_buf: [4096]u8
        if os.get_env_buf(env_buf[:], "ANUSH_ROOT") == "" {
            source := system_root()
            defer if source != "" { delete(source) }
            if !refresh_managed_files(target, source) {
                delete(target)
                return "", false
            }
        }
        return target, true
    }
    if os.exists(target) {
        fmt.eprintln("anushctl:", target, "exists but is not a complete Anush installation")
        delete(target)
        return "", false
    }

    source := system_root()
    if source == "" || !root_is_complete(source) {
        fmt.eprintln("anushctl: could not find Anush data; set ANUSH_SYSTEM_DIR")
        delete(target)
        if source != "" { delete(source) }
        return "", false
    }
    defer delete(source)

    parent := filepath.dir(target)
    if !os.exists(parent) {
        if err := os.make_directory_all(parent); err != nil {
            fmt.eprintln("anushctl: cannot create", parent, ":", err)
            delete(target)
            return "", false
        }
    }

    staging, staging_err := os.make_directory_temp(
        parent, ".anush-initialize-*", context.allocator)
    if staging_err != nil {
        fmt.eprintln("anushctl: cannot create initialization directory:", staging_err)
        delete(target)
        return "", false
    }
    defer delete(staging)

    if err := os.copy_directory_all(staging, source); err != nil {
        _ = os.remove_all(staging)
        fmt.eprintln("anushctl: cannot initialize from", source, ":", err)
        delete(target)
        return "", false
    }
    if !ensure_script_permissions(staging) {
        _ = os.remove_all(staging)
        delete(target)
        return "", false
    }
    if err := os.rename(staging, target); err != nil {
        _ = os.remove_all(staging)
        if root_is_complete(target) { return target, true }
        fmt.eprintln("anushctl: cannot install user files at", target, ":", err)
        delete(target)
        return "", false
    }

    fmt.println("Initialized Anush at", target)
    return target, true
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
    helper := fmt.aprintf("%s/shell/scripts/clipboard-history", root)
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
        "%s/config/wallpaper/hadrut_srcery.jpeg", root)
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
        fmt.eprintln("anushctl: cannot resolve the Anush shell directory")
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
        fmt.eprintln("anushctl: Anush shell is not running or did not accept the command")
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
        fmt.eprintln("anushctl: Anush shell is not running")
        return EXIT_NOT_RUNNING
    }

    // The kill command acknowledges the request before the old instance has
    // necessarily removed its IPC registration. Launching immediately with
    // --no-duplicate can therefore succeed without creating a replacement.
    if !wait_for_shell(shell_dir, false, 30) {
        fmt.eprintln("anushctl: timed out waiting for Anush to stop")
        return EXIT_RUNTIME
    }

    configure_shell_environment(root)
    code, out, err_out, launched := run_process(
        []string{"qs", "-d", "--no-duplicate", "-p", shell_dir})
    defer delete(out)
    defer delete(err_out)
    if !launched || code != 0 {
        if len(err_out) > 0 { fmt.eprint(string(err_out)) }
        fmt.eprintln("anushctl: failed to relaunch Anush")
        return EXIT_RUNTIME
    }
    if !wait_for_shell(shell_dir, true, 50) {
        fmt.eprintln("anushctl: Anush was launched but did not become ready")
        return EXIT_RUNTIME
    }
    fmt.println("Anush restarted.")
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
        fmt.eprintln("anushctl: failed to launch Anush:", err)
        return EXIT_RUNTIME
    }
    state, wait_err := os.process_wait(process)
    if wait_err != nil {
        fmt.eprintln("anushctl: failed while waiting for Anush:", wait_err)
        return EXIT_RUNTIME
    }
    return state.exit_code
}
