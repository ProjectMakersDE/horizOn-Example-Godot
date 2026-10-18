#!/usr/bin/env python3
"""Real local HTTP companion contract; no Develop credential, engine or fixed port."""
import base64
import copy
import hashlib
import importlib.util
import json
import os
from pathlib import Path
import socket
import tempfile
import threading
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
import unittest
import uuid

SPEC = importlib.util.spec_from_file_location("defense_notice", Path(__file__).resolve().parents[1] / "tools/defense_notice.py")
C = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(C)
P, U, V, O, R = [str(uuid.UUID(int=n)) for n in range(100, 105)]
T = "2026-10-18T12:00:00.000Z"


class Fixture(BaseHTTPRequestHandler):
    def log_message(self, *_args):
        pass

    def do_GET(self):
        self.server.calls.append(("GET", self.path, None))
        path = self.path.split("?")[0]
        if "/shared-objects/" in path:
            value = {"object": {"id": O, "collection": "defenses", "ownerId": V, "revision": 1,
                "dataBase64": base64.b64encode(C.encoded({"version": 1, "hp": 1, "power": 3})).decode()}, "serverTime": T}
        elif path.endswith("/runs"):
            value = {"runs": [dict(self.server.run)]}
        elif path.endswith("/log"):
            raw = self.server.log
            self.send_response(200); self.end_headers(); self.wfile.write(raw)
            return
        elif "/evidence/" in path:
            value = dict(self.server.evidence)
        elif "/inbox/players/" in path:
            value = {"userId": V, "revision": 7, "serverTime": T,
                     "limits": {"freeTextBytes": self.server.text_bytes, "freeTextRetentionDays": self.server.retention_days}}
        else:
            self.send_error(404)
            return
        self.send_response(200); self.end_headers(); self.wfile.write(C.encoded(value))

    def do_POST(self):
        body = self.rfile.read(int(self.headers["Content-Length"]))
        self.server.calls.append(("POST", self.path, body))
        if self.server.refuse:
            self.send_error(409)
            return
        value = C.decode(body)
        previous = self.server.original
        if previous is not None and previous != body:
            self.send_error(409)
            return
        self.server.original = body
        stamp = C.millis(C.instant(value["issuedAt"]))
        identity = f"{P}:{V}:{value['operationId']}:{value['expectedRevision']}:{stamp}"
        entry = "message:" + str(uuid.UUID(bytes=hashlib.md5(identity.encode()).digest(), version=3))
        result = {"entryId": entry, "replayed": previous is not None}
        if self.server.malformed:
            result["entryId"] = "message:" + str(uuid.UUID(int=999))
        if self.server.drop:
            self.server.drop = False
            self.connection.shutdown(socket.SHUT_RDWR); self.connection.close()
            return
        self.send_response(200); self.end_headers(); self.wfile.write(C.encoded(result))


class CompanionTest(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix="seagull-defense-contract-")
        self.root = Path(self.temp.name); self.root.chmod(0o700)
        self.path = self.root / "original.json"
        self.server = ThreadingHTTPServer(("127.0.0.1", 0), Fixture)
        self.server.calls = []; self.server.original = None
        self.server.text_bytes = 256; self.server.retention_days = 17
        self.server.drop = False; self.server.refuse = False; self.server.malformed = False
        self.thread = threading.Thread(target=self.server.serve_forever, daemon=True); self.thread.start()
        config = self.root / "private.json"
        C.save(config, {"baseUrl": f"http://127.0.0.1:{self.server.server_port}", "apiKeyId": P, "sessionToken": "synthetic-session"}, fresh=True)
        self.api = C.Api(config)
        args = type("Args", (), dict(object=O, attacker=U, collection="defenses", board="defense_recipe"))()
        self.challenge = C.prepare(self.api, self.path, args)
        self.server.log = C.encoded({k: self.challenge[k] for k in ["version", "challengeId", "objectId", "revision", "digest"]} | {"runId": R, "seed": 7, "moves": [0]})
        self.server.run = {"runId": R, "userId": U, "leaderboardKey": "defense_recipe", "status": "ACCEPTED", "sus": False, "score": 1201, "issuedAt": T}
        self.server.evidence = {"runId": R, "apiKeyId": P, "userId": U, "leaderboardKey": "defense_recipe", "status": "UPLOADED", "sus": False, "seed": 7, "score": 1201, "logHash": C.digest(self.server.log)}

    def tearDown(self):
        self.server.shutdown(); self.server.server_close(); self.thread.join(timeout=5)
        self.temp.cleanup()

    def state(self):
        return C.decode(self.path.read_bytes())

    def verify(self, seconds=3600):
        return C.verify(self.api, self.path, self.state(), R, seconds)

    def test_independent_simulation_and_no_blob_history(self):
        self.assertEqual(C.simulate(7, {"version": 1, "hp": 1, "power": 3}, [0]), {"attackerWon": True, "score": 1201})
        self.assertEqual(C.simulate(0, {"version": 1, "hp": 1000, "power": 1000}, [0]), {"attackerWon": False, "score": 5})
        self.verify()
        state = self.state()
        self.assertNotIn("dataBase64", json.dumps(state)); self.assertNotIn("moves", json.dumps(state))
        self.assertNotIn("ticket", json.dumps(state)); self.assertNotIn("sessionToken", json.dumps(state))
        self.assertEqual(state["run"]["logHash"], C.digest(self.server.log))
        self.assertEqual(set(C.decode(state["noticeJson"].encode())), {"apiKeyId", "userId", "operationId", "issuedAt", "expiresAt", "freeText", "expectedRevision"})

    def test_true_committed_drop_and_identical_explicit_retry_after_reload(self):
        self.verify(); original = self.state()["noticeJson"]
        self.server.drop = True
        with self.assertRaises(OSError): C.send(self.api, self.path, self.state())
        self.assertEqual(self.state()["state"], "unconfirmed")
        # Independent read/recreated Api models operator process restart; no new identity.
        api = C.Api(self.root / "private.json")
        self.server.text_bytes = 1; self.server.retention_days = 1
        result = C.send(api, self.path, self.state())
        self.assertTrue(result["replayed"])
        posts = [call[2] for call in self.server.calls if call[0] == "POST"]
        self.assertEqual(posts, [original.encode(), original.encode()])
        self.assertEqual(self.state()["noticeJson"], original)

    def test_untrusted_server_evidence_rejected_before_any_notice(self):
        self.server.evidence["userId"] = V
        with self.assertRaisesRegex(C.Refused, "UNTRUSTED_EVIDENCE"): self.verify()
        self.assertIsNone(self.state()["noticeJson"])
        self.assertEqual(self.state()["run"]["runId"], R)
        with self.assertRaisesRegex(C.Refused, "ANOTHER_RUN"): C.verify(self.api, self.path, self.state(), str(uuid.uuid4()), 60)
        self.assertFalse(any(call[0] == "POST" for call in self.server.calls))

    def test_claimed_win_or_altered_defense_is_never_authority(self):
        inputs = C.decode(self.server.log); inputs["win"] = True
        self.server.log = C.encoded(inputs); self.server.evidence["logHash"] = C.digest(self.server.log)
        with self.assertRaisesRegex(C.Refused, "INVALID_INPUT_LOG"): self.verify()
        inputs.pop("win"); inputs["digest"] = "0" * 64
        self.server.log = C.encoded(inputs); self.server.evidence["logHash"] = C.digest(self.server.log)
        with self.assertRaisesRegex(C.Refused, "DEFENSE_BINDING"): self.verify()

    def test_server_hash_and_independent_score_required(self):
        self.server.evidence["logHash"] = "0" * 64
        with self.assertRaisesRegex(C.Refused, "SERVER_LOG_HASH"): self.verify()
        self.server.evidence["logHash"] = C.digest(self.server.log)
        self.server.evidence["score"] = 1; self.server.run["score"] = 1
        with self.assertRaisesRegex(C.Refused, "AUTHORITATIVE_REPLAY"): self.verify()

    def test_policy_is_current_configurable_and_original_is_frozen(self):
        self.verify(12 * 86400)
        notice = C.decode(self.state()["noticeJson"].encode())
        self.assertEqual((C.instant(notice["expiresAt"]) - C.instant(notice["issuedAt"])).days, 12)
        self.assertEqual(notice["expectedRevision"], 7)
        with self.assertRaisesRegex(C.Refused, "ORIGINAL_NOTICE_ALREADY"): self.verify()

    def test_refusal_expiry_or_malformed_result_never_deletes_or_rebases(self):
        self.verify(); original = self.state()["noticeJson"]
        self.server.refuse = True
        with self.assertRaisesRegex(C.Refused, "HTTP_409"): C.send(self.api, self.path, self.state())
        self.assertEqual(self.state()["state"], "unconfirmed"); self.assertEqual(self.state()["noticeJson"], original)
        self.server.refuse = False; self.server.malformed = True
        with self.assertRaisesRegex(C.Refused, "UNCONFIRMED_DELIVERY"): C.send(self.api, self.path, self.state())
        self.assertEqual(self.state()["state"], "unconfirmed"); self.assertEqual(self.state()["noticeJson"], original)

    def test_small_policy_missing_run_and_partial_store_fail_closed(self):
        self.server.text_bytes = 1
        with self.assertRaisesRegex(C.Refused, "PLAIN_TEXT_POLICY"): self.verify()
        self.assertEqual(self.state()["state"], "verified"); self.assertIsNone(self.state()["noticeJson"])
        self.server.run["runId"] = str(uuid.uuid4())
        with self.assertRaisesRegex(C.Refused, "ORIGINAL_ACCEPTED_RUN_NOT_RETAINED"): self.verify()
        partial = self.path.with_name(self.path.name + ".next"); partial.write_bytes(b"partial")
        before = len(self.server.calls)
        with self.assertRaisesRegex(C.Refused, "PARTIAL_STATE"):
            with C.lock(self.path): pass
        self.assertEqual(len(self.server.calls), before)

    def test_exact_millisecond_identity_and_inputs(self):
        self.assertEqual(C.millis(C.instant("2026-10-18T12:00:00.001Z")) % 1000, 1)
        with self.assertRaises(C.Refused): C.decode(b'{"x":1,"x":2}')
        with self.assertRaises(C.Refused): C.simulate(7, {"version": 1, "hp": 1, "power": 3}, [0, 0])
        with self.assertRaises(C.Refused): C.simulate(7, {"version": 1, "hp": 100, "power": 1}, [])


if __name__ == "__main__":
    unittest.main()
