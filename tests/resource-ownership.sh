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

grep -Fq 'command: [root.eventMonitorExecutable, "--session"' \
    shell/components/Phone/PhoneService.qml
grep -Fq '&& (!root.eventMonitorOnline || root.eventMonitorFailed)' \
    shell/components/Phone/PhoneService.qml

# Disabled widgets must not briefly start with defaults during config loading,
# and services retained as QML singletons must stop recurring work at runtime.
grep -Fq '|| (stateLoaded && widgets[key] !== false)' \
    shell/components/Bar/BarVisibility.qml
grep -Fq 'model: barScreens' shell/shell.qml
for ownership in \
    'Network/NetworkService.qml:widgetEnabled: BarVisibility.enabled("network")' \
    'Network/HotspotService.qml:widgetEnabled: BarVisibility.enabled("network")' \
    'Network/BluetoothService.qml:widgetEnabled: BarVisibility.enabled("bluetooth")' \
    'Phone/PhoneService.qml:widgetEnabled: BarVisibility.enabled("phone")' \
    'Tailscale/TailscaleService.qml:widgetEnabled: BarVisibility.enabled("tailscale")' \
    'Clipboard/ClipboardState.qml:widgetEnabled: BarVisibility.enabled("clipboard")' \
    'Keyboard/KeyboardState.qml:BarVisibility.enabled("keyboard")' \
    'ColorPicker/ColorPickerState.qml:widgetEnabled: BarVisibility.enabled("colorPicker")' \
    'Tmux/TmuxService.qml:widgetEnabled: BarVisibility.enabled("tmux")' \
    'Audio/EasyEffectsService.qml:widgetEnabled: BarVisibility.enabled("volume")' \
    'Workspaces/WindowListState.qml:widgetEnabled: BarVisibility.enabled("windowList")'
do
    file=${ownership%%:*}
    pattern=${ownership#*:}
    grep -Fq "$pattern" "shell/components/$file"
done

if grep -Eq 'NotepadState\.initialize\(\)|ColorPickerState\.initialize\(\)|TailscaleService\.initialize\(\)' \
        shell/shell.qml; then
    echo "optional widget service was forced on by the shell root" >&2
    exit 1
fi

echo "resource ownership tests passed"
