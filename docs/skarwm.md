# skarwm integration

anush does not install or own a skarwm configuration. Add the lines you want
directly to your user-owned `$XDG_CONFIG_HOME/skarwm/config.rc`.

## Required

Start the shell with the session:

```text
autostart : "anushctl start"
```

This is the only required skarwm line.

On X11, a compositor is also required for transparent surfaces. Without one,
the unused area around separated bar sections is rendered black. To use the
anush Picom defaults, add:

```text
autostart : "picom --config ${ANUSH_CONFIG_DIR:-${XDG_CONFIG_HOME:-$HOME/.config}/skarwm/anush}/picom/picom.conf ${ANUSH_PICOM_ARGS:---no-use-damage} -b"
```

This line is required for separated-section transparency unless another X11
compositor is already started elsewhere.

The Layout picker's **Picom compositor** switch manages this line. Disabling
comments it out and stops Picom; enabling uncomments it and executes the exact
quoted command. If the line is absent, enabling the switch adds the command
above to the active skarwm configuration. The switch is hidden when Picom is
not installed. An installed Picom with no matching autostart line is shown as
disabled until the user enables it.

## Optional key bindings

```text
bind : mod + a : "anushctl launcher toggle"
bind : mod + v : "anushctl clipboard toggle"

# Keep the generated Shift variant from arming tab placement for this
# non-window IPC command.
bind : mod + Shift + v : "anushctl clipboard toggle"
bind : mod + Shift + n : "anushctl notes toggle"
```

These combinations are examples; change or omit them to fit your configuration.

## Optional services

```text
# Restore the last wallpaper, or the bundled default on a clean session.
autostart : "anushctl wallpaper restore"

# Required only for anush's clipboard-history widget.
autostart : "anushctl clipboard daemon"

# Use anushctl as the stable lock command if xss-lock is desired.
autostart : "xss-lock -- anushctl lock"
```

Window-border, corner-radius, and decoration controls in anush update the
active skarwm configuration reported by `skarwm-msg`. They do not require a
second anush-owned rc template.
