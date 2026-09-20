package main

import "core:fmt"
import "core:os"
import "core:strings"

SKARWM_BEGIN :: "# >>> Anush shell (managed by anushctl) >>>"
SKARWM_END   :: "# <<< Anush shell (managed by anushctl) <<<"

SKARWM_BLOCK :: `# >>> Anush shell (managed by anushctl) >>>
bind : mod + a : "anushctl launcher toggle"
bind : mod + v : "anushctl clipboard toggle"
bind : mod + Shift + v : "anushctl clipboard toggle"
bind : mod + Shift + n : "anushctl notes toggle"
autostart : "anushctl start"
autostart : "anushctl wallpaper restore"
autostart : "anushctl clipboard daemon"
autostart : "xss-lock -- anushctl lock"
# <<< Anush shell (managed by anushctl) <<<
`

LEGACY_SKARWM_AUTOSTARTS := [5]string{
    `autostart : "if [ -f ~/.fehbg ]; then sh ~/.fehbg; else feh --bg-fill ${ANUSH_CONFIG_DIR:-${XDG_CONFIG_HOME:-$HOME/.config}/anush/config}/wallpaper/hadrut_srcery.jpeg; fi"`,
    `autostart : "if [ -f ~/.fehbg ]; then sh ~/.fehbg; else feh --bg-fill ${ANUSH_CONFIG_DIR:-$HOME/.config/anush/config}/wallpaper/hadrut_srcery.jpeg; fi"`,
    `autostart : "${ANUSH_ROOT:-${XDG_CONFIG_HOME:-$HOME/.config}/anush}/shell/scripts/clipboard-history daemon"`,
    `autostart : "${ANUSH_ROOT:-$HOME/.config/anush}/shell/scripts/clipboard-history daemon"`,
    `autostart : "xss-lock -- betterlockscreen -l"`,
}

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

read_text :: proc(path: string) -> (string, bool) {
    if !os.exists(path) { return "", true }
    data, err := os.read_entire_file(path, context.allocator)
    if err != nil {
        fmt.eprintln("anushctl: cannot read", path, ":", err)
        return "", false
    }
    return string(data), true
}

strip_legacy_skarwm_autostarts :: proc(input: string) -> string {
    current := strings.clone(input)
    for legacy in LEGACY_SKARWM_AUTOSTARTS {
        line := fmt.aprintf("%s\n", legacy)
        next, allocated := strings.replace(current, line, "", -1)
        delete(line)
        if allocated {
            delete(current)
            current = next
        }
    }
    return current
}

upsert_managed_block :: proc(path, begin, end, block: string) -> int {
    original, ok := read_text(path)
    if !ok { return EXIT_RUNTIME }
    defer if len(original) > 0 { delete(transmute([]byte)original) }
    current := strip_legacy_skarwm_autostarts(original)
    defer delete(current)

    parent := parent_dir(path)
    defer delete(parent)
    if !os.exists(parent) {
        if err := os.make_directory_all(parent); err != nil {
            fmt.eprintln("anushctl: cannot create", parent, ":", err)
            return EXIT_RUNTIME
        }
    }
    updated := ""
    start := strings.index(current, begin)
    if start >= 0 {
        finish_relative := strings.index(current[start:], end)
        if finish_relative < 0 {
            fmt.eprintln("anushctl: managed block in", path, "has no end marker; refusing to edit it")
            return EXIT_RUNTIME
        }
        finish := start + finish_relative + len(end)
        if finish < len(current) && current[finish] == '\r' { finish += 1 }
        if finish < len(current) && current[finish] == '\n' { finish += 1 }
        updated = fmt.aprintf("%s%s%s", current[:start], block, current[finish:])
    } else {
        separator := ""
        if len(current) > 0 && current[len(current) - 1] != '\n' { separator = "\n" }
        prefix := ""
        if len(current) > 0 { prefix = "\n" }
        updated = fmt.aprintf("%s%s%s%s", current, separator, prefix, block)
    }
    defer delete(updated)
    if err := os.write_entire_file(path, updated); err != nil {
        fmt.eprintln("anushctl: cannot write", path, ":", err)
        return EXIT_RUNTIME
    }
    fmt.println("Installed Anush integration in", path)
    return EXIT_OK
}

remove_managed_block :: proc(path, begin, end: string) -> int {
    current, ok := read_text(path)
    if !ok { return EXIT_RUNTIME }
    defer if len(current) > 0 { delete(transmute([]byte)current) }
    start := strings.index(current, begin)
    if start < 0 {
        fmt.println("No Anush integration found in", path)
        return EXIT_OK
    }
    finish_relative := strings.index(current[start:], end)
    if finish_relative < 0 {
        fmt.eprintln("anushctl: managed block in", path, "has no end marker; refusing to edit it")
        return EXIT_RUNTIME
    }
    finish := start + finish_relative + len(end)
    if finish < len(current) && current[finish] == '\r' { finish += 1 }
    if finish < len(current) && current[finish] == '\n' { finish += 1 }
    if start > 0 && current[start - 1] == '\n' { start -= 1 }
    updated := fmt.aprintf("%s%s", current[:start], current[finish:])
    defer delete(updated)
    if err := os.write_entire_file(path, updated); err != nil {
        fmt.eprintln("anushctl: cannot write", path, ":", err)
        return EXIT_RUNTIME
    }
    fmt.println("Removed Anush integration from", path)
    return EXIT_OK
}

parent_dir :: proc(path: string) -> string {
    slash := strings.last_index(path, "/")
    if slash <= 0 { return strings.clone(".") }
    return strings.clone(path[:slash])
}

install_skarwm :: proc() -> int {
    base := config_home()
    if base == "" {
        fmt.eprintln("anushctl: HOME and XDG_CONFIG_HOME are unset")
        return EXIT_RUNTIME
    }
    defer delete(base)

    path := fmt.aprintf("%s/skarwm/config.rc", base)
    defer delete(path)
    return upsert_managed_block(
        path, SKARWM_BEGIN, SKARWM_END, SKARWM_BLOCK)
}

remove_skarwm :: proc() -> int {
    base := config_home()
    if base == "" {
        fmt.eprintln("anushctl: HOME and XDG_CONFIG_HOME are unset")
        return EXIT_RUNTIME
    }
    defer delete(base)

    skarwm_path := fmt.aprintf("%s/skarwm/config.rc", base)
    defer delete(skarwm_path)
    return remove_managed_block(skarwm_path, SKARWM_BEGIN, SKARWM_END)
}
