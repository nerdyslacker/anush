# skarwm integration

anush does not install or own a skarwm configuration. Add the lines you want
directly to your user-owned `$XDG_CONFIG_HOME/skarwm/skarwm.rc`; the former
`config.rc` name remains supported as a fallback.

The graphical skarwm editor follows recursive `import` directives. Imported
bindings and other entries are shown alongside entries from the main file, and
changes are saved back to the rc file that owns each entry.

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
autostart : "picom --config ${ANUSH_CONFIG_DIR:-${XDG_CONFIG_HOME:-$HOME/.config}/skarwm/anush}/picom/picom.conf ${ANUSH_PICOM_ARGS:-} -b"
```

This line is required for separated-section transparency unless another X11
compositor is already started elsewhere.

The Layout picker's **Picom compositor** switch starts or stops Anush's Picom
instance and stores the preference in Anush state. It does not rewrite this rc
entry or reload skarwm. The switch is hidden when Picom is not installed.

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

Window-border, corner-radius, decoration, and theme controls use `skarwm-msg`
to update the running WM without rewriting its rc file.

While anush is connected through skarwm's shell UI subscription, automatic rc
hot reload is suspended. Shell controls apply gaps, window radius, and
decorations through live IPC commands, then persist their values without
reloading the WM or closing open popups. Anush persists them in its own state;
the skarwm rc remains the standalone fallback. Explicit reload commands and **Save &
Reload** in the skarwm editor still reload the configuration. Normal automatic
hot reload resumes as soon as the shell disconnects.
