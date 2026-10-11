#!/usr/bin/env python3

import json
import os
from pathlib import Path
import subprocess


ROOT = Path(__file__).resolve().parents[1]
PROVIDER = ROOT / "shell/scripts/wm/ewmh-provider"
FIXTURES = ROOT / "tests/fixtures"


def run(fixture, command):
    environment = os.environ.copy()
    environment["ANUSH_EWMH_FIXTURE_DIR"] = str(FIXTURES / fixture)
    result = subprocess.run(
        [str(PROVIDER), command], env=environment, check=True,
        capture_output=True, text=True,
    )
    return json.loads(result.stdout)


identity = run("ewmh-full", "detect")
assert identity == {
    "connected": True,
    "name": "spectrwm",
    "windowId": "0x200001",
    "identity": "spectrwm",
}

full = run("ewmh-full", "snapshot")
assert full["connected"] is True
assert full["wmIdentity"] == "spectrwm"
assert [workspace["name"] for workspace in full["workspaces"]] == [
    "term", "web", "chat",
]
assert [workspace["focused"] for workspace in full["workspaces"]] == [
    False, True, False,
]
assert [workspace["occupied"] for workspace in full["workspaces"]] == [
    True, True, False,
]
assert full["workspaces"][0]["urgent"] is True
assert len(full["windows"]) == 3
assert full["windows"][1]["focused"] is True
assert full["windows"][1]["maximized"] is True
assert full["windows"][2]["dock"] is True
assert full["capabilities"]["workspaces"] is True
assert full["capabilities"]["focusWindow"] is True
assert full["capabilities"]["moveWindowToWorkspace"] is True
assert full["capabilities"]["screens"] is False

dwm = run("ewmh-dwm", "snapshot")
assert dwm["wmIdentity"] == "dwm"
assert dwm["workspaces"] == []
assert len(dwm["windows"]) == 1
assert dwm["windows"][0]["workspaceId"] is None
assert dwm["capabilities"]["workspaces"] is False
assert dwm["capabilities"]["windows"] is True
assert dwm["capabilities"]["focusWindow"] is True
assert dwm["capabilities"]["closeWindow"] is False
assert dwm["capabilities"]["moveWindowToWorkspace"] is False

print("EWMH provider tests passed")
