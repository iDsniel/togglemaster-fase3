import copy
import datetime as dt
import tempfile
import unittest
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path
from app import Engine, authorized


class SafetyTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.clock = 1800000000
        self.calls = []
        self.path = str(Path(self.tmp.name) / "state.sqlite")
        self.engine = Engine(self.path, True, self.calls.append, lambda: self.clock)
        self.alert = {"status": "firing", "startsAt": dt.datetime.fromtimestamp(self.clock-180, dt.timezone.utc).isoformat(), "fingerprint": "test", "labels": {"alertname": "ToggleMasterAuthHighErrorRate", "project": "togglemaster", "service": "auth-service", "self_heal": "restart-auth"}}

    def tearDown(self):
        self.tmp.cleanup()

    def send(self, alert=None):
        return self.engine.handle({"alerts": [alert or self.alert]})

    def test_concurrent_duplicates_only_restart_once(self):
        with ThreadPoolExecutor(max_workers=8) as pool:
            list(pool.map(lambda _: self.send(), range(8)))
        self.assertEqual(len(self.calls), 1)
        self.engine = Engine(self.path, True, self.calls.append, lambda: self.clock)
        self.assertEqual(self.send(), ["duplicate"])

    def test_resolved_and_wrong_targets_never_restart(self):
        for key, value in [("service", "flag-service"), ("project", "another"), ("self_heal", "arbitrary-command")]:
            alert = copy.deepcopy(self.alert); alert["labels"][key] = value
            self.assertEqual(self.send(alert), ["ignored"])
        alert = copy.deepcopy(self.alert); alert["status"] = "resolved"
        self.assertEqual(self.send(alert), ["ignored"])
        self.assertFalse(self.calls)

    def test_disabled_and_stale(self):
        self.engine.enabled = False
        self.assertEqual(self.send(), ["dry-run"])
        self.engine.enabled = True; self.clock += 901
        self.assertEqual(self.send(), ["stale"])
        self.assertFalse(self.calls)

    def test_cooldown_and_failed_attempt_budget(self):
        def fail(_): raise RuntimeError("unhealthy")
        self.engine.restart = fail
        self.assertEqual(self.send(), ["failed"])
        self.assertEqual(self.send(), ["duplicate"])
        alert = copy.deepcopy(self.alert); alert["fingerprint"] = "different"
        self.assertEqual(self.send(alert), ["cooldown"])

    def test_authentication(self):
        self.assertTrue(authorized("Bearer " + "a"*32, "a"*32))
        self.assertFalse(authorized("Bearer wrong", "a"*32))
        self.assertFalse(authorized("Bearer ", ""))


if __name__ == "__main__":
    unittest.main()
