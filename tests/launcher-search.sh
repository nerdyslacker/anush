#!/bin/sh

set -eu

repo=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
helper="$repo/shell/scripts/launcher/search-provider"
tmp=$(mktemp -d /tmp/anush-launcher-search.XXXXXX)
trap 'rm -rf "$tmp"' EXIT HUP INT TERM

mkdir -p "$tmp/home/.ssh/conf.d" "$tmp/bin"
cat >"$tmp/home/.ssh/config" <<'EOF'
Include conf.d/*.conf
Host prod *.wild !excluded
  HostName prod.example.test
  Include host-conditional.conf
Match host conditional
  Include conditional.conf
EOF
cat >"$tmp/home/.ssh/conf.d/team.conf" <<'EOF'
Host staging
EOF
cat >"$tmp/home/.ssh/conditional.conf" <<'EOF'
Host hidden-by-match
EOF
cat >"$tmp/home/.ssh/host-conditional.conf" <<'EOF'
Host hidden-by-host
EOF
cat >"$tmp/home/.ssh/known_hosts" <<'EOF'
visible.example ssh-ed25519 AAAA
|1|hashed|host ssh-ed25519 AAAA
[port.example]:2222 ssh-ed25519 AAAA
EOF

export HOME="$tmp/home"
ssh_json=$($helper ssh prod)
python3 - "$ssh_json" <<'PY'
import json, sys
data = json.loads(sys.argv[1])
assert [item["name"] for item in data["results"]] == ["prod"]
PY
ssh_json=$($helper ssh '')
python3 - "$ssh_json" <<'PY'
import json, sys
names = [item["name"] for item in json.loads(sys.argv[1])["results"]]
assert names == ["port.example", "prod", "staging", "visible.example"], names
assert "hidden-by-match" not in names
assert "hidden-by-host" not in names
PY
ssh_json=$($helper ssh deploy@example.test)
python3 - "$ssh_json" <<'PY'
import json, sys
items = json.loads(sys.argv[1])["results"]
assert items[-1]["detail"] == "Direct connection"
assert items[-1]["value"] == "deploy@example.test"
PY

cat >"$tmp/mountinfo" <<'EOF'
20 1 8:1 / / rw - ext4 /dev/old rw
21 1 0:1 / /proc rw - proc proc rw
22 1 8:2 / /media/My\040Disk rw - ext4 /dev/new rw
23 1 8:3 / /media/My\040Disk rw - xfs /dev/visible rw
EOF
export ANUSH_LAUNCHER_MOUNTINFO="$tmp/mountinfo"
mount_json=$($helper mounts xfs)
python3 - "$mount_json" <<'PY'
import json, sys
items = json.loads(sys.argv[1])["results"]
assert items == [{"kind": "mount", "name": "/media/My Disk", "detail": "/dev/visible · xfs", "value": "/media/My Disk"}], items
PY

cat >"$tmp/bin/plocate" <<'EOF'
#!/bin/sh
printf '%s\n' '/var/lib/Needle.db' "$HOME/docs/needle.txt"
EOF
cat >"$tmp/bin/fd" <<'EOF'
#!/bin/sh
printf '%s\n' "$HOME/docs/needle.txt" "$HOME/Needle.md"
EOF
chmod +x "$tmp/bin/plocate" "$tmp/bin/fd"
export PATH="$tmp/bin:/usr/bin:/bin"
file_json=$($helper file needle)
python3 - "$file_json" <<'PY'
import json, sys
items = json.loads(sys.argv[1])["results"]
assert len(items) == 3, items
assert items[0]["name"] in ("Needle.md", "Needle.db", "needle.txt")
assert not json.loads(sys.argv[1])["partial"]
PY

printf '%s\n' 'launcher search tests passed'
