# Configuration ownership and precedence

anush has three distinct storage classes:

| Class | Default location | Contents | Writable by anush |
|---|---|---|---|
| Package data | `${prefix}/share/anush` | QML, helpers, assets, canonical defaults, application templates, bundled wallpapers and theme presets | No |
| User config | `${XDG_CONFIG_HOME:-$HOME/.config}/skarwm/anush` | Optional intentional overrides, generated application config, and user-created presets | Only for initialization or an explicit user action |
| User state | `${XDG_STATE_HOME:-$HOME/.local/state}/anush` | Runtime and persistent UI state | Yes |

`ANUSH_DEFAULT_CONFIG`, `ANUSH_CONFIG_DIR`/`ANUSH_USER_CONFIG`, and
`ANUSH_STATE_DIR` override the individual paths for development and testing.
Installed defaults are otherwise
located relative to the active QML shell, so alternate installation prefixes do
not require `/usr/share/anush` to be embedded in user files.

## Shell configuration model

There was no separate configuration parser before this model. The shell read
`shell-state.json`, filled missing values from a QML object, and merged only one
object level below each section. It had no import syntax, no user override file,
and arrays were assigned implicitly.

The loader now produces one effective object in this order:

1. the emergency QML fallback, used only if loading fails;
2. package defaults from `config/defaults.json`;
3. optional user overrides from `$XDG_CONFIG_HOME/skarwm/anush/config.json`;
4. mutable state from `$XDG_STATE_HOME/anush/shell-state.json`.

The package JSON is the canonical complete configuration. A user file can be as
small as:

```json
{
  "bar": {"height": 40},
  "theme": {"accent": "custom", "customAccent": "#89b4fa"}
}
```

Objects merge recursively, so this preserves `bar.position`, `bar.scale`, and
all other installed values. Scalars replace the lower-precedence value. Arrays
replace as a whole; there is no implicit append, prepend, or item deletion.
This applies to favorites and hidden tray entries and avoids guessing an
identity or order for list elements. The intentionally free-form objects
`bar.widgets`, `bar.clusters`, and `keyboard.layout` accept user-defined child
keys. Other unknown user keys and incompatible types produce diagnostics and
are ignored. User files are never rewritten.

The user file and state file are both optional. A clean run neither creates a
complete user config nor creates state merely to duplicate defaults. State is
created when a setting is changed through the running shell, or when legacy
state is actually migrated. New keys added to the installed JSON therefore
appear automatically unless a higher-precedence layer defines them.

This is loader-level composition rather than a JSON `include` extension. It is
smaller, hides prefix-specific paths, gives every QML consumer the same
effective object, and leaves standard JSON tooling usable.

## Current file audit

The repository content has the following intended ownership:

- `shell/`, `shell/scripts/`, and `assets/` are package implementation/data.
- `config/defaults.json`, `config/themes/presets/`, `config/wallpaper/`,
  `config/matugen/config.toml`, and the dunst, kitty, picom, rofi, and Fastfetch
  files are installed defaults or templates.
- `shell-state.json`, clipboard history, generated palettes, and display
  rollback data are state/cache and must remain outside package data.
- Notepad documents are user data under `$XDG_DATA_HOME/anush/notepad`.
- GTK, Qt, Fastfetch, kitty, and live skarwm files generated or changed by theme
  actions are user configuration owned by their respective applications.

`anushctl` runs QML and helpers from the package tree. It seeds only the
writable dunst, Fastfetch, kitty, Picom, and rofi files under `skarwm/anush`
when those directories are absent. Package assets, wallpapers, Matugen
configuration, and built-in presets are never copied. Generated colors modify
only the writable copies and the user's active skarwm configuration.

## skarwm evaluation

skarwm's current rc parser has no include/import directive. It loads the first
existing rc file, applies built-in scalar defaults for omitted settings, and
treats a discovered file as the complete binding/directive set. Repeated
bindings, rules, autostarts, and bar blocks are ordered lists, so a generic
deep-merge rule would be unsafe.

anush therefore does not install, remove, or bundle a skarwm rc file. The user
adds the required startup line and any optional bindings directly; see
[`skarwm.md`](skarwm.md). A future skarwm-side `include` feature would still
need explicit ordering and duplicate semantics for repeated directives.
