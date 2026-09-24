#!/usr/bin/env python3
"""Non-blocking Codex hook bridge for the native whale companion."""

from __future__ import annotations

import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import time


def event_record(kind: str, payload: dict, now: float | None = None) -> dict | None:
    expected = "SessionStart" if kind == "start" else "Stop"
    if payload.get("hook_event_name") != expected:
        return None
    if kind == "start":
        return None
    session_id = payload.get("session_id")
    turn_id = payload.get("turn_id")
    if not isinstance(session_id, str) or not session_id:
        return None
    if not isinstance(turn_id, str) or not turn_id:
        return None
    return {
        "kind": "turn_complete",
        "session_id": session_id,
        "turn_id": turn_id,
        "at": now if now is not None else time.time(),
    }


def write_record(data_dir: Path, record: dict) -> None:
    data_dir.mkdir(parents=True, exist_ok=True, mode=0o700)
    destination = data_dir / "latest-event.json"
    descriptor, name = tempfile.mkstemp(prefix=".event-", suffix=".json", dir=data_dir)
    try:
        with os.fdopen(descriptor, "w", encoding="utf-8") as handle:
            json.dump(record, handle, ensure_ascii=False, separators=(",", ":"))
            handle.write("\n")
        os.chmod(name, 0o600)
        os.replace(name, destination)
    finally:
        try:
            os.unlink(name)
        except FileNotFoundError:
            pass


def launch_companion(plugin_root: Path, data_dir: Path) -> None:
    executable = plugin_root / "bin" / "deepseek-girl"
    if not executable.is_file() or not os.access(executable, os.X_OK):
        return
    subprocess.Popen(
        [str(executable), "--data-dir", str(data_dir), "--asset", str(plugin_root / "assets" / "deepseek-sticker.png")],
        cwd=plugin_root,
        stdin=subprocess.DEVNULL,
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
        start_new_session=True,
        close_fds=True,
    )


def main(argv: list[str]) -> int:
    # Stop hooks require JSON stdout. Never let an optional desktop companion
    # block or alter the agent's final response.
    try:
        if len(argv) != 2 or argv[1] not in ("start", "complete"):
            return 0
        payload = json.load(sys.stdin)
        if not isinstance(payload, dict):
            return 0
        kind = argv[1]
        expected = "SessionStart" if kind == "start" else "Stop"
        if payload.get("hook_event_name") != expected:
            return 0
        plugin_root = Path(os.environ["PLUGIN_ROOT"]).resolve()
        data_dir = Path(os.environ["PLUGIN_DATA"]).resolve()
        if kind == "complete":
            record = event_record(kind, payload)
            if record is not None:
                write_record(data_dir, record)
        launch_companion(plugin_root, data_dir)
    except (OSError, ValueError, KeyError, TypeError, json.JSONDecodeError):
        pass
    finally:
        print("{}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))
