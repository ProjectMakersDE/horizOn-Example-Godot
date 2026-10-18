#!/usr/bin/env python3
"""Explicit trusted operator companion; never ship the private config in a game build.

prepare reads a real defense. verify replays real server evidence. send submits the
one durable seven-field ordinary Inbox original. No daemon or automatic retries.
"""
import argparse
import base64
import contextlib
import datetime as dt
import fcntl
import hashlib
import json
import os
from pathlib import Path
import re
import sys
import urllib.error
import urllib.parse
import urllib.request
import uuid

SAFE = 9007199254740991
VERSION = "seagull-defense-v1"


class Refused(Exception):
    pass


def require(condition, code):
    if not condition:
        raise Refused(code)


def integer(value, low=0, high=SAFE):
    return type(value) is int and low <= value <= high


def identifier(value):
    try:
        return isinstance(value, str) and str(uuid.UUID(value)) == value
    except (ValueError, AttributeError):
        return False


def pairs(items):
    result = {}
    for key, value in items:
        require(key not in result, "DUPLICATE_JSON_KEY")
        result[key] = value
    return result


def decode(raw):
    return json.loads(raw.decode("utf-8", errors="strict"), object_pairs_hook=pairs,
                      parse_constant=lambda _: (_ for _ in ()).throw(Refused("NONFINITE_JSON")))


def encoded(value):
    return (json.dumps(value, ensure_ascii=False, separators=(",", ":"), allow_nan=False) + "\n").encode("utf-8")


def digest(raw):
    return hashlib.sha256(raw).hexdigest()


def sync_dir(folder):
    fd = os.open(folder, os.O_RDONLY)
    try:
        os.fsync(fd)
    finally:
        os.close(fd)


def private_file(path):
    require(path.is_file() and not path.is_symlink() and path.stat().st_mode & 0o077 == 0,
            "PRIVATE_REGULAR_FILE_REQUIRED")


def save(path, value, fresh=False):
    require(not path.is_symlink() and (not fresh or not path.exists()), "EXISTING_STATE_REQUIRES_RECONCILIATION")
    partial = path.with_name(path.name + ".next")
    fd = os.open(partial, os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600)
    raw = encoded(value)
    with os.fdopen(fd, "wb") as file:
        file.write(raw)
        file.flush()
        os.fsync(file.fileno())
    require(partial.read_bytes() == raw, "STATE_READBACK_FAILED")
    os.replace(partial, path)
    sync_dir(path.parent)
    require(path.read_bytes() == raw, "STATE_READBACK_FAILED")


@contextlib.contextmanager
def lock(path):
    require(path.parent.is_dir() and not path.parent.is_symlink(), "EXISTING_PRIVATE_DIRECTORY_REQUIRED")
    require(path.parent.stat().st_mode & 0o077 == 0, "PRIVATE_DIRECTORY_REQUIRED")
    lock_path = path.with_name(path.name + ".lock")
    fd = os.open(lock_path, os.O_RDWR | os.O_CREAT | getattr(os, "O_NOFOLLOW", 0), 0o600)
    try:
        fcntl.flock(fd, fcntl.LOCK_EX | fcntl.LOCK_NB)
        require(not path.with_name(path.name + ".next").exists(), "PARTIAL_STATE_REQUIRES_RECOVERY")
        yield
    finally:
        os.close(fd)


def instant(value):
    require(isinstance(value, str), "INVALID_SERVER_TIME")
    parsed = dt.datetime.fromisoformat(value.replace("Z", "+00:00"))
    require(parsed.tzinfo is not None and parsed.microsecond % 1000 == 0, "INVALID_SERVER_TIME")
    require(0 <= millis(parsed) <= SAFE, "INVALID_SERVER_TIME")
    return parsed


def millis(value):
    delta = value.astimezone(dt.timezone.utc) - dt.datetime(1970, 1, 1, tzinfo=dt.timezone.utc)
    return delta.days * 86400000 + delta.seconds * 1000 + delta.microseconds // 1000


def iso(value):
    return value.astimezone(dt.timezone.utc).isoformat(timespec="milliseconds").replace("+00:00", "Z")


class NoRedirect(urllib.request.HTTPRedirectHandler):
    def redirect_request(self, *_args, **_kwargs):
        raise Refused("REDIRECT_REFUSED")


class Api:
    def __init__(self, config):
        private_file(config)
        value = decode(config.read_bytes())
        self.base = value["baseUrl"].rstrip("/")
        url = urllib.parse.urlsplit(self.base)
        require(url.scheme == "https" or (url.scheme == "http" and url.hostname in ("127.0.0.1", "localhost")),
                "HTTPS_OR_LOOPBACK_REQUIRED")
        require(not url.username and not url.password and not url.query and not url.fragment and url.path in ("", "/"),
                "ORIGIN_REQUIRED")
        self.project = value["apiKeyId"]
        require(identifier(self.project), "INVALID_PROJECT")
        self.token = value["sessionToken"]
        require(isinstance(self.token, str) and self.token and not any(c in self.token for c in "\r\n;"), "INVALID_SESSION")
        self.maximum = value.get("maxResponseBytes", 16 * 1024 * 1024)
        require(integer(self.maximum, 1), "INVALID_OPERATOR_TRANSPORT_BUDGET")
        self.calls = []

    def request(self, method, route, original=None, binary=False):
        require(route.startswith("/api/v1/admin/") and "://" not in route, "ADMIN_ROUTE_REQUIRED")
        body = original.encode("utf-8") if original is not None else None
        self.calls.append({"method": method, "route": route})
        request = urllib.request.Request(self.base + route, data=body, method=method,
            headers={"Cookie": "horizon_session=" + self.token, "Content-Type": "application/json"})
        opener = urllib.request.build_opener(NoRedirect())
        try:
            response = opener.open(request, timeout=30)
        except urllib.error.HTTPError as error:
            raise Refused("HTTP_" + str(error.code)) from None
        with response:
            raw = response.read(self.maximum + 1)
            require(len(raw) <= self.maximum, "OPERATOR_RESPONSE_BUDGET_EXCEEDED")
            require(response.status in (200, 201), "UNEXPECTED_HTTP_STATUS")
        return raw if binary else decode(raw)

    def query(self, route, **values):
        return route + "?" + urllib.parse.urlencode(dict(apiKeyId=self.project, **values))


def parameters(raw):
    value = decode(raw)
    require(type(value) is dict and set(value) == {"version", "hp", "power"} and type(value["version"]) is int and value["version"] == 1,
            "NOT_RECIPE_DEFENSE")
    # Fixed rules of this six-turn mini-game, not a Shared Objects quota.
    require(integer(value["hp"], 1, 1000) and integer(value["power"], 1, 1000), "INVALID_GAME_PARAMETERS")
    return value


def simulate(seed, params, moves):
    require(integer(seed, -(2 ** 31), 2 ** 31 - 1), "INVALID_SERVER_SEED")
    require(type(moves) is list and 1 <= len(moves) <= 6 and all(integer(x, 0, 1) for x in moves), "INVALID_INPUT_LOG")
    rng, player, defender = seed & 0xffffffff, 20, params["hp"]
    for index, move in enumerate(moves):
        require(player > 0 and defender > 0, "INPUT_AFTER_TERMINAL")
        rng = (rng * 1664525 + 1013904223) & 0xffffffff
        damage = 2 + ((rng >> 8) % 4) if move == 0 else 1
        defender = max(0, defender - damage)
        if defender > 0:
            player = max(0, player - max(0, params["power"] + ((rng >> 16) % 2) - (3 if move == 1 else 0)))
        if index == len(moves) - 1:
            require(player == 0 or defender == 0 or len(moves) == 6, "GAME_NOT_FINISHED")
    won = defender == 0 and player > 0
    return {"attackerWon": won, "score": (1000 if won else 0) + player * 10 + params["hp"] - defender}


def prepare(api, path, args):
    require(not path.exists(), "EXISTING_STATE_REQUIRES_RECONCILIATION")
    require(identifier(args.object) and identifier(args.attacker), "INVALID_PLAYER_OR_OBJECT")
    require(re.fullmatch(r"[a-z][a-z0-9_]{0,63}", args.collection) is not None, "INVALID_COLLECTION")
    require(isinstance(args.board, str) and args.board and len(args.board.encode()) <= 200, "INVALID_BOARD")
    result = api.request("GET", api.query("/api/v1/admin/shared-objects/" + args.collection + "/objects/" + args.object))
    obj = result["object"]
    require(obj["id"] == args.object and obj["collection"] == args.collection and identifier(obj["ownerId"]), "FOREIGN_DEFENSE")
    require(obj["ownerId"] != args.attacker and integer(obj["revision"], 1), "FOREIGN_DEFENSE")
    raw = base64.b64decode(obj["dataBase64"], validate=True)
    require(base64.b64encode(raw).decode() == obj["dataBase64"], "NONCANONICAL_DEFENSE")
    params = parameters(raw)
    created = instant(result["serverTime"])
    challenge = {"version": VERSION, "challengeId": str(uuid.uuid4()), "apiKeyId": api.project,
        "collection": args.collection, "objectId": obj["id"], "defenderId": obj["ownerId"],
        "attackerId": args.attacker, "revision": obj["revision"], "digest": digest(raw),
        "parameters": params, "leaderboardKey": args.board, "createdAt": iso(created)}
    state = {"format": VERSION, "baseUrl": api.base, "state": "prepared", "challenge": challenge,
             "run": None, "noticeJson": None, "delivery": None}
    save(path, state, fresh=True)
    return challenge


def verify(api, path, state, run_id, retention):
    require(state["noticeJson"] is None, "ORIGINAL_NOTICE_ALREADY_EXISTS_USE_SEND")
    require(identifier(run_id), "INVALID_RUN")
    challenge = state["challenge"]
    if state["run"] is not None:
        require(state["run"]["runId"] == run_id, "ANOTHER_RUN_ALREADY_BOUND")
    else:
        state["run"] = {"runId": run_id}
        state["state"] = "verification-unconfirmed"
        save(path, state)  # Freeze the selected original run before the first fallible read.
    runs = api.request("GET", api.query("/api/v1/admin/validated-actions/runs", status="ACCEPTED", limit=100))["runs"]
    matches = [run for run in runs if run.get("runId") == run_id]
    require(len(matches) == 1, "ORIGINAL_ACCEPTED_RUN_NOT_RETAINED")
    run = matches[0]
    require(run["status"] == "ACCEPTED" and run["userId"] == challenge["attackerId"]
            and run["leaderboardKey"] == challenge["leaderboardKey"] and run.get("sus") is False, "UNTRUSTED_RUN")
    require(instant(run["issuedAt"]) >= instant(challenge["createdAt"]), "RUN_PREDATES_CHALLENGE")
    detail = api.request("GET", api.query("/api/v1/admin/validated-actions/evidence/" + run_id))
    require(detail["runId"] == run_id and detail["apiKeyId"] == api.project and detail["userId"] == challenge["attackerId"]
            and detail["leaderboardKey"] == challenge["leaderboardKey"] and detail["status"] == "UPLOADED"
            and detail.get("sus") is False, "UNTRUSTED_EVIDENCE")
    log = api.request("GET", api.query("/api/v1/admin/validated-actions/evidence/" + run_id + "/log"), binary=True)
    require(digest(log) == detail["logHash"], "SERVER_LOG_HASH_MISMATCH")
    inputs = decode(log)
    require(type(inputs) is dict and set(inputs) == {"version", "challengeId", "objectId", "revision", "digest", "runId", "seed", "moves"}, "INVALID_INPUT_LOG")
    for key in ("version", "challengeId", "objectId", "revision", "digest"):
        require(inputs[key] == challenge[key], "DEFENSE_BINDING_MISMATCH")
    require(inputs["runId"] == run_id and inputs["seed"] == detail["seed"], "RUN_BINDING_MISMATCH")
    outcome = simulate(detail["seed"], challenge["parameters"], inputs["moves"])
    require(integer(detail["score"]) and detail["score"] == run["score"] == outcome["score"], "AUTHORITATIVE_REPLAY_MISMATCH")
    state["run"] = dict(runId=run_id, logHash=detail["logHash"], seed=detail["seed"], **outcome)
    state["state"] = "verified"
    save(path, state)  # No second defense blob or input-log history is persisted.
    inbox = api.request("GET", api.query("/api/v1/admin/inbox/players/" + challenge["defenderId"]))
    require(inbox["userId"] == challenge["defenderId"] and integer(inbox["revision"]), "INVALID_DEFENDER_INBOX")
    limits = inbox["limits"]
    require(integer(limits["freeTextBytes"], 1) and integer(limits["freeTextRetentionDays"], 1), "INVALID_CURRENT_INBOX_POLICY")
    text = "Your defense fell." if outcome["attackerWon"] else "Your defense held."
    require(len(text.encode("utf-8")) <= limits["freeTextBytes"], "PLAIN_TEXT_POLICY_TOO_SMALL")
    require(integer(retention, 1), "INVALID_REQUESTED_RETENTION")
    issued = instant(inbox["serverTime"])
    seconds = min(retention, limits["freeTextRetentionDays"] * 86400)
    notice = {"apiKeyId": api.project, "userId": challenge["defenderId"], "operationId": str(uuid.uuid4()),
        "issuedAt": iso(issued), "expiresAt": iso(issued + dt.timedelta(seconds=seconds)),
        "freeText": text, "expectedRevision": inbox["revision"]}
    state["noticeJson"] = encoded(notice).decode().rstrip("\n")
    state["state"] = "notice-prepared"
    save(path, state)
    return {"verified": True, "runId": run_id, "noticePrepared": True, "attackerWon": outcome["attackerWon"]}


def send(api, path, state):
    original = state["noticeJson"]
    require(isinstance(original, str) and state["run"] is not None, "VERIFIED_ORIGINAL_REQUIRED")
    notice = decode(original.encode())
    require(set(notice) == {"apiKeyId", "userId", "operationId", "issuedAt", "expiresAt", "freeText", "expectedRevision"}, "INVALID_ORIGINAL")
    require(notice["apiKeyId"] == api.project and notice["userId"] == state["challenge"]["defenderId"], "FOREIGN_ORIGINAL")
    # Mark uncertain BEFORE the single POST. Expiry/refusal never discards or re-identifies it.
    state["state"] = "unconfirmed"
    state["sendAttempts"] = state.get("sendAttempts", 0) + 1
    save(path, state)
    result = api.request("POST", "/api/v1/admin/inbox/messages", original)
    stamp = millis(instant(notice["issuedAt"]))
    identity = f"{api.project}:{notice['userId']}:{notice['operationId']}:{notice['expectedRevision']}:{stamp}"
    expected = "message:" + str(uuid.UUID(bytes=hashlib.md5(identity.encode()).digest(), version=3))
    require(result.get("entryId") == expected and type(result.get("replayed")) is bool, "UNCONFIRMED_DELIVERY_RESPONSE")
    state["delivery"] = {"entryId": expected, "replayed": result["replayed"]}
    state["state"] = "delivered"
    # Keep only the small original/binding needed for exact retry; never retain input logs/blobs.
    save(path, state)
    return result


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("command", choices=["prepare", "verify", "send", "inspect"])
    parser.add_argument("--config", type=Path)
    parser.add_argument("--state", type=Path, required=True)
    parser.add_argument("--collection", default="defenses")
    parser.add_argument("--object")
    parser.add_argument("--attacker")
    parser.add_argument("--board", default="defense_recipe")
    parser.add_argument("--run")
    parser.add_argument("--retention-seconds", type=int, default=3600)
    args = parser.parse_args()
    os.umask(0o077)
    try:
        with lock(args.state):
            if args.command == "inspect":
                private_file(args.state)
                state = decode(args.state.read_bytes())
                print(json.dumps({"state": state["state"], "challenge": state["challenge"], "run": state["run"], "delivery": state["delivery"]}))
                return 0
            require(args.config is not None, "PRIVATE_CONFIG_REQUIRED")
            api = Api(args.config)
            if args.command == "prepare":
                result = prepare(api, args.state, args)
            else:
                private_file(args.state)
                state = decode(args.state.read_bytes())
                require(state["format"] == VERSION and state["baseUrl"] == api.base and state["challenge"]["apiKeyId"] == api.project, "FOREIGN_STATE")
                if args.command == "verify":
                    result = verify(api, args.state, state, args.run, args.retention_seconds)
                else:
                    result = send(api, args.state, state)
            print(json.dumps(result))
        return 0
    except (Refused, OSError, ValueError, KeyError, TypeError, OverflowError, urllib.error.URLError) as error:
        code = str(error) if isinstance(error, Refused) else type(error).__name__
        print(json.dumps({"ok": False, "code": code, "automaticRetries": 0}), file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
