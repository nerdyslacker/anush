#!/usr/bin/env python3

import json
import os
from pathlib import Path
import subprocess
import tempfile


ROOT = Path(__file__).resolve().parents[1]
PROVIDER = ROOT / "shell/scripts/wm/herbstluftwm-provider"
FIXTURE = ROOT / "tests/fixtures/herbstluftwm"

environment = os.environ.copy()
environment["ANUSH_HERBSTLUFTWM_FIXTURE_DIR"] = str(FIXTURE)
environment["PATH"] = str(FIXTURE / "bin") + os.pathsep + environment["PATH"]

result = subprocess.run(
    [str(PROVIDER), "snapshot"], env=environment, check=True,
    capture_output=True, text=True,
)
snapshot = json.loads(result.stdout)

assert snapshot["connected"] is True
assert [screen["id"] for screen in snapshot["screens"]] == ["0", "1"]
assert [screen["name"] for screen in snapshot["screens"]] == ["DP-1", "1"]
assert [screen["focused"] for screen in snapshot["screens"]] == [False, True]
assert snapshot["screens"][1]["geometry"] == {
    "x": -1280, "y": 0, "width": 1280, "height": 1024,
}
assert snapshot["screens"][0]["workarea"] == {
    "x": 0, "y": 28, "width": 1920, "height": 1052,
}
assert [workspace["name"] for workspace in snapshot["workspaces"]] == [
    "term", "web", "chat", "empty",
]
assert [workspace["visible"] for workspace in snapshot["workspaces"]] == [
    True, False, True, False,
]
assert snapshot["workspaces"][0]["screenId"] == "0"
assert snapshot["workspaces"][1]["screenId"] is None
assert snapshot["workspaces"][2]["focused"] is True
assert snapshot["workspaces"][0]["urgent"] is True
assert snapshot["workspaces"][3]["occupied"] is False
assert len(snapshot["windows"]) == 3
assert snapshot["windows"][1]["screenId"] is None
assert snapshot["windows"][1]["fullscreen"] is True
assert snapshot["windows"][1]["minimized"] is True
assert snapshot["windows"][2]["focused"] is True
assert snapshot["windows"][2]["floating"] is True
assert snapshot["capabilities"]["perScreenWorkspaces"] is False
assert snapshot["capabilities"]["moveWindowToScreen"] is True

with tempfile.TemporaryDirectory(prefix="anush-herbstluftwm-test.") as directory:
    log = Path(directory) / "action.log"
    environment["ANUSH_HERBSTLUFTWM_ACTION_LOG"] = str(log)

    def action(*arguments):
        subprocess.run(
            [str(PROVIDER), "action", *arguments], env=environment, check=True,
            capture_output=True, text=True,
        )
        return log.read_text().splitlines()

    assert action("workspace", "web", "1") == [
        "-n", "chain", ",", "focus_monitor", "1", ",", "use", "web",
    ]
    assert action("move-workspace", "0x600001", "web") == [
        "-n", "apply_tmp_rule", "0x600001", "tag=web", "focus=off",
    ]
    assert action("move-screen", "0x600001", "1") == [
        "-n", "apply_tmp_rule", "0x600001", "monitor=1", "focus=off",
    ]
    assert action("close", "0x600001") == ["-n", "close", "0x600001"]

print("herbstluftwm provider tests passed")
