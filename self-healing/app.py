"""Authenticated, single-target Grafana webhook. Disabled unless explicitly enabled.

SQLite persists the one-attempt-per-incident budget across process restarts.
Only a deployment template annotation can be patched; no command execution.
"""
import datetime as dt
import hashlib
import hmac
import json
import logging
import os
from pathlib import Path
import sqlite3
import ssl
import threading
import time
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from urllib.request import Request, urlopen

LOG = logging.getLogger("self-healer")
TARGET = "/apis/apps/v1/namespaces/togglemaster/deployments/auth-service"


class Kubernetes:
    def __init__(self):
        self.base = "https://kubernetes.default.svc"
        self.directory = Path("/var/run/secrets/kubernetes.io/serviceaccount")
        self.ssl = ssl.create_default_context(cafile=str(self.directory / "ca.crt"))

    def call(self, method, body=None):
        headers = {"Authorization": "Bearer " + (self.directory / "token").read_text()}
        headers["Content-Type"] = "application/strategic-merge-patch+json"
        data = None if body is None else json.dumps(body).encode()
        with urlopen(Request(self.base + TARGET, data=data, headers=headers, method=method), context=self.ssl, timeout=10) as response:
            return json.load(response)

    def restart(self, incident):
        current = self.call("GET")
        if current["metadata"].get("annotations", {}).get("togglemaster.io/self-heal") != "enabled":
            raise ValueError("deployment has not opted in")
        if current["spec"].get("replicas", 1) < 1:
            raise ValueError("deployment is scaled to zero")
        status = current.get("status", {})
        if status.get("observedGeneration", 0) < current["metadata"].get("generation", 1):
            raise ValueError("a rollout is already pending")
        if status.get("updatedReplicas", 0) != current["spec"].get("replicas", 1):
            raise ValueError("a rollout is already in progress")
        updated = self.call("PATCH", {
            "metadata": {"resourceVersion": current["metadata"]["resourceVersion"]},
            "spec": {"template": {"metadata": {"annotations": {"togglemaster.io/recovery-id": incident}}}},
        })
        generation = updated["metadata"]["generation"]
        deadline = time.monotonic() + 180
        while time.monotonic() < deadline:
            obj = self.call("GET")
            state = obj.get("status", {})
            desired = obj["spec"].get("replicas", 1)
            if obj["metadata"].get("generation") != generation:
                raise RuntimeError("concurrent deployment change; manual review required")
            if (state.get("observedGeneration", 0) >= generation
                    and state.get("updatedReplicas", 0) == desired
                    and state.get("availableReplicas", 0) == desired
                    and state.get("replicas", 0) == desired):
                return
            time.sleep(5)
        raise TimeoutError("rollout not healthy after 180 seconds")


class Engine:
    def __init__(self, database, enabled=False, restart=None, now=time.time):
        self.database, self.enabled, self.restart, self.now = database, enabled, restart, now
        self.lock = threading.Lock()
        with sqlite3.connect(database) as db:
            db.execute("CREATE TABLE IF NOT EXISTS attempts (incident TEXT PRIMARY KEY, created REAL, result TEXT)")

    def handle(self, payload):
        results = []
        for alert in payload.get("alerts", []):
            labels = alert.get("labels", {})
            if (alert.get("status") != "firing" or labels.get("alertname") != "ToggleMasterAuthHighErrorRate"
                    or labels.get("project") != "togglemaster" or labels.get("service") != "auth-service"
                    or labels.get("self_heal") != "restart-auth"):
                results.append("ignored")
                continue
            try:
                start = dt.datetime.fromisoformat(alert["startsAt"].replace("Z", "+00:00")).timestamp()
            except (KeyError, ValueError, TypeError):
                results.append("invalid-time")
                continue
            age = self.now() - start
            if age < -60 or age > 900:
                results.append("stale")
                continue
            incident = hashlib.sha256((str(alert.get("fingerprint", "")) + alert["startsAt"] + "auth-service").encode()).hexdigest()
            if not self.enabled:
                LOG.info(json.dumps({"event": "dry-run", "incident": incident, "target": "auth-service"}))
                results.append("dry-run")
                continue
            with self.lock, sqlite3.connect(self.database, timeout=10) as db:
                db.execute("BEGIN IMMEDIATE")
                if db.execute("SELECT 1 FROM attempts WHERE incident=?", (incident,)).fetchone():
                    results.append("duplicate")
                    continue
                recent = db.execute("SELECT MAX(created) FROM attempts").fetchone()[0]
                if recent is not None and self.now() - recent < 900:
                    results.append("cooldown")
                    continue
                db.execute("INSERT INTO attempts VALUES (?, ?, ?)", (incident, self.now(), "reserved"))
                db.commit()  # Reserve before side effects; a crash must not cause a second restart.
            try:
                self.restart(incident)
                result = "recovered"
            except Exception as error:
                result = "failed"
                LOG.error(json.dumps({"event": result, "incident": incident, "reason": type(error).__name__}))
            with sqlite3.connect(self.database) as db:
                db.execute("UPDATE attempts SET result=? WHERE incident=?", (result, incident))
            LOG.info(json.dumps({"event": result, "incident": incident, "target": "auth-service"}))
            results.append(result)
        return results


def authorized(header, secret):
    return bool(secret) and hmac.compare_digest(header, "Bearer " + secret)


def main():
    logging.basicConfig(level=logging.INFO, format="%(message)s")
    token = os.environ["HEALER_TOKEN"]
    if len(token) < 32:
        raise ValueError("HEALER_TOKEN must have at least 32 characters")
    enabled = os.getenv("HEALING_ENABLED", "false") == "true"
    engine = Engine(os.getenv("STATE_DB", "/state/attempts.sqlite"), enabled, Kubernetes().restart if enabled else None)

    class Handler(BaseHTTPRequestHandler):
        def log_message(self, *args):
            pass  # Never log authorization or webhook bodies.

        def do_GET(self):
            self.send_response(200 if self.path == "/health" else 404)
            self.end_headers()

        def do_POST(self):
            if self.path != "/alert":
                self.send_error(404)
                return
            if not authorized(self.headers.get("Authorization", ""), token):
                self.send_error(401)
                return
            try:
                length = int(self.headers.get("Content-Length", "0"))
                if not 0 < length <= 65536:
                    raise ValueError("size")
                payload = json.loads(self.rfile.read(length))
                if not isinstance(payload, dict) or not isinstance(payload.get("alerts"), list) or len(payload["alerts"]) > 20:
                    raise ValueError("shape")
                if any(not isinstance(a, dict) or not isinstance(a.get("labels", {}), dict) for a in payload["alerts"]):
                    raise ValueError("alert shape")
            except (ValueError, TypeError):
                self.send_error(400)
                return
            # Work runs asynchronously; duplicate deliveries are protected by the durable ledger.
            threading.Thread(target=engine.handle, args=(payload,), daemon=True).start()
            self.send_response(202)
            self.end_headers()

    ThreadingHTTPServer(("0.0.0.0", 8080), Handler).serve_forever()


if __name__ == "__main__":
    main()
