#!/usr/bin/env python3
"""Read ChatGPT Codex rate-limit windows through the official local app-server.

Only a sanitized percentage/reset snapshot is stored. No session logs or
credentials are read by this helper directly.
"""

from __future__ import annotations

import argparse
import json
import os
from pathlib import Path
import selectors
import shutil
import subprocess
import sys
import tempfile
import time


MAX_MESSAGE_BYTES = 1_000_000
REQUEST_TIMEOUT_SECONDS = 12


def normalize_window(bucket_id: str, bucket_name: str, raw: object) -> dict | None:
    if not isinstance(raw, dict):
        return None
    used = raw.get("usedPercent")
    duration = raw.get("windowDurationMins")
    if isinstance(used, bool) or not isinstance(used, (int, float)):
        return None
    if isinstance(duration, bool) or not isinstance(duration, (int, float)):
        return None
    if not (0 <= used <= 100 and 1 <= duration <= 525_600):
        return None
    result = {
        "bucket": bucket_id[:80],
        "bucketName": bucket_name[:80],
        "durationMins": int(duration),
        "usedPercent": float(used),
    }
    reset = raw.get("resetsAt")
    if isinstance(reset, (int, float)) and not isinstance(reset, bool) and 0 < reset < 4_102_444_800:
        result["resetsAt"] = int(reset)
    return result


def normalize_response(result: object, now: float | None = None) -> dict:
    if not isinstance(result, dict):
        return {"schema": 1, "status": "unavailable", "reason": "invalid_response", "windows": []}
    buckets = result.get("rateLimitsByLimitId")
    if not isinstance(buckets, dict) or not buckets:
        legacy = result.get("rateLimits")
        buckets = {"codex": legacy} if isinstance(legacy, dict) else {}
    windows = []
    for bucket_id, bucket in sorted(buckets.items(), key=lambda pair: (pair[0] != "codex", pair[0])):
        if not isinstance(bucket_id, str) or not isinstance(bucket, dict):
            continue
        name = bucket.get("limitName")
        bucket_name = name if isinstance(name, str) and name else ("Codex" if bucket_id == "codex" else bucket_id)
        for key in ("primary", "secondary"):
            window = normalize_window(bucket_id, bucket_name, bucket.get(key))
            if window is not None:
                windows.append(window)
    if not windows:
        return {"schema": 1, "status": "unavailable", "reason": "no_windows", "windows": []}
    return {"schema": 1, "status": "ok", "fetchedAt": int(now or time.time()), "windows": windows[:12]}


def _send(process: subprocess.Popen, message: dict) -> None:
    assert process.stdin is not None
    process.stdin.write(json.dumps(message, separators=(",", ":")).encode() + b"\n")
    process.stdin.flush()


def _read_response(process: subprocess.Popen, request_id: int, deadline: float,
                   pending: bytearray) -> dict:
    assert process.stdout is not None
    with selectors.DefaultSelector() as selector:
        selector.register(process.stdout, selectors.EVENT_READ)
        while time.monotonic() < deadline:
            while b"\n" in pending:
                line, _, rest = pending.partition(b"\n")
                pending[:] = rest
                try:
                    message = json.loads(line)
                except (ValueError, UnicodeDecodeError):
                    continue
                if isinstance(message, dict) and message.get("id") == request_id:
                    return message
            ready = selector.select(max(0, deadline - time.monotonic()))
            if not ready:
                break
            chunk = os.read(process.stdout.fileno(), 65_536)
            if not chunk:
                break
            pending.extend(chunk)
            if len(pending) > MAX_MESSAGE_BYTES:
                raise ValueError("App Server response too large")
    raise TimeoutError("App Server did not respond")


def read_rate_limits(codex: str, timeout: float = REQUEST_TIMEOUT_SECONDS) -> dict:
    process = subprocess.Popen(
        [codex, "app-server", "--stdio"],
        stdin=subprocess.PIPE,
        stdout=subprocess.PIPE,
        stderr=subprocess.DEVNULL,
        close_fds=True,
    )
    pending = bytearray()
    deadline = time.monotonic() + timeout
    try:
        _send(process, {
            "method": "initialize", "id": 1,
            "params": {"clientInfo": {
                "name": "deepseek_girl", "title": "DeepSeek Girl", "version": "0.1.0"
            }},
        })
        initialized = _read_response(process, 1, deadline, pending)
        if "error" in initialized:
            raise ValueError("App Server initialization failed")
        _send(process, {"method": "initialized", "params": {}})
        _send(process, {"method": "account/rateLimits/read", "id": 2})
        reply = _read_response(process, 2, deadline, pending)
        if "error" in reply:
            return {"schema": 1, "status": "unavailable", "reason": "account_unavailable", "windows": []}
        return normalize_response(reply.get("result"))
    finally:
        if process.poll() is None:
            process.terminate()
        try:
            process.communicate(timeout=1)
        except subprocess.TimeoutExpired:
            process.kill()
            process.communicate(timeout=1)


def write_snapshot(data_dir: Path, snapshot: dict) -> None:
    data_dir.mkdir(parents=True, exist_ok=True, mode=0o700)
    destination = data_dir / "rate-limits.json"
    descriptor, temporary = tempfile.mkstemp(prefix=".rate-limits-", suffix=".json", dir=data_dir)
    try:
        with os.fdopen(descriptor, "w", encoding="utf-8") as handle:
            json.dump(snapshot, handle, ensure_ascii=False, separators=(",", ":"))
            handle.write("\n")
        os.chmod(temporary, 0o600)
        os.replace(temporary, destination)
    finally:
        try:
            os.unlink(temporary)
        except FileNotFoundError:
            pass


def main(argv: list[str]) -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--data-dir", required=True)
    parser.add_argument("--codex", default=None)
    args = parser.parse_args(argv)
    codex = args.codex or shutil.which("codex")
    if not codex:
        snapshot = {"schema": 1, "status": "unavailable", "reason": "codex_not_found", "windows": []}
    else:
        try:
            snapshot = read_rate_limits(codex)
        except (OSError, ValueError, TimeoutError, subprocess.SubprocessError):
            snapshot = {"schema": 1, "status": "unavailable", "reason": "request_failed", "windows": []}
    write_snapshot(Path(args.data_dir), snapshot)
    return 0 if snapshot["status"] == "ok" else 1


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
