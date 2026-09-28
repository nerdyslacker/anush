# `anushctl`

`anushctl` is the supported command-line interface for the running anush shell.
It is written in Odin and delegates runtime operations to typed Quickshell IPC
handlers. It does not expose a raw command or shell-execution endpoint.

Start anush with:

```sh
anushctl start
```

On first start, the CLI locates the installed anush data, copies it atomically
to the user directory, launches `qs --no-duplicate`, and remains attached for
the lifetime of the shell. This makes it suitable for a skarwm `autostart`
entry without a separate initialization script.

On later starts, managed `shell/` and `assets/` files are refreshed from the
detected installation so package updates reach an existing user directory.
The user-owned `config/` directory is preserved. Setting `ANUSH_ROOT`
explicitly selects a checkout or custom tree and disables this refresh.

Starting the shell also activates anush's themed Fastfetch configuration at
Fastfetch's standard XDG path. Before creating the symlink, an existing config
is retained as `config.jsonc.pre-anush`.

## Runtime commands

```sh
anushctl status
anushctl reload
anushctl restart
anushctl lock
anushctl launcher toggle
anushctl clipboard toggle
anushctl clipboard daemon
anushctl sidebar toggle
anushctl notes toggle
anushctl notes new
anushctl notes save
anushctl notes close
anushctl popup network
anushctl popup hotspot
anushctl popup bluetooth
anushctl hotspot status
anushctl hotspot on
anushctl hotspot off
anushctl hotspot toggle
anushctl hotspot clients
anushctl wallpaper set ~/Pictures/wallpaper.jpg
anushctl wallpaper random
anushctl wallpaper restore
anushctl theme mode light
anushctl theme mode dark
```

`sidebar toggle` is an alias for the current Notepad sidebar. `reload` uses
Quickshell's native hard reload and keeps the process instance. `restart` waits
for the old instance to stop, launches its replacement, and verifies that its
IPC endpoint is ready. `lock` invokes Betterlockscreen and
returns its exit status. The `daemon` and `restore` commands provide stable
skarwm autostart entry points for anush-owned clipboard and wallpaper behavior.

The writable user directory is `$ANUSH_ROOT` when set, otherwise
`$XDG_CONFIG_HOME/anush` or `$HOME/.config/anush`. For first-run seeding, the
CLI finds the source installation in this order:

1. `$ANUSH_SYSTEM_DIR`
2. the source checkout containing a development `build/anushctl`
3. `<executable-prefix>/share/anush`
4. `/usr/share/anush` or `/usr/local/share/anush`

An existing but incomplete user directory is never overwritten; `anushctl`
reports the missing installation instead.

If no matching Quickshell instance is available, runtime commands print a clear
error and return exit code 3. Invalid usage returns 2 and other runtime or file
errors return 1.

## Compositor integration

```sh
anushctl install skarwm
anushctl remove skarwm
```

The installer preserves existing configuration by adding a marked, idempotent
block to `$XDG_CONFIG_HOME/skarwm/config.rc`.

The integration launches `anushctl start`, restores the wallpaper, starts
clipboard capture, configures `xss-lock` to call `anushctl lock`, and adds
launcher, clipboard, and Notepad bindings. `anushctl start` runs user-directory
initialization before it starts Quickshell. Run `anushctl remove skarwm` to
delete only the lines managed by `anushctl`.

## Protocol

The shell exposes the versioned `anush` target alongside feature-specific
targets:

```text
anush.status() -> JSON string
anush.reload()
anush.themeMode("light" | "dark")
launcher.toggleCentered()
clipboard.toggle()
notepad.toggle() | newNote() | save() | close()
network.open()
hotspot.openPopup()
hotspot.status() | enable() | disable() | toggle() | clients()
bluetooth.open()
wallpapers.set(path) | random()
```

New features should add a typed `IpcHandler` function and an explicit parser
branch in `anushctl`; arbitrary target/function forwarding is intentionally not
part of the public CLI.
