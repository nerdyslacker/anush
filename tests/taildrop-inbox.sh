#!/bin/sh

set -eu

repo=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
helper="$repo/shell/scripts/tailscale/taildrop-inbox"
tmp=$(mktemp -d /tmp/anush-taildrop-test.XXXXXX)
trap 'rm -rf "$tmp"' EXIT HUP INT TERM

mkdir -p "$tmp/bin" "$tmp/inbox" "$tmp/downloads"
cat >"$tmp/bin/tailscale" <<'EOF'
#!/bin/sh
target=$5
printf '%s\n' 'pending data' >"$target/report.txt"
EOF
chmod +x "$tmp/bin/tailscale"

"$helper" poll "$tmp/inbox" "$tmp/bin/tailscale" >"$tmp/list.json"
python3 - "$tmp/list.json" <<'PY'
import json, sys
items = json.load(open(sys.argv[1], encoding="utf-8"))
assert len(items) == 1
assert items[0]["name"] == "report.txt"
assert items[0]["size"] > 0
PY

"$helper" accept "$tmp/inbox" "$tmp/downloads" report.txt
test -f "$tmp/downloads/report.txt"
test ! -e "$tmp/inbox/report.txt"

printf '%s\n' reject >"$tmp/inbox/reject.txt"
"$helper" reject "$tmp/inbox" reject.txt
test ! -e "$tmp/inbox/reject.txt"

if "$helper" reject "$tmp/inbox" ../outside 2>/dev/null; then
    echo "unsafe filename was accepted" >&2
    exit 1
fi

printf '%s\n' "taildrop inbox tests passed"
