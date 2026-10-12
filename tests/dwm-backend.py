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
EWMH_PROVIDER = ROOT / "shell/scripts/wm/ewmh-provider"
PROVIDER = ROOT / "shell/scripts/wm/dwm-provider"
FIXTURE = ROOT / "tests/fixtures/ewmh-dwm"
MAGIC = b"DWM-IPC"


def receive_exact(connection, size):
    result = b""
    while len(result) < size:
        chunk = connection.recv(size - len(result))
        if not chunk:
            raise RuntimeError("connection closed")
        result += chunk
    return result


def receive_message(connection):
    header = receive_exact(connection, len(MAGIC) + 5)
    assert header[:len(MAGIC)] == MAGIC
    length, message_type = struct.unpack("=IB", header[len(MAGIC):])
    payload = receive_exact(connection, length).rstrip(b"\0")
    return message_type, json.loads(payload) if payload else None


def send_message(connection, message_type, payload):
    encoded = json.dumps(payload).encode()
    connection.sendall(
        MAGIC + struct.pack("=IB", len(encoded), message_type) + encoded
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
environment["ANUSH_EWMH_FIXTURE_DIR"] = str(FIXTURE)


def run(command, *arguments, provider=PROVIDER):
    return subprocess.run(
        [str(provider), command, *arguments], env=environment, check=True,
        capture_output=True, text=True,
    )


identity = json.loads(run("detect", provider=EWMH_PROVIDER).stdout)
assert identity["identity"] == "dwm"

environment["ANUSH_DWM_IPC_SOCKET"] = "/tmp/anush-dwm-missing.sock"
snapshot = json.loads(run("snapshot").stdout)
assert snapshot["connected"] is True
assert snapshot["wmName"] == "dwm"
assert snapshot["wmIdentity"] == "dwm"
assert snapshot["integration"] == "stock"
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

environment["ANUSH_DWM_IPC_FIXTURE_DIR"] = str(
    ROOT / "tests/fixtures/dwm-ipc"
)
environment["ANUSH_EWMH_FIXTURE_DIR"] = str(
    ROOT / "tests/fixtures/dwm-ipc-ewmh"
)
snapshot = json.loads(run("snapshot").stdout)
assert snapshot["integration"] == "dwm-ipc"
assert [screen["id"] for screen in snapshot["screens"]] == ["0", "1"]
assert [screen["focused"] for screen in snapshot["screens"]] == [True, False]
assert snapshot["screens"][0]["workarea"] == {
    "x": 0, "y": 28, "width": 1920, "height": 1052,
}

workspaces = snapshot["workspaces"]
assert len(workspaces) == 6
assert [workspace["id"] for workspace in workspaces] == [
    "0:1", "0:2", "0:4", "1:1", "1:2", "1:4",
]
assert [workspace["visible"] for workspace in workspaces] == [
    True, True, False, False, True, False,
]
assert [workspace["focused"] for workspace in workspaces] == [
    True, True, False, False, False, False,
]
assert workspaces[2]["urgent"] is True
assert workspaces[4]["occupied"] is True

windows = snapshot["windows"]
assert len(windows) == 3
assert windows[0]["class"] == "kitty"
assert windows[0]["focused"] is True
assert windows[0]["workspaceId"] == "0:1"
assert windows[1]["workspaceId"] is None
assert windows[1]["floating"] is True
assert windows[1]["urgent"] is True
assert windows[2]["workspaceId"] == "1:2"
assert windows[2]["focused"] is False
assert windows[2]["fullscreen"] is True

capabilities = snapshot["capabilities"]
assert capabilities["screens"] is True
assert capabilities["perScreenWorkspaces"] is True
assert capabilities["workspaces"] is True
assert capabilities["windows"] is True
assert capabilities["focusWindow"] is False
assert capabilities["closeWindow"] is False
assert capabilities["moveWindowToWorkspace"] is False
assert capabilities["moveWindowToScreen"] is False

events = [json.loads(line) for line in run("monitor").stdout.splitlines()]
assert list(events[0]) == ["tag_change_event"]
assert list(events[1]) == ["client_focus_change_event"]

with tempfile.TemporaryDirectory(prefix="anush-dwm-ipc.") as directory:
    socket_path = Path(directory) / "dwm.sock"
    fixture = ROOT / "tests/fixtures/dwm-ipc"
    monitors = json.loads((fixture / "monitors.json").read_text())
    tags = json.loads((fixture / "tags.json").read_text())
    clients = json.loads((fixture / "clients.json").read_text())
    clients_by_id = {client["window_id"]: client for client in clients}

    def ipc_server(connection):
        message_type, payload = receive_message(connection)
        assert message_type == 1 and payload is None
        send_message(connection, message_type, monitors)
        message_type, payload = receive_message(connection)
        assert message_type == 2 and payload is None
        send_message(connection, message_type, tags)
        for window_id in (101, 102, 103):
            message_type, payload = receive_message(connection)
            assert message_type == 4
            assert payload == {"client_window_id": window_id}
            send_message(connection, message_type, clients_by_id[window_id])

    thread, errors = serve(socket_path, ipc_server)
    environment.pop("ANUSH_DWM_IPC_FIXTURE_DIR", None)
    environment["ANUSH_DWM_IPC_SOCKET"] = str(socket_path)
    snapshot = json.loads(run("snapshot").stdout)
    thread.join(timeout=5)
    assert not thread.is_alive()
    assert not errors
    assert snapshot["integration"] == "dwm-ipc"
    assert len(snapshot["screens"]) == 2

print("stock and IPC-patched dwm backend tests passed")
