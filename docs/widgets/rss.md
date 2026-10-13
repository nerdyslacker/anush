# RSS reader

Reads RSS and Atom feeds in a themed article list. Search and All/Unread
filters are local. Opening an article marks it read before handing its URL to
`xdg-open`.

The widget is disabled by default and performs no requests while disabled. One
shared service refreshes feeds for every monitor. Feed configuration is stored
in `shell-state.json`; the bounded article and read-state cache is stored with
mode `0600` at
`${XDG_STATE_HOME:-$HOME/.local/state}/anush/rss-items.json`.

Fetching accepts only public HTTP(S) destinations, limits each response to 4
MiB, and never executes feed content. The initial import does not announce old
posts; later refreshes use the anush notice overlay for new-item counts.

## Actions

- **Left click:** Open the article list.
- **Middle click:** Refresh all feeds.
- **Right click:** Open feed settings.
- **Feeds:** Add or remove RSS and Atom URLs and change the refresh interval.
