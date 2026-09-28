# Launcher

Searches installed desktop applications, filters them by category, and keeps a
persistent Favorites category. Prefix searches add these sources:

- `f:` or `file:` searches filenames with both the system `plocate` index and
  a live `fd` walk of `$HOME` (`fdfind` is accepted as a fallback). Enter opens
  a result with `xdg-open`.
- `ssh:` lists named hosts from `~/.ssh/config`, local unconditional includes,
  and visible entries in `~/.ssh/known_hosts`. Enter connects in a terminal;
  Shift+Enter copies the safely quoted command. A failed connection leaves the
  terminal open so its error remains visible.
- `mounts:` lists mounted non-pseudo filesystems. Enter opens the mountpoint;
  Shift+Enter copies its path.

Type after any prefix to filter its results. File results are marked partial
when a search backend is unavailable, fails, times out, or reaches its result
limit. Wildcard and hashed SSH hosts and includes inside `Host` or `Match`
blocks are not listed.

## Actions

- **Left click:** Open or close the application launcher.

  ![Launcher Left Click](screenshots/launcher_left_click.png)

- **Right click:** Open the launcher icon editor.

  ![Launcher Right Click](screenshots/launcher_right_click.png)
