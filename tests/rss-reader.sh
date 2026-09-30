#!/bin/sh

set -eu

repo=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
helper="$repo/shell/scripts/rss/rss-reader"
tmp=$(mktemp -d /tmp/anush-rss-test.XXXXXX)
trap 'rm -rf "$tmp"' EXIT HUP INT TERM

result=$($helper self-test)
case "$result" in
    *'"ok":true'*'"rss":1'*'"atom":1'*) ;;
    *) printf 'rss-reader self-test failed: %s\n' "$result" >&2; exit 1 ;;
esac

snapshot=$($helper snapshot "$tmp/items.json" 100)
case "$snapshot" in
    *'"ok":true'*'"articles":[]'*'"unreadCount":0'*) ;;
    *) printf 'rss-reader empty snapshot failed: %s\n' "$snapshot" >&2; exit 1 ;;
esac

printf '%s\n' '{"version":1,"initialized":true,"articles":{"item-1":{"id":"item-1","feed":"Example","feedUrl":"https://example.com/feed","title":"One","url":"https://example.com/one","summary":"","author":"","published":"","timestamp":1,"read":false}}}' >"$tmp/items.json"
marked=$($helper mark-read "$tmp/items.json" item-1 100)
case "$marked" in
    *'"unreadCount":0'*) ;;
    *) printf 'rss-reader mark-read failed: %s\n' "$marked" >&2; exit 1 ;;
esac
case "$marked" in
    *'"read":true'*) ;;
    *) printf 'rss-reader mark-read failed: %s\n' "$marked" >&2; exit 1 ;;
esac

mode=$(stat -c '%a' "$tmp/items.json")
test "$mode" = 600

cleared=$(printf '%s\n' '{"feeds":[],"maxItems":100}' \
    | "$helper" refresh "$tmp/items.json")
case "$cleared" in
    *'"articles":[]'*'"unreadCount":0'*) ;;
    *) printf 'rss-reader feed removal failed: %s\n' "$cleared" >&2; exit 1 ;;
esac

PYTHONPYCACHEPREFIX="$tmp" python3 -m py_compile "$helper"

printf '%s\n' 'rss reader tests passed'
