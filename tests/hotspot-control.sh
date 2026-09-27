#!/bin/sh

set -eu

repo=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)

python3 -c 'import pathlib, sys; path = pathlib.Path(sys.argv[1]); compile(path.read_bytes(), str(path), "exec")' \
    "$repo/shell/scripts/hotspot/hotspot-control"
python3 -c 'import pathlib, sys; path = pathlib.Path(sys.argv[1]); compile(path.read_bytes(), str(path), "exec")' \
    "$repo/shell/scripts/hotspot/hotspot-create-ap-helper"
python3 -c 'import pathlib, sys; path = pathlib.Path(sys.argv[1]); compile(path.read_bytes(), str(path), "exec")' \
    "$repo/shell/scripts/hotspot/hotspot-limit-enforcer"
test -x "$repo/shell/scripts/hotspot/hotspot-run-root"
sh -n "$repo/shell/scripts/hotspot/hotspot-run-root"
result=$(python3 "$repo/shell/scripts/hotspot/hotspot-control" self-test)
case "$result" in
    *'"ok":true'*) ;;
    *) printf 'hotspot helper self-test failed: %s\n' "$result" >&2; exit 1 ;;
esac

# Quickshell writes a newline-delimited request but intentionally keeps the
# process stdin pipe open. The helper must consume the line without awaiting
# EOF, otherwise Save and Enable remain busy forever.
python3 - "$repo/shell/scripts/hotspot/hotspot-control" <<'PY'
import subprocess
import sys

process = subprocess.Popen(
    [sys.executable, sys.argv[1], "apply"],
    stdin=subprocess.PIPE,
    stdout=subprocess.PIPE,
    stderr=subprocess.PIPE,
    text=True,
)
assert process.stdin is not None
process.stdin.write("{invalid json}\n")
process.stdin.flush()
try:
    process.wait(timeout=1)
except subprocess.TimeoutExpired:
    process.kill()
    raise AssertionError("hotspot helper waited for stdin EOF")
assert process.returncode == 1
PY

printf '%s\n' 'hotspot control tests passed'
