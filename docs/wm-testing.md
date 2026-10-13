# Window manager testing

The real-WM harness runs anush and an actual window-manager binary in an
isolated Xephyr X11 server. It does not replace the WM managing the developer's
desktop and does not use provider fixtures.

## Build and inspect

The harness expects the sibling source layout used by this workspace:

```text
Experimental/
├── anush/
├── skarwm/
└── WM/
    ├── bspwm/
    ├── dwm/
    ├── herbstluftwm/
    ├── i3/
    ├── openbox/
    └── spectrwm/
```

Set `ANUSH_WM_SOURCE_DIR` if the `WM` directory is elsewhere. Check the host
tools and build results with:

```sh
tools/wm-real-test doctor
tools/wm-real-test build all
```

Individual builds are supported as well:

```sh
tools/wm-real-test build bspwm
tools/wm-real-test build herbstluftwm
tools/wm-real-test build i3
tools/wm-real-test build openbox
tools/wm-real-test build spectrwm
tools/wm-real-test build dwm
tools/wm-real-test build skarwm
```

Builds stay inside the workspace and are never installed system-wide.
When `WM/bsp-layout` is present, building bspwm stages it under
`anush/build/wm/bsp-layout` and adds it only to harness sessions. Its `layouts`
command is used at runtime, so layout scripts added to that installation appear
in the picker without editing anush.
On Void-based systems, the current i3 and spectrwm sources additionally need:

```sh
sudo xbps-install -S startup-notification-devel libbsd-devel
```

The bspwm session also needs `sxhkd`, matching a normal bspwm installation:

```sh
sudo xbps-install -S sxhkd
```

Building the cloned Openbox source requires its normal Autotools dependencies,
including `autopoint`. On Void, `autopoint` is supplied by the Gettext
development tools. Openbox is configured and installed only under
`anush/build/wm/openbox`; nothing is installed system-wide.

The dwm build is copied to `build/wm/dwm` before its test-only configuration is
applied. The cloned dwm source is left untouched. This variant disables dwm's
bar, adopts Quickshell panels as EWMH docks, and follows their live struts so
dwm cannot tile the panel or place clients underneath it. It also publishes
the selected, occupied, and urgent tag masks plus the complete compiled layout
table through root-window properties. Workspace actions use
`_NET_CURRENT_DESKTOP` rather than simulated key presses. Stock dwm remains
unmodified and degrades without tag or layout controls when those properties
and optional dwm IPC are absent.

## Start a session

```sh
tools/wm-real-test run bspwm
tools/wm-real-test run i3 --display :96
tools/wm-real-test run openbox
tools/wm-real-test run skarwm --multi
tools/wm-real-test run herbstluftwm --backend herbstluftwm
```

The harness creates isolated runtime, state, configuration, and cache
directories below `/tmp`, starts a private D-Bus session, and uses automatic
backend selection. It preserves its logs when the session ends and prints
their directory. Close the Xephyr window or interrupt the harness to stop all
session processes. Automatic display selection skips live X servers and safely
removes old lock files when no X11 socket exists. Socket-backed displays are
always left alone. An explicit `--display` fails early when that display is
already in use.

The default `--backend auto` validates identity detection. Run each WM once
more with `--backend NAME` to validate explicit selection independently.

Four real Xterm clients open inside Xephyr. One is a control terminal with
these commands:

```sh
wm_smoke status
wm_smoke dump
wm_smoke check
wm_smoke ui
wm_smoke open
wm_smoke restart
wm_smoke logs
```

The regular CLI is also available there:

```sh
anushctl wm screens
anushctl wm workspaces
anushctl wm windows
anushctl wm workspace focus ID
anushctl wm window focus ID
anushctl wm window move-workspace WINDOW_ID WORKSPACE_ID
anushctl wm window close WINDOW_ID
```

Use opaque IDs exactly as reported by the state commands. Only invoke actions
whose corresponding capability is true.

Every harness configuration uses Super as its modifier and supplies the same
shell shortcuts:

- `Super+A`: application launcher
- `Super+V`: clipboard history
- `Super+Shift+N`: notes

The harness provisions nine workspaces or tags. Layout controls use each WM's
native names and commands: skarwm's six modes, bspwm tiled/monocle plus all
layouts reported by an installed `bsp-layout`, herbstluftwm
vertical/horizontal/max/grid, i3 split/stacking/tabbed, every layout compiled
into dwm's `layouts[]` table, and spectrwm
vertical/horizontal/max/floating. The harness dwm publishes that table through
an X root property; patched layouts therefore appear in the next built session,
including unknown layouts whose visible dwm symbol is used as their picker
name. Stock dwm has no protocol for enumerating the complete table, so this
discovery requires the harness patch or an equivalent integration in the
installed dwm.
Openbox is a stacking WM, so its layout capability is deliberately false and
the layout picker remains hidden.
The harness configuration supports click-to-focus, title-bar movement and
resizing, title-bar window controls, `Super+Shift+F` maximize,
`Super+Shift+Z` minimize, `Super+Shift+M` move, and `Super+Q` or `Alt+F4`
close.

`wm_smoke ui` opens the launcher directly, verifies that its input surface owns
keyboard focus, types a harmless search probe, closes it, and repeats the focus
check through `Super+A`. This catches both popup-focus and WM-binding failures.
bspwm runs the included sxhkd configuration; all other sessions use native WM
bindings.

## Session checklist

For each backend:

1. Confirm `wm_smoke status` selects the expected backend and reports
   `connected`.
2. Run `wm_smoke ui` and confirm both focus checks pass.
3. Confirm the sample clients appear once in `anushctl wm windows` with real
   titles and classes.
4. Open, focus, move, and close clients and watch the Bar update without a
   shell reload.
5. Switch workspaces or tags and verify focused, visible, occupied, and urgent
   state according to that WM's semantics.
6. Run `wm_smoke restart`. Anush must enter disconnected mode, retain its
   non-WM UI, reconnect, and rebuild fresh state.
7. Exercise every capability reported as true and confirm unsupported actions
   fail explicitly.

Expected scope differs by backend:

- skarwm: screens, workspaces, windows, layouts, scratchpads, and virtual
  screens;
- bspwm, herbstluftwm, and i3: native state, events, focus, movement, close,
  and restart recovery;
- spectrwm: the verified EWMH subset and global workspace limitations;
- Openbox: global EWMH workspaces, window metadata, focus, movement, close,
  reconfigure, session exit, and restart recovery; layout controls are absent;
- stock dwm: window metadata without fabricated tag or layout support;
- the harness dwm variant: nine real tags and native layout controls through
  its test-only state property;
- dwm-ipc: richer state only when the patched socket is genuinely available.

## Tests requiring a real login session

Xephyr exercises real WM processes and protocols, but it is not a substitute
for physical RandR outputs. Perform a final login-session pass for monitor
hotplug, DPI differences, physical-output mapping, popup placement, fullscreen
behavior, and skarwm virtual screens over multiple physical outputs.

Before that pass, keep a TTY available. Start only one WM on the target X
display, verify `anushctl wm status` immediately, and retain the harness logs
when comparing nested and physical-output behavior.
