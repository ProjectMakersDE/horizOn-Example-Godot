#!/usr/bin/env python3
"""Real Godot game/Hello consumers, isolated userdata and exact loopback requests only."""
import base64
import copy
import hashlib
import json
import os
from pathlib import Path
import runpy
import shutil
import threading
import uuid
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from urllib.parse import parse_qs, urlparse
import run_checks as native

U = "abcdefab-cdef-4abc-8def-000000001016"
V = "abcdefab-cdef-4abc-8def-000000001017"
W = "abcdefab-cdef-4abc-8def-000000001018"
G = "abcdefab-cdef-4abc-8def-000000003016"
I = "abcdefab-cdef-4abc-8def-000000004016"
J = "abcdefab-cdef-4abc-8def-000000004017"
L = "abcdefab-cdef-4abc-8def-000000005016"
T = "2026-10-17T12:00:00.000Z"
ENTRY = "message:" + I
R = 4294967296
FEATURE_REQUESTS = []
MARKET_ORIGINAL = None

def friend_state(revision, outgoing=()):
    return {"userId": U, "revision": revision, "friendCode": "H-" + base64.urlsafe_b64encode(uuid.UUID(U).bytes).decode().rstrip("="),
            "friends": [], "incoming": [], "outgoing": [{"userId": target, "requestId": target, "createdAt": T, "display": {"name": None, "profile": {"avatarId": None, "frameId": None, "badges": []}}} for target in outgoing],
            "blocked": [], "limits": {"maxFriends": 20, "maxIncomingRequests": 20, "maxOutgoingRequests": 20, "maxBlocked": 100}, "serverTime": T}

def group():
    return {"id": G, "revision": 1, "name": "Seagulls", "description": "", "joinMode": "open", "leaderId": U, "memberCount": 1, "createdAt": T, "updatedAt": T, "myRole": "leader", "data": {}}

def groups_state(revision, created=False):
    return {"userId": U, "revision": revision, "groups": [group()] if created else [], "incomingInvites": [], "outgoingRequests": [],
            "limits": {"maxMembers": 20, "maxGroupsPerPlayer": 1, "maxInvitations": 20, "maxJoinRequests": 20, "maxDataBytes": 2048, "memberPageSize": 50, "maxPlayerInvitations": 2, "maxPlayerRequests": 2, "maxNameBytes": 120, "maxDescriptionBytes": 1024, "maxDataDepth": 16}, "serverTime": T}

def values(revision=10, balance=138):
    return {"userId": U, "revision": revision, "definitionVersion": 1, "day": "2026-10-17", "values": [{"key": "coins", "balance": balance, "earnedToday": 0, "dailyCap": None}], "operationWindow": {"serverTime": T, "oldestAcceptedAt": "2026-09-16T12:00:00Z"}}

def inbox(claimed=False):
    return {"userId": U, "cursor": "claimed" if claimed else "original", "revision": 2 if claimed else 1, "broadcastRevision": 1, "serverTime": T, "pollAfterSeconds": 120, "unchanged": False,
            "entries": [{"id": ENTRY, "kind": "message", "type": "marketplace", "reference": L, "textKey": "marketplace.item_return", "parameters": {}, "createdAt": T, "expiresAt": "2026-10-16T12:00:00Z", "overdue": True, "read": claimed, "claimed": claimed,
                         "attachment": {"values": [], "itemReturn": {"listingId": L, "instanceId": I, "itemKey": "hat"}}}],
            "counts": {"marketplace": {"total": 1, "unread": 0 if claimed else 1, "claimable": 0 if claimed else 1}}, "limits": {"targeted": 1, "broadcasts": 1, "freeTexts": 1, "freeTextBytes": 256, "freeTextRetentionDays": 7}}

def item():
    return {"instanceId": J, "itemKey": "hat", "properties": {"power": 9007199254740991, "label": "雪/😀\0tail", "bound": True}, "equipped": False, "createdAt": T}

ITEM_LIMITS = {"catalog": 6000, "inventory": 250, "receipts": 80}
def inventory(bought=False): return {"userId": U, "revision": 101 if bought else 100, "instances": [item()] if bought else [], "limits": ITEM_LIMITS, "serverTime": T}
MARKET_LIMITS = {"openListingsPerPlayer": 3000, "retainedListingsPerProject": 12000, "receiptsPerPlayer": 160, "historyPerPlayer": 180, "projectWritesPerMinute": 200, "playerWriteIntervalMillis": 1000, "minDurationSeconds": 300, "maxDurationSeconds": 604800, "terminalRetentionSeconds": 604800, "operationRetentionSeconds": 2592000, "queryCandidates": 256, "pageSize": 50}
def listing(sold=False):
    return {"id": L, "revision": 2 if sold else 1, "sellerId": V, "buyerId": U if sold else None, "returnOwnerId": V, "item": None if sold else item(), "itemReference": {"instanceId": J, "itemKey": "hat"}, "currencyKey": "coins", "price": 101, "feeBps": 333, "feeAmount": 3, "sellerNet": 98, "status": "sold" if sold else "active", "createdAt": T, "expiresAt": "2026-10-18T12:00:00.000Z", "terminalAt": T if sold else None, "returnEntryId": None, "ownerUnavailable": False}
def market_state(revision=1): return {"state": {"userId": U, "revision": revision, "openListings": [], "history": [], "operationWindow": {"serverTime": T, "acceptAfter": "2026-09-16T12:00:00.000Z"}, "moderation": {"banUntil": None, "reason": ""}, "limits": MARKET_LIMITS}, "serverTime": T}
MATCH_LIMITS = {"activeMatches": 2, "stateBytes": 1024, "retainedMatches": 20, "pendingInvites": 20, "settlementMatches": 100, "historyRetentionSeconds": 604800, "rankedSettlementSeconds": 604800}
OPTIONS = {"name": "Seagull match", "capacity": 2, "visibility": "private", "strength": 1, "turnSeconds": 60, "timeoutPolicy": "skip", "ranked": False, "dataBase64": "", "inviteeIds": []}
def match():
    return dict(OPTIONS, id=G, revision=1, creatorId=U, status="lobby", participantIds=[U], invitedIds=[], forfeitedIds=[], currentPlayerId=None, turnDeadline=None, createdAt=T, startedAt=None, finishedAt=None, purgeAt=None, finalStateRevision=None, hasDisagreement=False, timeoutDue=False, turnOrder=[], reports=[], reportDeadline=None, absoluteDeadline=None, rankedLeaderboardKey=None, ownRankedRunId=None, notificationPending=False)

CASES = []
def add(method, path, body, response, status=200, query=None, if_match=None): CASES.append((method,path,query or {"userId":[U]} if method=="GET" else query or {},body,response,status,if_match))
add("POST", "/api/v1/app/user-management/signin", {"email":"lab@example.invalid","password":"synthetic-password","type":"EMAIL"}, {"userId":U,"displayName":"Lab","email":"lab@example.invalid","accessToken":"lab-session","type":"EMAIL","authStatus":"AUTHENTICATED"})
add("GET", "/api/v1/app/achievements", None, {"userId":U,"revision":0,"definitionVersion":"a"*64,"definitions":[],"progress":[],"limits":{"maxDefinitions":20,"maxLifetimeKeys":500},"serverTime":T})
add("GET", "/api/v1/app/friends", None, friend_state(R))
add("POST", "/api/v1/app/friends/request", {"userId":U,"targetUserId":V,"expectedRevision":R}, {"code":"UNAVAILABLE"},503)
add("GET", "/api/v1/app/friends", None, friend_state(R+1,[V]))
add("POST", "/api/v1/app/friends/request", {"userId":U,"targetUserId":W,"expectedRevision":R+1}, friend_state(R+2,[V,W]))
add("GET", "/api/v1/app/groups", None, groups_state(R))
add("POST", "/api/v1/app/groups", {"userId":U,"expectedPlayerRevision":R,"name":"Seagulls","description":"","joinMode":"open","data":{"epsilon":0.000001,"exact":9007199254740991,"text":"a\u0000雪"}}, {"code":"UNAVAILABLE"},503)
add("GET", "/api/v1/app/groups", None, groups_state(R+1,True))
add("GET", "/api/v1/app/inbox", None, inbox())
add("POST", "/api/v1/app/inbox/claim", {"userId":U,"entryId":ENTRY}, {"code":"UNAVAILABLE"},503)
add("POST", "/api/v1/app/inbox/claim", {"userId":U,"entryId":ENTRY}, {"entryId":ENTRY,"replayed":True,"inbox":inbox(True),"playerValues":values(),"items":[{"instanceId":I,"itemKey":"hat"}]})
add("GET", "/api/v1/app/items", None, inventory())
add("GET", "/api/v1/app/items/catalog", None, {"revision":1,"definitions":[],"nextAfterKey":None,"total":0,"limits":ITEM_LIMITS,"serverTime":T},query={"userId":[U],"limit":["50"]})
add("GET", "/api/v1/app/shared-objects/collections", None, {"revision":1,"definitions":[],"nextAfterKey":None,"limits":{"collections":2,"storageBytes":5242880,"objectBytes":2048},"serverTime":T},query={"userId":[U],"limit":["50"]})
add("GET", "/api/v1/app/matches", None, {"userId":U,"revision":R,"active":[],"invites":[],"recent":[],"pendingResults":[],"limits":MATCH_LIMITS,"pollAfterSeconds":120,"serverTime":T})
add("POST", "/api/v1/app/matches", dict(OPTIONS,userId=U), {"match":match(),"playerRevision":R+1,"pollAfterSeconds":120,"serverTime":T},if_match=str(R))
add("GET", "/api/v1/app/marketplace/limits", None, {"limits":MARKET_LIMITS,"config":{"revision":7,"enabled":True,"currencyKey":"coins","feeBps":333},"capabilities":{"marketplace":True,"realtime":False},"serverTime":T})
add("GET", "/api/v1/app/marketplace/rules", None, {"revision":7,"rules":[{"itemKey":"hat","active":True,"minPrice":1,"maxPrice":200}],"nextCursor":None,"serverTime":T},query={"userId":[U],"limit":["50"]})
add("GET", "/api/v1/app/marketplace", None, market_state())
add("GET", "/api/v1/app/marketplace/listings/"+L, None, {"listing":listing(),"serverTime":T})
add("POST", "/api/v1/app/marketplace/listings/"+L+"/buy", "market-original", "market-write")
add("GET", "/api/v1/app/items", None, inventory(True))
add("GET", "/api/v1/app/player-values", None, values(11,37))
add("GET", "/api/v1/app/marketplace", None, market_state(2))
add("POST", "/api/v1/app/chat/channels/open", {"userId":U,"kind":"project"}, {"code":"NOT_SUPPORTED","message":"Hosted Chat is unavailable on this backend"},501)

class Fixture(BaseHTTPRequestHandler):
    index=0
    failure=None
    def log_message(self,*_): pass
    def do_GET(self): self.case("GET")
    def do_POST(self): self.case("POST")
    def do_PUT(self): self.case("PUT")
    def do_DELETE(self): self.case("DELETE")
    def case(self, method):
        global MARKET_ORIGINAL
        try:
            index=type(self).index
            assert index<len(CASES), "Unexpected automatic request"
            verb,path,query,body,response,status,if_match=CASES[index]
            parsed=urlparse(self.path)
            actual=json.loads(self.rfile.read(int(self.headers.get("Content-Length",0)))) if method in ["POST","PUT"] else None
            assert (method,parsed.path,parse_qs(parsed.query))==(verb,path,query),(index,method,self.path)
            assert self.headers.get("X-API-Key")=="lab-project-key"
            if index: assert self.headers.get("Authorization")=="Bearer lab-session"
            if if_match is not None: assert self.headers.get("If-Match")==if_match
            if body=="market-original":
                assert set(actual)=={"userId","operationId","issuedAt","expectedListingRevision","expectedPrice","expectedCurrencyKey"}
                assert actual["userId"]==U and actual["expectedListingRevision"]==1 and actual["expectedPrice"]==101 and actual["expectedCurrencyKey"]=="coins"
                assert str(uuid.UUID(actual["operationId"]))==actual["operationId"] and len(actual["issuedAt"])==24 and actual["issuedAt"].endswith("Z")
                MARKET_ORIGINAL=actual
                response={"receipt":{"operationId":actual["operationId"],"issuedAt":actual["issuedAt"],"kind":"buy","listingId":L,"listingRevision":2,"recordedAt":T,"itemReference":{"instanceId":J,"itemKey":"hat"},"currencyKey":"coins","price":101,"feeAmount":3,"sellerNet":98},"listing":listing(True),"replayed":False,"serverTime":T}
            else: assert actual==body,(index,actual,body)
            type(self).index+=1
            FEATURE_REQUESTS.append((method,self.path))
        except Exception as error:
            type(self).failure=str(error)
            status,response=422,{"code":"FIXTURE_REJECTED","message":str(error)}
        raw=json.dumps(response,ensure_ascii=False).encode()
        self.send_response(status);self.send_header("Content-Type","application/json");self.send_header("Content-Length",str(len(raw)));self.end_headers();self.wfile.write(raw)

def main():
    runpy.run_path(str(native.ROOT/'tests/verify_sdk_source.py'),run_name='__main__')
    guide=json.loads((native.ROOT/'examples/public_marketplace/SOURCE.json').read_text())
    assert hashlib.sha256((native.ROOT/'examples/public_marketplace/marketplace_demo.gd').read_bytes()).hexdigest()==guide['sha256']
    native.QA=native.ROOT/'tmp/feature-lab-project'
    if native.QA.exists(): shutil.rmtree(native.QA)
    shutil.copytree(native.ROOT,native.QA,ignore=shutil.ignore_patterns('.git','.godot','tmp','exports','horizon_config.tres'),ignore_dangling_symlinks=True)
    project=native.QA/'project.godot'
    project.write_text(project.read_text().replace('config/name="Seagull Storm"',f'config/name="Seagull Features QA"\nconfig/use_custom_user_dir=true\nconfig/custom_user_dir_name="{native.QA_DATA_NAME}"'))
    native.run('--headless','--editor','--import','--quit')
    assert 'PUBLIC_FEATURE_GUIDES_PASS' in native.run('--headless','--script','tests/public_guides_smoke.gd')
    with ThreadingHTTPServer(('127.0.0.1',0),Fixture) as server:
        thread=threading.Thread(target=server.serve_forever,daemon=True);thread.start()
        env=os.environ.copy();env['SEAGULL_LAB_URL']=f'http://127.0.0.1:{server.server_port}'
        result=native.run('--headless','--script','tests/feature_lab_smoke.gd',env=env)
        server.shutdown()
    assert 'FEATURE_LAB_SMOKE_PASS' in result
    assert Fixture.failure is None,Fixture.failure
    assert Fixture.index==len(CASES),(Fixture.index,len(CASES))
    print(f'FEATURE_LAB_NATIVE_PASS: {len(CASES)} exact HTTP requests; actual game/Hello, source-pinned helpers, unchanged public guide, uncertain social/Inbox originals, no local rewards or historical item creation.')

if __name__=='__main__':
    try: main()
    finally:
        # Unique fixture userdata only; never touches real game progress or pending originals.
        base=Path.home()/'Library/Application Support' if os.sys.platform=='darwin' else Path(os.environ.get('XDG_DATA_HOME',str(Path.home()/'.local/share')))
        userdata=base/native.QA_DATA_NAME
        if userdata.exists(): shutil.rmtree(userdata)
