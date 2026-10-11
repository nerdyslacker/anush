#!/usr/bin/env python3

import json
import os
from pathlib import Path
import socket
import struct
import subprocess
import tempfile
import threading


ROOT = Path(__file__).resolve().parents[1]
PROVIDER = ROOT / "shell/scripts/wm/i3-provider"
FIXTURE = ROOT / "tests/fixtures/i3"
MAGIC = b"i3-ipc"


def receive_exact(connection, size):
    result = b""
    while len(result) < size:
        chunk = connection.recv(size - len(result))
        if not chunk:
            raise RuntimeError("connection closed")
        result += chunk
    return result


def receive_message(connection):
    header = receive_exact(connection, len(MAGIC) + 8)
    assert header[:len(MAGIC)] == MAGIC
    length, message_type = struct.unpack("=II", header[len(MAGIC):])
    return message_type, receive_exact(connection, length).decode()


def send_message(connection, message_type, payload):
    encoded = json.dumps(payload).encode()
    connection.sendall(
        MAGIC + struct.pack("=II", len(encoded), message_type) + encoded
    )


def serve(socket_path, handler):
    errors = []
    server = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
    server.bind(str(socket_path))
    server.listen(1)

    def target():
        try:
            connection, _ = server.accept()
            with connection:
                handler(connection)
        except Exception as error:
            errors.append(error)
        finally:
            server.close()

    thread = threading.Thread(target=target)
    thread.start()
    return thread, errors

environment = os.environ.copy()
environment["ANUSH_I3_FIXTURE_DIR"] = str(FIXTURE)
result = subprocess.run(
    [str(PROVIDER), "snapshot"], env=environment, check=True,
    capture_output=True, text=True,
)
snapshot = json.loads(result.stdout)

assert snapshot["connected"] is True
assert [screen["id"] for screen in snapshot["screens"]] == ["DP-1", "HDMI-1"]
assert [screen["focused"] for screen in snapshot["screens"]] == [False, True]
assert snapshot["screens"][0]["workarea"] == {
    "x": 0, "y": 28, "width": 1920, "height": 1052,
}
assert [workspace["index"] for workspace in snapshot["workspaces"]] == [0, 1, 0, 1]
assert [workspace["visible"] for workspace in snapshot["workspaces"]] == [
    True, False, True, False,
]
assert snapshot["workspaces"][0]["urgent"] is True
assert snapshot["workspaces"][2]["focused"] is True
assert snapshot["workspaces"][3]["occupied"] is False
assert len(snapshot["windows"]) == 4
assert all(window["class"] != "Panel" for window in snapshot["windows"])
assert snapshot["windows"][1]["fullscreen"] is True
assert snapshot["windows"][2]["focused"] is True
assert snapshot["windows"][2]["floating"] is True
assert snapshot["windows"][3]["scratchpad"] is True
assert snapshot["windows"][3]["workspaceId"] is None
assert snapshot["capabilities"]["perScreenWorkspaces"] is True
assert snapshot["capabilities"]["scratchpad"] is True

events = subprocess.run(
    [str(PROVIDER), "monitor"], env=environment, check=True,
    capture_output=True, text=True,
).stdout.splitlines()
assert [json.loads(line)["event"] for line in events] == ["window", "shutdown"]

with tempfile.TemporaryDirectory(prefix="anush-i3-test.") as directory:
    log = Path(directory) / "action.log"
    environment["ANUSH_I3_ACTION_LOG"] = str(log)

    def action(*arguments):
        subprocess.run(
            [str(PROVIDER), "action", *arguments], env=environment, check=True,
            capture_output=True, text=True,
        )
        return log.read_text()

    assert action("workspace", '2: "web"', "HDMI-1") == \
        'focus output "HDMI-1"; workspace --no-auto-back-and-forth "2: \\"web\\""'
    assert action("focus", "103") == '[con_id="103"] focus'
    assert action("move-workspace", "101", "2: web") == \
        '[con_id="101"] move container to workspace "2: web"'
    assert action("move-screen", "101", "HDMI-1") == \
        '[con_id="101"] move container to output "HDMI-1"'
    assert action("toggle-scratchpad", "104") == \
        '[con_id="104"] scratchpad show'

with tempfile.TemporaryDirectory(prefix="anush-i3-ipc.") as directory:
    socket_path = Path(directory) / "ipc.sock"
    raw = {
        name: json.loads((FIXTURE / f"{name}.json").read_text())
        for name in ("outputs", "workspaces", "tree")
    }

    def snapshot_server(connection):
        for message_type, name in ((3, "outputs"), (1, "workspaces"), (4, "tree")):
            received_type, payload = receive_message(connection)
            assert received_type == message_type
            assert payload == ""
            send_message(connection, message_type, raw[name])

    thread, errors = serve(socket_path, snapshot_server)
    ipc_environment = os.environ.copy()
    ipc_environment.pop("ANUSH_I3_FIXTURE_DIR", None)
    ipc_environment["I3SOCK"] = str(socket_path)
    result = subprocess.run(
        [str(PROVIDER), "snapshot"], env=ipc_environment, check=True,
        capture_output=True, text=True,
    )
    thread.join(timeout=5)
    assert not thread.is_alive()
    assert not errors
    assert json.loads(result.stdout)["windows"][2]["focused"] is True

with tempfile.TemporaryDirectory(prefix="anush-i3-events.") as directory:
    socket_path = Path(directory) / "ipc.sock"

    def event_server(connection):
        message_type, payload = receive_message(connection)
        assert message_type == 2
        assert json.loads(payload) == ["workspace", "output", "window", "shutdown"]
        send_message(connection, message_type, {"success": True})
        send_message(connection, (1 << 31) | 3, {"change": "focus"})
        send_message(connection, (1 << 31) | 6, {"change": "restart"})

    thread, errors = serve(socket_path, event_server)
    ipc_environment["I3SOCK"] = str(socket_path)
    result = subprocess.run(
        [str(PROVIDER), "monitor"], env=ipc_environment, check=True,
        capture_output=True, text=True,
    )
    thread.join(timeout=5)
    assert not thread.is_alive()
    assert not errors
    events = [json.loads(line)["event"] for line in result.stdout.splitlines()]
    assert events == ["window", "shutdown"]

print("i3 provider tests passed")
