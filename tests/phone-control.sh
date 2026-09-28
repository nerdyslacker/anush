#!/bin/sh

set -eu

repo=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
helper="$repo/shell/scripts/phone/phone-control"
tmp=$(mktemp -d /tmp/anush-phone-test.XXXXXX)
trap 'rm -rf "$tmp"' EXIT HUP INT TERM

result=$($helper self-test)
case "$result" in
    *'"ok":true'*) ;;
    *) printf 'phone-control self-test failed: %s\n' "$result" >&2; exit 1 ;;
esac

PYTHONPYCACHEPREFIX="$tmp" python3 -m py_compile "$helper"

printf '%s\n' 'phone control tests passed'
