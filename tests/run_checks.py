#!/usr/bin/env python3
"""Isolate Godot userdata and test real scene/SDK behavior against loopback fakes."""
from __future__ import annotations
import base64
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import threading
import time
import uuid
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from urllib.parse import urlparse

ROOT = Path(__file__).resolve().parents[1]
QA = ROOT / "tmp" / "qa-project"
GODOT = os.environ.get("GODOT_BIN", "/Applications/Godot.app/Contents/MacOS/Godot")
REQUESTS: list[dict] = []
QA_RUN_ID = uuid.uuid4().hex[:12]
QA_DATA_NAME = f"horizon-task913-godot-qa-{QA_RUN_ID}"

class Fixture(BaseHTTPRequestHandler):
    def log_message(self, *_):
        pass

    def do_GET(self):
        self.handle_fixture()

    def do_POST(self):
        self.handle_fixture()

    def do_PUT(self):
        self.handle_fixture()

    def handle_fixture(self):
        path = urlparse(self.path).path
        raw = self.rfile.read(int(self.headers.get("Content-Length", "0")))
        body = json.loads(raw) if raw else {}
        REQUESTS.append({"method": self.command, "path": self.path, "body": body,
                         "auth": self.headers.get("Authorization", "")})
        status = 200
        result: object = {"success": True}
        if path.endswith("user-management/signin"):
            email = body.get("email", "qa@example.invalid")
            if email == "slow-player@example.invalid":
                time.sleep(0.25)
            user_id = email.split("@")[0] if email != "qa@example.invalid" else "qa-player"
            result = {"userId": user_id, "displayName": "QA Seagull", "email": email, "accessToken": "synthetic-player-session", "type": "EMAIL", "authStatus": "AUTHENTICATED"}
        elif path.endswith("cloud-save/load"):
            if body.get("userId") == "slow-player":
                time.sleep(0.3)
            result = {"found": True, "saveData": json.dumps({"coins": 77, "highscore": 120})}
        elif path.endswith("cloud-save/save"):
            time.sleep(0.15)
            result = {"success": True}
        elif path.endswith("validated-actions/runs"):
            if body.get("leaderboardKey") == "delayed":
                time.sleep(0.25)
            if body.get("leaderboardKey") == "no-ticket":
                time.sleep(0.25)
                status = 404
                result = {"code": "NOT_SUPPORTED", "message": "Synthetic unavailable ticket"}
            else:
                result = {"runId": "synthetic-run", "ticket": "synthetic-ticket", "seed": 42,
                      "leaderboardKey": body.get("leaderboardKey", "storm"), "expiresInSeconds": 300}
        elif path.endswith("validated-actions/submit"):
            if body.get("leaderboardKey") == "reject":
                status, result = 422, {"code": "DURATION_TOO_SHORT", "message": "Synthetic rejection"}
            else:
                result = {"accepted": True, "runId": "synthetic-run", "leaderboardKey": "storm", "rank": 2,
                          "score": 100, "bestScore": 120, "evidence": {"required": True,
                          "runId": "synthetic-run", "maxBytes": 1 if body.get("leaderboardKey") == "tiny-evidence" else 32768, "uploadBefore": "2099-01-01T00:00:00Z"}}
        elif path.endswith("/evidence"):
            assert base64.b64decode(body["log"]), "Evidence payload must contain recorder bytes"
        elif path.endswith("validated-actions/state"):
            result = {"userId": "qa-player", "day": "2026-10-02", "values": [{"key": "pearls", "balance": 5}]}
        elif path.endswith("/leaderboards"):
            result = {"boards": [{"key": "storm", "name": "Storm", "validatedOnly": False},
                                  {"key": "validated", "name": "Validated", "validatedOnly": True}]}
        elif "/leaderboards/" in path:
            entry = {"position": 2, "username": "QA Seagull", "score": 120}
            if path.endswith("/rank"):
                result = entry
            elif path.endswith("/submit") and "/validated/" in path:
                status, result = 403, {"code": "VALIDATED_SUBMIT_REQUIRED", "message": "Use validated actions"}
            else:
                result = {"entries": [entry]}
        elif path.endswith("/news"):
            result = [{"title": "QA news", "message": "Fixture news", "releaseDate": "2026-10-02"}]
        elif path.endswith("/player-profile"):
            result = {"userId": "qa-player", "profile": {"avatarId": "seagull", "badges": []},
                      "cosmetics": [{"id": "seagull", "type": "avatar", "available": True, "locked": False}]}
        elif path.endswith("remote-config/all"):
            time.sleep(0.2)
            result = {"configs": {"run_duration_seconds": "180"}, "total": 1}
        elif "/localization/all" in path:
            result = {"translations": {"seagull.play": "Fixture spielen"}, "total": 1}
        elif path.endswith("gift-codes/validate"):
            result = {"valid": True}
        elif path.endswith("gift-codes/redeem"):
            result = {"success": True, "giftData": '{"coins":10}', "grantedUnlocks": ["seagull"]}
        elif path.endswith("user-logs/create"):
            result = {"id": "qa-log", "createdAt": "2026-10-02T00:00:00Z"}
        elif path.endswith("crash-reports/session"):
            result = {"success": True, "sessionId": "qa-session"}
        elif path.endswith("email-sending/send"):
            result = {"id": "synthetic-email", "status": "QUEUED"}
        elif path.endswith("email-sending/synthetic-email"):
            result = {"id": "synthetic-email", "status": "QUEUED"}
        data = json.dumps(result).encode()
        self.send_response(status)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(data)))
        self.end_headers()
        self.wfile.write(data)

def run(*args, env=None):
    completed = subprocess.run([GODOT, "--path", str(QA), *args], capture_output=True, text=True, env=env, timeout=50)
    output = completed.stdout + completed.stderr
    log = ROOT / "tmp" / ("check-" + ("import" if "--import" in args else Path(args[-1]).stem) + ".log")
    log.write_text(output)
    print(log.name, "exit", completed.returncode, flush=True)
    if completed.returncode or "SCRIPT ERROR" in output or "resources still in use" in output:
        print(output[-8000:])
        raise SystemExit(1)
    return output

def main():
    if QA.exists():
        shutil.rmtree(QA)
    shutil.copytree(ROOT, QA, ignore=shutil.ignore_patterns(".git", ".godot", "tmp", "exports", "horizon_config.tres"), ignore_dangling_symlinks=True)
    project = QA / "project.godot"
    text = project.read_text().replace('config/name="Seagull Storm"',
        f'config/name="Seagull Storm QA"\nconfig/use_custom_user_dir=true\nconfig/custom_user_dir_name="{QA_DATA_NAME}"')
    project.write_text(text)
    run("--headless", "--editor", "--import", "--quit")
    if "--render" in sys.argv:
        captures = run("--script", "tests/render_layout.gd")
        assert "NATIVE_LAYOUT_CAPTURE_PASS" in captures
        for capture in (QA / "tmp").glob("qa-*.png"):
            shutil.copy2(capture, ROOT / "tmp" / capture.name)
        print("LAYOUT_CHECKS_PASS: native renderer captures use isolated QA userdata.")
        return
    offline = run("--headless", "--verbose", "--script", "tests/offline_smoke.gd")
    assert "OFFLINE_SMOKE_PASS" in offline
    with ThreadingHTTPServer(("127.0.0.1", 0), Fixture) as server:
        thread = threading.Thread(target=server.serve_forever, daemon=True)
        thread.start()
        env = os.environ.copy()
        env["SEAGULL_FIXTURE_URL"] = f"http://127.0.0.1:{server.server_port}"
        sdk = run("--headless", "--script", "tests/sdk_fixture_smoke.gd", env=env)
        server.shutdown()
    assert "SDK_FIXTURE_SMOKE_PASS" in sdk
    protected = [r for r in REQUESTS if any(part in r["path"] for part in
                 ["cloud-save", "validated-actions", "player-profile", "gift-codes/redeem"])]
    assert protected and all(r["auth"] == "Bearer synthetic-player-session" for r in protected)
    assert any("/storm/around?" in r["path"] and "range=5" in r["path"] for r in REQUESTS)
    assert not any(r["path"].endswith("/reject/submit") for r in REQUESTS)
    assert not any("/storm/submit" in r["path"] for r in REQUESTS), "No failed validated request may become an ordinary score"
    saves = [json.loads(r["body"]["saveData"])["coins"] for r in REQUESTS if r["path"].endswith("cloud-save/save")]
    assert saves == [77, 67, 42], f"Full cloud snapshots arrive in order and no failed-ticket rewards leak: {saves}"
    print(f"ALL_CHECKS_PASS: offline gameplay and {len(REQUESTS)} real SDK loopback requests; authenticated protected routes; rejected validation never falls back.")

if __name__ == "__main__":
    try:
        main()
    finally:
        # Remove only this invocation's exact custom userdata directory. Keep
        # logs/captures and the isolated project for export verification.
        if sys.platform == "darwin":
            data_base = Path.home() / "Library/Application Support"
        elif sys.platform == "win32":
            data_base = Path(os.environ["APPDATA"])
        else:
            data_base = Path(os.environ.get("XDG_DATA_HOME", str(Path.home() / ".local/share")))
        userdata = data_base / QA_DATA_NAME
        if userdata.exists():
            shutil.rmtree(userdata)
