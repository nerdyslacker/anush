#!/usr/bin/env python3

import json
import os
from pathlib import Path
import subprocess


ROOT = Path(__file__).resolve().parents[1]
PROVIDER = ROOT / "shell/scripts/wm/bspwm-provider"
FIXTURE = ROOT / "tests/fixtures/bspwm"

environment = os.environ.copy()
environment["ANUSH_BSPWM_FIXTURE_DIR"] = str(FIXTURE)
result = subprocess.run(
    [str(PROVIDER), "snapshot"], env=environment, check=True,
    capture_output=True, text=True,
)
snapshot = json.loads(result.stdout)

assert snapshot["connected"] is True
assert [screen["id"] for screen in snapshot["screens"]] == [
    "0x00200001", "0x00200004",
]
assert [screen["focused"] for screen in snapshot["screens"]] == [True, False]
assert snapshot["screens"][0]["workarea"] == {
    "x": 5, "y": 30, "width": 1912, "height": 1046,
}
assert [workspace["name"] for workspace in snapshot["workspaces"]] == [
    "term", "web", "chat", "empty",
]
assert [workspace["index"] for workspace in snapshot["workspaces"]] == [
    0, 1, 0, 1,
]
assert [workspace["visible"] for workspace in snapshot["workspaces"]] == [
    False, True, True, False,
]
assert snapshot["workspaces"][1]["focused"] is True
assert snapshot["workspaces"][0]["urgent"] is True
assert snapshot["workspaces"][3]["occupied"] is False
assert len(snapshot["windows"]) == 3
assert snapshot["windows"][1]["focused"] is True
assert snapshot["windows"][1]["fullscreen"] is True
assert snapshot["windows"][2]["floating"] is True
assert snapshot["windows"][2]["screenId"] == "0x00200004"
assert snapshot["windows"][0]["title"] == "Terminal"
assert snapshot["capabilities"]["perScreenWorkspaces"] is True
assert snapshot["capabilities"]["moveWindowToScreen"] is True
assert snapshot["capabilities"]["scratchpad"] is False

print("bspwm provider tests passed")
