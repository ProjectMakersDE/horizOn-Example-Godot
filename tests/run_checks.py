#!/usr/bin/env python3
"""Isolate Godot userdata and test real scene/SDK behavior against loopback fakes."""
from __future__ import annotations
import base64
from datetime import datetime, timezone
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
VALUE_PURCHASES = 0
VALUE_BALANCE = 100
VALUE_REVISION = 1
VALUE_OFFERS = 0
VALUE_ADJUSTS = 0
STATISTICS_POSTS = 0
STATISTICS_REVISION = 0
STATISTICS_VALUES = {"rounds": 0, "kills": 0, "best_score": 0}
STATISTICS_RECEIPTS: dict = {}
GIFT_COUNT = 9007199254740993
GIFT_REDEEMS = 0
GIFT_ORIGINALS: dict = {}
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
        global VALUE_PURCHASES, VALUE_BALANCE, VALUE_REVISION, VALUE_OFFERS, VALUE_ADJUSTS, STATISTICS_POSTS, STATISTICS_REVISION, GIFT_COUNT, GIFT_REDEEMS
        path = urlparse(self.path).path
        raw = self.rfile.read(int(self.headers.get("Content-Length", "0")))
        body = json.loads(raw) if raw else {}
        REQUESTS.append({"method": self.command, "path": self.path, "body": body,
                         "auth": self.headers.get("Authorization", "")})
        status = 200
        result: object = {"success": True}
        if "/app/statistics" in path:
            definitions = [{"key": key, "name": key, "mode": "max" if key == "best_score" else "sum", "reset": "none"} for key in STATISTICS_VALUES]
            replayed = False
            if self.command == "POST":
                STATISTICS_POSTS += 1
                operation = body["operationId"]
                replayed = operation in STATISTICS_RECEIPTS
                if replayed:
                    assert STATISTICS_RECEIPTS[operation] == body["updates"], "Original batch cannot change"
                else:
                    STATISTICS_RECEIPTS[operation] = body["updates"]
                    for update in body["updates"]:
                        key, value = update["key"], update["value"]
                        STATISTICS_VALUES[key] = max(STATISTICS_VALUES[key], value) if key == "best_score" else STATISTICS_VALUES[key] + value
                    STATISTICS_REVISION += 1
                if STATISTICS_POSTS <= 2:
                    status, result = 503, {"code": "UNAVAILABLE", "message": "Synthetic response lost after booking"}
            if status == 200:
                result = {"userId": "qa-player", "revision": STATISTICS_REVISION, "definitionVersion": 1, "definitions": definitions,
                          "values": [{"key": key, "value": value, "hasValue": STATISTICS_REVISION > 0, "period": "all"} for key, value in STATISTICS_VALUES.items()],
                          "operationWindow": {"serverTimeUnixMillis": int(time.time() * 1000), "maxAgeSeconds": 86400, "maxFutureSkewSeconds": 30},
                          "newlyUnlocked": [], "replayed": replayed}
                if self.command == "POST": result["operationId"] = body["operationId"]
        elif "/app/player-values" in path:
            now = datetime.now(timezone.utc).isoformat(timespec="milliseconds").replace("+00:00", "Z")
            if path.endswith("/purchase"):
                VALUE_PURCHASES += 1
                if VALUE_PURCHASES <= 2:
                    status = 503
                    result = {"code": "UNAVAILABLE", "message": "Synthetic lost response"}
                else:
                    VALUE_BALANCE = 90
                    VALUE_REVISION = 2
            elif path.endswith("/adjust"):
                VALUE_ADJUSTS += 1
                if VALUE_ADJUSTS == 1:
                    VALUE_BALANCE = 91
                    VALUE_REVISION = 3
                elif VALUE_ADJUSTS == 5:
                    status = 503
                    result = {"code": "UNAVAILABLE", "message": "Synthetic uncertain first attempt"}
            values = [{"key": "gold", "balance": VALUE_BALANCE, "earnedToday": 1, "dailyCap": 1000}, {"key": "gem", "balance": 1 if VALUE_PURCHASES else 0, "earnedToday": 1 if VALUE_PURCHASES else 0, "dailyCap": 1000}]
            if status == 200:
                if path.endswith("/offers"):
                    VALUE_OFFERS += 1
                    result = {"definitionVersion": 1, "serverTime": now, "definitions": values, "offers": [{"key": "pack", "name": "Pearl pack", "active": True, "costs": [{"key": "gold", "amount": 10 if VALUE_OFFERS == 1 else 11}], "rewards": [{"key": "gem", "amount": 1}], "purchasesPerDay": 5}]}
                else:
                    result = {"userId": "qa-player", "definitionVersion": 1, "revision": VALUE_REVISION, "day": "2026-10-16", "values": values, "operationWindow": {"serverTime": now, "oldestAcceptedAt": "2026-09-16T00:00:00Z"}}
                    if path.endswith("/adjust") and VALUE_ADJUSTS > 1:
                        status = 422
                        result = {"code": "OPERATION_EXPIRED" if VALUE_ADJUSTS == 3 else "ADJUST_NOT_ALLOWED", "message": "Synthetic no-write refusal", "state": result}
        elif path.endswith("user-management/signin"):
            if body.get("anonymousToken") == "restore-fails":
                data = json.dumps({"code": "UNAVAILABLE", "message": "Synthetic transient restore failure"}).encode()
                self.send_response(503)
                self.send_header("Content-Type", "application/json")
                self.send_header("Content-Length", str(len(data)))
                self.end_headers()
                self.wfile.write(data)
                return
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
            if body.get("includeIntent"):
                assert body.get("userId") == "qa-player"
                if body.get("code") == "QA-MIGRATION":
                    status, result = 409, {"code": "MIGRATION_REQUIRED", "message": "Original source needs studio reconciliation"}
                else:
                    result.update(protocolVersion=2, campaignId="abcdefab-cdef-4abc-8def-abcdef123456", expectedCount=str(GIFT_COUNT), configRevision="9223372036854775806")
        elif path.endswith("gift-codes/redeem"):
            assert body.get("protocolVersion") == 2 and isinstance(body.get("expectedCount"), str) and isinstance(body.get("configRevision"), str)
            assert body.get("campaignId") == "abcdefab-cdef-4abc-8def-abcdef123456" and body.get("configRevision") == "9223372036854775806"
            identity = (body["campaignId"], body["userId"], body["expectedCount"])
            replayed = identity in GIFT_ORIGINALS
            if not replayed:
                assert int(body["expectedCount"]) == GIFT_COUNT
                GIFT_ORIGINALS[identity] = body
                GIFT_COUNT += 1
            else:
                assert GIFT_ORIGINALS[identity] == body, "V2 retries must preserve the full original tuple"
            GIFT_REDEEMS += 1
            if GIFT_REDEEMS <= 2:
                status, result = 503, {"code": "UNAVAILABLE", "message": "Response lost after source commit"}
            else:
                result = {"success": True, "giftData": None if replayed else '{"coins":10}', "grantedUnlocks": [], "grantedValues": [], "playerValues": None,
                          "replayed": replayed, "alreadyApplied": replayed, "campaignId": body["campaignId"], "count": str(GIFT_COUNT), "configRevision": body["configRevision"]}
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
    log = ROOT / "tmp" / ("check-" + ("import" if "--import" in args else Path(args[-1]).stem) + ".log")
    try:
        completed = subprocess.run([GODOT, "--path", str(QA), *args], capture_output=True, text=True, env=env, timeout=50)
    except subprocess.TimeoutExpired as error:
        output = (error.stdout or b"").decode(errors="replace") + (error.stderr or b"").decode(errors="replace")
        log.write_text(output)
        print(output[-6000:], flush=True)
        raise
    output = completed.stdout + completed.stderr
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
    animation = run("--headless", "--script", "tests/cutout_animation_smoke.gd")
    assert "CUTOUT_ANIMATION_SMOKE_PASS" in animation
    offline = run("--headless", "--verbose", "--script", "tests/offline_smoke.gd")
    assert "OFFLINE_SMOKE_PASS" in offline
    if "--offline-only" in sys.argv:
        print("OFFLINE_ONLY_CHECKS_PASS: actual gameplay and terminal audio ownership.")
        return
    with ThreadingHTTPServer(("127.0.0.1", 0), Fixture) as server:
        thread = threading.Thread(target=server.serve_forever, daemon=True)
        thread.start()
        env = os.environ.copy()
        env["SEAGULL_FIXTURE_URL"] = f"http://127.0.0.1:{server.server_port}"
        sdk = run("--headless", "--script", "tests/sdk_fixture_smoke.gd", env=env)
        server.shutdown()
    assert "SDK_FIXTURE_SMOKE_PASS" in sdk
    protected = [r for r in REQUESTS if any(part in r["path"] for part in
                 ["cloud-save", "validated-actions", "player-profile", "gift-codes/redeem", "player-values", "/app/statistics"])]
    assert protected and all(r["auth"] == "Bearer synthetic-player-session" for r in protected)
    assert any("/storm/around?" in r["path"] and "range=5" in r["path"] for r in REQUESTS)
    assert not any(r["path"].endswith("/reject/submit") for r in REQUESTS)
    assert not any("/storm/submit" in r["path"] for r in REQUESTS), "No failed validated request may become an ordinary score"
    saves = [json.loads(r["body"]["saveData"])["coins"] for r in REQUESTS if r["path"].endswith("cloud-save/save")]
    assert saves == [77, 67, 42], f"Full cloud snapshots arrive in order and no failed-ticket rewards leak: {saves}"
    assert not any(r["path"].endswith("user-management/signup") for r in REQUESTS), "Failed restore must never create a replacement guest"
    gifts = [r["body"] for r in REQUESTS if r["path"].endswith("gift-codes/redeem")]
    assert len(gifts) == 4 and gifts[0] == gifts[1] == gifts[2], "Lost Gift response and restart retain the exact V2 original"
    assert len(GIFT_ORIGINALS) == 2 and GIFT_COUNT == 9007199254740995
    assert gifts[0]["expectedCount"] == "9007199254740993" and gifts[3]["expectedCount"] == "9007199254740994", "Int64 sequence strings never round"
    purchases = [r["body"] for r in REQUESTS if r["path"].endswith("player-values/purchase")]
    assert len(purchases) == 3 and len({r["operationId"] for r in purchases}) == 1, "Retries preserve the original purchase ID"
    assert all(r["offerKey"] == "pack" and r["userId"] == "qa-player" for r in purchases)
    adjustments = [r["body"] for r in REQUESTS if r["path"].endswith("player-values/adjust")]
    assert len(adjustments) == 6 and adjustments[2]["operationId"] == adjustments[3]["operationId"]
    assert adjustments[4]["operationId"] == adjustments[5]["operationId"], "Internal retry retains its original ID"
    assert len({r["operationId"] for r in adjustments}) == 4, "Only definite first-send refusal releases a command; expired/internal retries remain protected"
    statistics = [r["body"] for r in REQUESTS if r["method"] == "POST" and r["path"] == "/api/v1/app/statistics"]
    assert len(statistics) == 4 and statistics[0] == statistics[1] == statistics[2], "Lost-response retries retain exactly one immutable ID/payload"
    assert len(STATISTICS_RECEIPTS) == 2 and STATISTICS_VALUES == {"rounds": 3, "kills": 4294967301, "best_score": 9007199254740990}, "Each batch books once, with safe int64 preserved"
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
