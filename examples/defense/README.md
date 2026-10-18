# World map and asynchronous defense

One optional recipe in the official Godot Game and Hello. After signing in, open **Current SDK feature lab → Open world map / trusted defense recipe**. Opening it sends no request. Normal game/login/SDK hot paths are unchanged.

Shared Objects stores bytes; Validated Actions checks tickets and configured rules. Neither validates combat. The separate operator CLI independently replays this small game's actual input with the **server seed**, then alone delivers an ordinary defender Inbox message. No client winner flag, client notice send, reward attachment or new backend service is involved.

## Existing project prerequisites

Use your own project, an existing owner account session and two distinct players. Game and standalone Hello can be the clients. Keep current System Config quotas; this recipe does not raise them.

Configure with the existing Dashboard:

- Collection `defenses`: active, all-player reads, owner writes, positions enabled, no TTL, one integer search field `power`. Select count/bytes permitted by current policy. The demonstrated defense is only `{"version":1,"hp":15,"power":3}`. Schema is immutable after first use; a previously used incompatible collection needs a new key.
- Dedicated board `defense_recipe`: `validatedOnly:true`, one available `evidenceTopN` slot. Configure compatible explicit score/duration rules in the existing Validated Actions editor; the six-turn score is within 0–2200. No earned economic values are needed. Accepted input evidence must actually be requested and uploaded.

That slot is an explicit recipe fixture, not a new permanent player/account reserve. Missing/displaced/expired/unuploaded or suspicious evidence cannot authorize a notice. The fixed six turns, 20 attacker HP and HP/power range 1–1000 are mini-game rules, not Shared/Inbox product quotas.

## Defender stores and publishes the map defense

On player B, choose HP/power, explicitly **Read owner usage**, then **Store reviewed defense at map position 10,10** once. **Read one world-map rectangle page** and inspect its server-issued object UUID/owner/revision. Unknown creates use the existing Shared reconciliation flow; do not create again to discover a lost ID.

Player A can **Read one opponent power sample** and select B's defense. Pages are bounded, not uniformly random; returned refresh cadence applies. No hidden poller or automatic pagination is installed.

## Trusted operator freezes the selection

Run the CLI on the trusted operator machine. Never ship its config to Godot/builds/source control or paste it into the challenge field. Use the session of the account that **owns this project**; an unrelated global Admin fixture is not the owner. Recent-run lookup currently requires this owner account session. The delivery endpoint enforces existing project/INBOX authorization.

Make an operator directory 0700 and a config file 0600:

```json
{"baseUrl":"http://127.0.0.1:3170","apiKeyId":"OWN_PROJECT_UUID","sessionToken":"PRIVATE_EXISTING_OWNER_SESSION","maxResponseBytes":16777216}
```

`maxResponseBytes` is an explicit operator resource budget, independent of product quotas. Exceeding it fails visibly and preserves existing originals. Other environments require HTTPS. There are no redirects, login fallback, credential refresh or automatic retries.

```sh
python3 tools/defense_notice.py prepare --config /private/config.json --state /private/defense.json --object DEFENSE_UUID --attacker PLAYER_A_UUID --collection defenses --board defense_recipe
```

One real admin Shared GET freezes ID/owner/revision/digest and small simulation parameters. One challenge UUID is generated. Its stdout is the public challenge JSON for player A; the state file remains private. No complete defense blob is persisted.

## Player A plays and submits

1. Paste the challenge and **Save this reviewed trusted challenge** locally. A previous pending challenge blocks replacement.
2. **Read original defense and start one validated run**. The real Shared SDK GET checks original owner/revision/bytes. The existing `begin_defense_run` sample starts VA. An uncertain-start marker is persisted before dispatch.
3. Explicitly click **Attack** or **Guard** for each turn. Every choice is saved. Displayed HP/score is only a preview.
4. Once terminal, **Submit the finished game and original input log** through existing `submit_defense_run`. The log contains original challenge, defense revision/digest, run ID/seed and actual choices. SDK submit binds its hash; requested evidence uploads the actual log.
5. Record the real run ID and observe actual evidence upload. Accepted submit alone is insufficient for trusted verification.

Interrupted starts/submits stay protected. There is no replacement-run or start/submit retry button. A restarted process without its original SDK ticket requires trusted reconciliation; transparent ticket recovery is not claimed. Unknown originals are retained.

## Verify independently, then send the original notice

```sh
python3 tools/defense_notice.py verify --config /private/config.json --state /private/defense.json --run ORIGINAL_RUN_UUID --retention-seconds 3600
python3 tools/defense_notice.py send --config /private/config.json --state /private/defense.json
```

Before its first fallible read, `verify` freezes the selected original run ID. It requires the actual account/project's accepted non-suspicious run, correct attacker/board/time, uploaded evidence metadata, and exact SHA-256 of the server-downloaded log. The log must bind the original challenge and defense. The CLI independently simulates choices with the server seed, and both server score records must equal the computed result. Claimed winner fields, altered bytes/owners, foreign runs, missing evidence or an unfinished game refuse delivery.

Top-N evidence does **not** capture initial-state packages. No such proof is invented here: the trusted original snapshot plus server-bound submitted input log provides the binding. The downloaded log is read in memory, not saved as another history. Only run ID/seed/log hash/verified score/result remain.

The CLI then reads the current defender Inbox revision/time and configurable `freeTextBytes/freeTextRetentionDays`. It prepares exactly `{apiKeyId,userId,operationId,issuedAt,expiresAt,freeText,expectedRevision}` with no attachment. Retention is no more than the explicit request and current policy; there is no hardcoded seven-day assumption. Too-small text policy fails visibly. Complete original JSON is atomically persisted with file and parent-directory fsync before the single POST.

Player B must **read actual Inbox** and verify the server-derived `message:UUID` and text. A's display is not a recipient proof.

## Replay, uncertainty and lifecycle

Stop the CLI and invoke the same `send` command with the same state file for exact replay. It resends the original JSON bytes and validates the server UUIDv3 from original project/player/operation/revision/issued time. It never refreshes revision/times/text, generates replacement IDs or rejects a retained replay merely because policy was lowered.

Lost replies, timeout, scope/refusal/conflict, expiry, missing sources or malformed responses remain `unconfirmed`. Complete originals and any earlier delivery proof remain inspectable **even after expiry**. No age-based deletion or automatic replacement occurs:

```sh
python3 tools/defense_notice.py inspect --state /private/defense.json
```

Each selected defense has one private state file and a lock file. Retain unresolved originals for operator reconciliation. After confirmed delivery and completed acceptance review, retain the small original/confirmation through normal application backup/recovery. There is no automatic pruning, full-payload archive, recurring service or account-wide enumeration. After native acceptance the consumed ticket is dropped; the original choices stay until an actual SDK evidence-upload confirmation. A failed upload can explicitly retry only that same requested log, including after restart. After upload confirmation the raw choices are dropped, and the player can acknowledge the small completed local run explicitly. This local ACK never claims trusted delivery. Unknown starts/submits/uploads are not cleared. Never erase another player's/application's storage.

## Explicit costs

| Successful logical flow | Requests |
|---|---:|
| Defender usage + conditional create | 2 |
| Opponent sample + exact defense GET | 2 |
| Existing VA start + submit + requested evidence upload | 3 |
| Trusted original defense GET | 1 |
| Accepted-run lookup + evidence metadata + log download | 3 |
| Defender Inbox snapshot + one ordinary delivery | 2 |
| Actual recipient Inbox read | 1 |
| **Total** | **14** |

An explicit map page adds one GET. Notice replay adds one POST; another recipient read adds one GET. Failures stop early. These are logical API calls, not guessed Mongo command counts or timings. Actual SDK wire retries/cadence must be measured separately; the trusted CLI never retries automatically.

Only existing explicit defense, VA evidence and ordinary Inbox mechanisms store server data. This recipe adds zero login/save hot-path reads, zero backend changes, zero recurring workload and no player/account reserve. Local pending data contains bounded IDs/digests, small game parameters and required original input until definite acceptance; companion storage never contains full defense/evidence blobs. Actual byte sizes/HTTP totals/runtime results remain pending until measured.

## Checks

`python3 tests/test_defense_notice.py` performs real local HTTP tests: committed/lost reply and identical retry, independent simulation, foreign/wrong proof, changed digest, policy beyond seven days, immutable originals, malformed response, partial state and refusal/expiry retention.

`python3 tests/run_feature_lab_checks.py` imports the complete fresh project, runs that CLI suite, constructs the actual panel offline and checks Python/native simulation goldens alongside all existing Game/Hello checks. Loopback evidence is separate from actual Develop acceptance. This documentation does not claim a hosted result.
