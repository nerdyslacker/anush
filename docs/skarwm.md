# skarwm integration

anush does not install or own your main skarwm configuration. Add the sections
you want to `$XDG_CONFIG_HOME/skarwm/default.conf` or an imported module.

When an Anush control changes a skarwm value, it creates `anush.conf` beside
the active root and adds this final import to the root if needed:

```ini
[import]
anush = anush.conf
```

All generated overrides are grouped by section in `anush.conf`; Anush leaves
the remaining contents of `default.conf` and its other modules unchanged.

## Required

Start the shell with the session:

```ini
[autostart]
anush = anushctl start
```

This is the only required skarwm entry.

On X11, a compositor is also required for transparent surfaces. Without one,
the unused area around separated bar sections is rendered black. To use the
anush Picom defaults, add:

```ini
[autostart]
picom = picom --config ${ANUSH_CONFIG_DIR:-${XDG_CONFIG_HOME:-$HOME/.config}/skarwm/anush}/picom/picom.conf ${ANUSH_PICOM_ARGS:---no-use-damage} -b
```

This line is required for separated-section transparency unless another X11
compositor is already started elsewhere.

The Layout picker's **Picom compositor** switch manages this assignment. Disabling
comments it out and stops Picom; enabling restores it and executes the exact
command. If the assignment is absent, enabling the switch adds the command
above to `anush.conf`. The switch is hidden when Picom is
not installed. An installed Picom with no matching autostart line is shown as
disabled until the user enables it.

## Optional key bindings

```ini
[bind]
"mod + a" = anushctl launcher toggle
"mod + v" = anushctl clipboard toggle

# Keep the generated Shift variant from arming tab placement for this
# non-window IPC command.
"mod + Shift + v" = anushctl clipboard toggle
"mod + Shift + n" = anushctl notes toggle
```

These combinations are examples; change or omit them to fit your configuration.

## Optional services

```ini
[autostart]
# Restore the last wallpaper, or the bundled default on a clean session.
wallpaper = anushctl wallpaper restore

# Required only for anush's clipboard-history widget.
clipboard = anushctl clipboard daemon

# Use anushctl as the stable lock command if xss-lock is desired.
lock = xss-lock -- anushctl lock
```

Window-border, corner-radius, and decoration controls in anush update the
`anush.conf` overlay associated with the active configuration reported by
`skarwm-msg`.
