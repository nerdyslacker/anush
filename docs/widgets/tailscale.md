# Tailscale

Manages a Tailscale connection and the current tailnet from the bar. The icon
shows the number of online machines while connected and marks login or health
warnings with a badge.

## Actions

- **Left click:** Open the Tailscale manager.
- **Middle click:** Refresh status, preferences, accounts, peers, and exit nodes.
- **Right click:** Connect or disconnect Tailscale.

The manager has four views:

- **Connection:** Connect, log in, inspect this machine, dismiss health
  warnings, review incoming Taildrop files, and control route, DNS, shields-up,
  exit-node LAN access, exit-node advertising, and Tailscale SSH preferences.
- **Exit nodes:** Select a tailnet exit node, use Tailscale's suggestion, or
  return to a direct connection.
- **Mullvad:** Search and select Mullvad regions when the tailnet has Mullvad
  exit nodes enabled. This view is hidden when none are available.
- **Machines:** Search online and offline peers, inspect traffic totals and
  last-seen time, use eligible machines as an exit node, copy an address, open
  Tailscale SSH, or send a file with Taildrop.

The **Admin** button opens the Tailscale machines page in the default browser.
The adjacent **Accounts** menu switches between saved Tailscale profiles or
starts browser login for another account.

## Requirements

Install the `tailscale` command and configure `tailscaled`. Reading status does
not need elevated privileges. Settings changes require Tailscale operator mode.
When the CLI reports access denied, the widget offers an **Authorize** button
that runs the equivalent of:

```sh
sudo tailscale set --operator="$USER"
```

The button uses PolicyKit (`pkexec`) and validates the current account name
before crossing the privilege boundary. `xdg-open` is used for login/admin
pages. Tailscale SSH uses `$TERMINAL` when available, then tries Kitty, `st`,
and finally Xterm.

Taildrop sending uses `tailscale file cp` directly. Incoming files are first
staged in anush's private state directory and trigger a desktop notification.
The Connection view then offers **Receive**, which moves the selected file to
`~/Downloads`, or **Reject**, which deletes that staged file. Name conflicts in
Downloads are resolved by adding a numeric suffix. The tailnet administrator
must enable file sharing before Taildrop controls become available.
