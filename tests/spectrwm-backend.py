#!/usr/bin/env python3

import json
import os
from pathlib import Path
import subprocess
import tempfile


ROOT = Path(__file__).resolve().parents[1]
PROVIDER = ROOT / "shell/scripts/wm/ewmh-provider"
FIXTURE = ROOT / "tests/fixtures/spectrwm"

environment = os.environ.copy()
environment["ANUSH_EWMH_FIXTURE_DIR"] = str(FIXTURE)


def run(command, *arguments):
    return subprocess.run(
        [str(PROVIDER), command, *arguments], env=environment, check=True,
        capture_output=True, text=True,
    )


identity = json.loads(run("detect").stdout)
assert identity["identity"] == "spectrwm"

snapshot = json.loads(run("snapshot").stdout)
assert snapshot["connected"] is True
assert snapshot["wmIdentity"] == "spectrwm"
assert [workspace["name"] for workspace in snapshot["workspaces"]] == [
    "term", "web", "chat", "files",
]
assert [workspace["visible"] for workspace in snapshot["workspaces"]] == [
    False, True, False, False,
]
assert snapshot["workspaces"][0]["urgent"] is True
assert snapshot["workspaces"][2]["occupied"] is True
assert snapshot["windows"][1]["focused"] is True
assert snapshot["windows"][1]["fullscreen"] is True
assert snapshot["windows"][2]["floating"] is None

capabilities = snapshot["capabilities"]
assert capabilities["workspaces"] is True
assert capabilities["windows"] is True
assert capabilities["focusWindow"] is True
assert capabilities["closeWindow"] is True
assert capabilities["moveWindowToWorkspace"] is True
assert capabilities["screens"] is False
assert capabilities["perScreenWorkspaces"] is False
assert capabilities["moveWindowToScreen"] is False
assert capabilities["layouts"] is False
assert capabilities["gaps"] is False
assert capabilities["reload"] is False
assert capabilities["sessionControl"] is False

events = run("monitor").stdout.splitlines()
assert len(events) == 2

with tempfile.TemporaryDirectory(prefix="anush-spectrwm-test.") as directory:
    log = Path(directory) / "action.json"
    environment["ANUSH_EWMH_ACTION_LOG"] = str(log)

    def action(*arguments):
        run("action", *arguments)
        return json.loads(log.read_text())

    assert action("workspace", "2") == ["xdotool", "set_desktop", "2"]
    assert action("focus", "4194306") == [
        "xdotool", "windowactivate", "--sync", "4194306",
    ]
    assert action("close", "4194306") == [
        "xdotool", "windowclose", "4194306",
    ]
    assert action("move-workspace", "4194306", "3") == [
        "xdotool", "set_desktop_for_window", "4194306", "3",
    ]

print("spectrwm backend tests passed")
