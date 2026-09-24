import importlib.util
import json
from pathlib import Path
import tempfile
import unittest


SPEC = importlib.util.spec_from_file_location(
    "quota", Path(__file__).resolve().parents[1] / "hooks" / "quota.py"
)
quota = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(quota)


class QuotaTests(unittest.TestCase):
    def test_multi_bucket_and_missing_window(self):
        result = quota.normalize_response({
            "rateLimitsByLimitId": {
                "codex_other": {"limitName": "Other", "primary": {
                    "usedPercent": 25, "windowDurationMins": 300, "resetsAt": 1234567890,
                }},
                "codex": {"primary": {
                    "usedPercent": 96, "windowDurationMins": 10080, "resetsAt": 1790508615,
                }, "secondary": None},
            },
            "accountId": "must-not-be-stored",
        }, now=1790160000)
        self.assertEqual(result["status"], "ok")
        self.assertEqual(result["fetchedAt"], 1790160000)
        self.assertEqual([w["bucket"] for w in result["windows"]], ["codex", "codex_other"])
        self.assertNotIn("accountId", json.dumps(result))

    def test_legacy_and_invalid_values(self):
        legacy = quota.normalize_response({"rateLimits": {"primary": {
            "usedPercent": 10.5, "windowDurationMins": 300,
        }}})
        self.assertEqual(legacy["windows"][0]["usedPercent"], 10.5)
        invalid = quota.normalize_response({"rateLimits": {"primary": {
            "usedPercent": True, "windowDurationMins": 300,
        }}})
        self.assertEqual(invalid["status"], "unavailable")
        self.assertEqual(invalid["reason"], "no_windows")

    def test_private_atomic_snapshot(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            quota.write_snapshot(root, {"schema": 1, "status": "ok", "windows": []})
            file = root / "rate-limits.json"
            self.assertEqual(file.stat().st_mode & 0o777, 0o600)
            self.assertEqual(json.loads(file.read_text())["schema"], 1)


if __name__ == "__main__":
    unittest.main()
