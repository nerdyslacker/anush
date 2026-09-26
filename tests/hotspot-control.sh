#!/bin/sh

set -eu

repo=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)

python3 -c 'import pathlib, sys; path = pathlib.Path(sys.argv[1]); compile(path.read_bytes(), str(path), "exec")' \
    "$repo/shell/scripts/hotspot-control"
result=$(python3 "$repo/shell/scripts/hotspot-control" self-test)
case "$result" in
    *'"ok":true'*) ;;
    *) printf 'hotspot helper self-test failed: %s\n' "$result" >&2; exit 1 ;;
esac

printf '%s\n' 'hotspot control tests passed'
