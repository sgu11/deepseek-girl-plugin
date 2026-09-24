import importlib.util
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch


SCRIPT = Path(__file__).resolve().parents[1] / "hooks" / "event.py"
SPEC = importlib.util.spec_from_file_location("deepseek_girl_event", SCRIPT)
MODULE = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(MODULE)


class EventTests(unittest.TestCase):
    def test_stop_becomes_turn_complete(self):
        self.assertEqual(
            MODULE.event_record(
                "complete",
                {"hook_event_name": "Stop", "session_id": "session", "turn_id": "turn"},
                now=123.0,
            ),
            {"kind": "turn_complete", "session_id": "session", "turn_id": "turn", "at": 123.0},
        )

    def test_unrelated_or_incomplete_payload_is_ignored(self):
        self.assertIsNone(MODULE.event_record("complete", {"hook_event_name": "SessionStart"}))
        self.assertIsNone(MODULE.event_record("complete", {"hook_event_name": "Stop", "turn_id": "turn"}))
        self.assertIsNone(MODULE.event_record("start", {"hook_event_name": "SessionStart"}))

    def test_atomic_record_is_private(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            MODULE.write_record(root, {"kind": "turn_complete", "turn_id": "one"})
            self.assertEqual((root / "latest-event.json").read_text(encoding="utf-8"),
                             '{"kind":"turn_complete","turn_id":"one"}\n')
            self.assertEqual((root / "latest-event.json").stat().st_mode & 0o777, 0o600)
            self.assertEqual(list(root.glob(".event-*")), [])

    def test_companion_starts_in_plugin_root(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            executable = root / "bin" / "deepseek-girl"
            executable.parent.mkdir()
            executable.touch(mode=0o700)
            with patch.object(MODULE.subprocess, "Popen") as launch:
                MODULE.launch_companion(root, root / "data")
            self.assertEqual(launch.call_args.kwargs["cwd"], root)
            self.assertEqual(launch.call_args.args[0][-1],
                             str(root / "assets" / "deepseek-sticker.png"))


if __name__ == "__main__":
    unittest.main()
