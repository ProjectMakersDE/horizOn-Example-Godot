"""One actual Godot UI → SDK → server-log → trusted CLI composition in loopback."""
import base64
import hashlib
import json
import os
from pathlib import Path
import tempfile
import threading
from http.server import ThreadingHTTPServer
import test_defense_notice as contract

C = contract.C
P, U, V, O, R, T = contract.P, contract.U, contract.V, contract.O, contract.R, contract.T
CREATED = "00000000-0000-0000-0000-0000000000c8"
LIMITS = {"collections": 10, "storageBytes": 5242880, "objectBytes": 2048}


def obj(identity=O, owner=V, data=None):
    raw = data if data is not None else C.encoded({"version": 1, "hp": 1, "power": 3})
    return {"id": identity, "collection": "defenses", "ownerId": owner, "groupId": None, "revision": 1,
            "dataBase64": base64.b64encode(raw).decode(), "search": {"power": 3}, "position": {"x": 10, "y": 10},
            "createdAt": T, "updatedAt": T, "expiresAt": None}


class NativeFixture(contract.Fixture):
    def reply(self, value):
        self.send_response(200); self.end_headers(); self.wfile.write(C.encoded(value))

    def do_GET(self):
        if self.path.startswith("/api/v1/admin/"):
            return super().do_GET()
        self.server.app_calls.append(("GET", self.path, None))
        if "/usage?" in self.path:
            return self.reply(dict(userId=U, collection="defenses", revision=0, count=0, limits=LIMITS, pollAfterSeconds=1, serverTime=T))
        if "/objects/" in self.path:
            return self.reply({"object": obj(), "pollAfterSeconds": 1, "serverTime": T})
        self.send_error(404)

    def do_POST(self):
        if self.path.startswith("/api/v1/admin/"):
            return super().do_POST()
        body = C.decode(self.rfile.read(int(self.headers.get("Content-Length", 0))))
        self.server.app_calls.append(("POST", self.path, body))
        if self.path.endswith("/user-management/signin"):
            return self.reply({"userId": U, "displayName": "Defense fixture", "email": "defense@example.invalid", "accessToken": "defense-fixture-session", "type": "EMAIL", "authStatus": "AUTHENTICATED"})
        if self.path.endswith("/defenses/objects"):
            assert self.headers["If-Match"] == "0" and body["userId"] == U
            assert C.parameters(base64.b64decode(body["dataBase64"])) == {"version": 1, "hp": 15, "power": 3}
            return self.reply({"object": obj(CREATED, U, base64.b64decode(body["dataBase64"])), "usage": dict(userId=U, collection="defenses", revision=1, count=1, limits=LIMITS, pollAfterSeconds=1, serverTime=T), "pollAfterSeconds": 1, "serverTime": T})
        if self.path.endswith("/defenses/query"):
            assert body["userId"] == U and body["mode"] in ("rectangle", "random")
            return self.reply({"objects": [obj()], "nextCursor": None, "pollAfterSeconds": 1, "serverTime": T})
        if self.path.endswith("/validated-actions/runs"):
            assert body["userId"] == U and body["leaderboardKey"] == "defense_recipe"
            assert C.digest(base64.b64decode(body["context"]["initialState"])) == body["context"]["contentDigest"]
            return self.reply({"runId": R, "ticket": "synthetic-defense-ticket", "seed": 7, "leaderboardKey": "defense_recipe", "issuedAt": T, "expiresAt": "2026-10-18T14:00:00.000Z", "expiresInSeconds": 7200})
        if self.path.endswith("/validated-actions/submit"):
            assert body["userId"] == U and body["ticket"] == "synthetic-defense-ticket" and body["score"] == 1201
            self.server.submitted_hash = body["inputLogHash"]
            self.server.run = {"runId": R, "userId": U, "leaderboardKey": "defense_recipe", "status": "ACCEPTED", "sus": False, "score": body["score"], "issuedAt": T}
            return self.reply({"accepted": True, "runId": R, "leaderboardKey": "defense_recipe", "score": 1201, "bestScore": 1201, "isNewHighScore": True, "rank": 1, "durationSeconds": 1, "state": None, "sus": False, "evidence": {"required": True, "runId": R, "uploadBefore": "2026-10-19T12:00:00.000Z", "maxBytes": 32768}})
        self.send_error(404)

    def do_PUT(self):
        body = C.decode(self.rfile.read(int(self.headers.get("Content-Length", 0))))
        self.server.app_calls.append(("PUT", self.path, body))
        assert self.path == f"/api/v1/app/validated-actions/runs/{R}/evidence" and body["userId"] == U
        self.server.log = base64.b64decode(body["log"], validate=True)
        assert C.digest(self.server.log) == self.server.submitted_hash
        self.server.evidence = {"runId": R, "apiKeyId": P, "userId": U, "leaderboardKey": "defense_recipe", "status": "UPLOADED", "sus": False, "seed": 7, "score": 1201, "logHash": self.server.submitted_hash}
        return self.reply({"runId": R, "status": "UPLOADED", "bytes": len(self.server.log)})


def run(native):
    with tempfile.TemporaryDirectory(prefix="seagull-native-trusted-") as folder:
        root = Path(folder); root.chmod(0o700)
        with ThreadingHTTPServer(("127.0.0.1", 0), NativeFixture) as server:
            server.calls = []; server.app_calls = []; server.original = None
            server.text_bytes = 256; server.retention_days = 17
            server.drop = False; server.refuse = False; server.malformed = False
            thread = threading.Thread(target=server.serve_forever, daemon=True); thread.start()
            try:
                config = root/'private.json'
                C.save(config, {"baseUrl": f"http://127.0.0.1:{server.server_port}", "apiKeyId": P, "sessionToken": "synthetic-session"}, fresh=True)
                api = C.Api(config); state_path = root/'challenge.json'
                args = type("Args", (), dict(object=O, attacker=U, collection="defenses", board="defense_recipe"))()
                challenge = C.prepare(api, state_path, args)
                env = os.environ.copy(); env['SEAGULL_DEFENSE_URL'] = api.base; env['SEAGULL_DEFENSE_CHALLENGE'] = json.dumps(challenge)
                output = native.run('--headless', '--script', 'tests/defense_recipe_transport.gd', env=env)
                assert 'DEFENSE_RECIPE_NATIVE_HTTP_PASS' in output
                assert len(server.app_calls) == 9, server.app_calls
                assert server.app_calls[-1][0] == 'PUT' and not any('/admin/' in item[1] for item in server.app_calls)
                C.verify(api, state_path, C.decode(state_path.read_bytes()), R, 3600)
                first = C.send(api, state_path, C.decode(state_path.read_bytes()))
                replay = C.send(C.Api(config), state_path, C.decode(state_path.read_bytes()))
                assert not first['replayed'] and replay['replayed'] and first['entryId'] == replay['entryId']
                posts = [item[2] for item in server.calls if item[0] == 'POST']
                assert len(posts) == 2 and posts[0] == posts[1]
                print('DEFENSE_NATIVE_TRUSTED_COMPOSITION_PASS: 9 actual native UI/SDK requests; actual uploaded input independently replayed by CLI; identical 7-field ordinary delivery/replay; zero client-admin requests.')
            finally:
                server.shutdown(); thread.join(timeout=5)
