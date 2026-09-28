#!/bin/sh
set -eu

repo=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

defaults=$repo/config/defaults.json
user=$tmp/config.json
state=$tmp/state.json
effective=$tmp/effective.json
errors=$tmp/errors

cat >"$user" <<'EOF'
{
  "bar": {"height": 40, "widgets": {"clock": false}},
  "theme": {"accent": "custom", "customAccent": "#89b4fa"},
  "launcher": {"favorites": ["one.desktop"]},
  "unknownSection": true
}
EOF
cat >"$state" <<'EOF'
{"bar":{"scale":1.25},"launcher":{"favorites":["runtime.desktop"]}}
EOF

"$repo/shell/scripts/config/load-config" \
    "$defaults" "$user" "$state" >"$effective" 2>"$errors"

python3 - "$effective" <<'PY'
import json
import sys

value = json.load(open(sys.argv[1]))
assert value["bar"]["height"] == 40
assert value["bar"]["scale"] == 1.25
assert value["bar"]["position"] == "top"
assert value["bar"]["widgets"] == {"clock": False}
assert value["launcher"]["favorites"] == ["runtime.desktop"]
assert value["theme"]["mode"] == "dark"
assert "unknownSection" not in value
PY
grep -q "unknown user config key 'unknownSection'" "$errors"

# Both optional layers may be absent.
"$repo/shell/scripts/config/load-config" \
    "$defaults" "$tmp/missing-user" "$tmp/missing-state" >"$effective"
python3 - "$defaults" "$effective" <<'PY'
import json
import sys

assert json.load(open(sys.argv[1])) == json.load(open(sys.argv[2]))
PY

# A clean first run does not create state just to duplicate defaults.
mkdir "$tmp/legacy"
new_state=$tmp/state-home/anush/shell-state.json
"$repo/shell/scripts/state/migrate-state" \
    "$new_state" "$defaults" "$tmp/legacy"
test ! -e "$new_state"
test -d "$tmp/state-home/anush"

echo "config loading tests passed"
