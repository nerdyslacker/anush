#!/bin/sh

set -eu

cd "$(dirname "$0")/.."

monitor_count=$(grep -R -F 'command: ["nmcli", "monitor"]' shell --include='*.qml' | wc -l)
if [ "$monitor_count" -ne 1 ]; then
    echo "expected one shared nmcli monitor, found $monitor_count" >&2
    exit 1
fi

grep -Fq 'signal networkStateInvalidated()' shell/components/Network/NetworkService.qml
grep -Fq 'function onNetworkStateInvalidated()' shell/components/Network/HotspotService.qml

if grep -Fq 'interval: 750' shell/components/Keyboard/KeyboardState.qml; then
    echo "keyboard layout polling was reintroduced" >&2
    exit 1
fi
grep -Fq 'command: ["xkb-switch", "-W"]' shell/components/Keyboard/KeyboardState.qml

if grep -Fq 'dunstctl is-paused' shell/common/Sys.qml; then
    echo "shell-wrapped DND polling was reintroduced" >&2
    exit 1
fi
grep -Fq 'command: ["xset", "q"]' shell/common/Sys.qml

echo "resource ownership tests passed"
