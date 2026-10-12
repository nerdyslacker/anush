#!/usr/bin/env python3

import json
import os
from pathlib import Path
import subprocess


ROOT = Path(__file__).resolve().parents[1]
PROVIDER = ROOT / "shell/scripts/wm/ewmh-provider"
FIXTURE = ROOT / "tests/fixtures/ewmh-dwm"

environment = os.environ.copy()
environment["ANUSH_EWMH_FIXTURE_DIR"] = str(FIXTURE)


def run(command, *arguments):
    return subprocess.run(
        [str(PROVIDER), command, *arguments], env=environment, check=True,
        capture_output=True, text=True,
    )


identity = json.loads(run("detect").stdout)
assert identity["identity"] == "dwm"

snapshot = json.loads(run("snapshot", "dwm").stdout)
assert snapshot["connected"] is True
assert snapshot["wmName"] == "dwm"
assert snapshot["wmIdentity"] == "dwm"
assert snapshot["screens"] == []
assert snapshot["workspaces"] == []
assert len(snapshot["windows"]) == 1

window = snapshot["windows"][0]
assert window["title"] == "xterm"
assert window["class"] == "XTerm"
assert window["instance"] == "xterm"
assert window["workspaceId"] is None
assert window["screenId"] is None
assert window["focused"] is True
assert window["urgent"] is True
assert window["floating"] is None
assert window["fullscreen"] is False
assert window["maximized"] is None

capabilities = snapshot["capabilities"]
assert capabilities["windows"] is True
assert capabilities["windowTitles"] is True
assert capabilities["windowAppIdentity"] is True
assert capabilities["eventStream"] is True
assert capabilities["screens"] is False
assert capabilities["workspaces"] is False
assert capabilities["focusWindow"] is False
assert capabilities["closeWindow"] is False
assert capabilities["moveWindowToWorkspace"] is False
assert capabilities["moveWindowToScreen"] is False
assert capabilities["scratchpad"] is False
assert capabilities["layouts"] is False
assert capabilities["gaps"] is False
assert capabilities["reload"] is False
assert capabilities["sessionControl"] is False

events = run("monitor").stdout.splitlines()
assert len(events) == 2

print("stock dwm backend tests passed")
