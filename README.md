# horizOn Example — Godot

**Seagull Storm** is a compact survival roguelike demonstrating the core [horizOn](https://horizon.pm) SDK managers. It runs immediately in offline practice and adds optional cloud features when configured. This source revision targets and is tested with Godot 4.7.

## Features Demonstrated

Play immediately using **Play offline practice**. Configuration and an account are
optional for gameplay. Practice coins/upgrades/highscores use their own local file;
online caches are scoped to the signed-in player and never import practice scores.

| SDK manager | In-game operation | Verification boundary |
|---|---|---|
| Authentication | Guest restore/sign-in; email sign-in/sign-up; sign-out | Synthetic loopback SDK transport; OAuth providers need platform setup |
| Leaderboards | Board picker, `validatedOnly`, Top 10, around-me ±5, player rank, ordinary submit | Loopback transport/model checks; live board contents not written |
| Cloud Save | Player-bound JSON progress, local cache, sync after run/purchase | Authenticated loopback load/save; writes pause if initial cloud load fails |
| Remote Config | Game balance and validated-run defaults | Loopback scalar config and built-in gameplay defaults |
| News | SDK lab and pause menu feed | Current SDK `message` model parsed against loopback |
| Gift Codes | Read-only V2 preparation, explicit confirmation, durable original tuple and exact Int64 sequence strings | Synthetic loopback lost responses/restart/same-original replay; server rewards never alter practice coins |
| Feedback | Explicit in-game title/message/category submission | Synthetic loopback request only |
| User Logs | Run summary; explicit diagnostic button | Synthetic loopback request only |
| Crash Reporting | Session registration, breadcrumbs and custom keys | Synthetic loopback session; no forced crash |
| Localization | EN/DE language action loads SDK keys and changes launch label | Actual UI label tested with synthetic `seagull.play` translation |
| Player Profile | Own display name/run stats, catalog, unlocked avatar equip | Synthetic loopback get/set, locked choices omitted |
| Validated Actions | Ticket/seed, bounded input evidence, submit/rejection, evidence status, server values | Synthetic loopback accepted/rejected/evidence paths; no authoritative replay claim |
| Player Values | Read balances/offers, explicit purchase and +1 adjustment, persistent original-intent retry | Native loopback transport plus immutable-intent/restart/project/corruption guards; balances stay separate from practice coins |
| Statistics | Completed online rounds/kills/best-score, explicit snapshot/report, durable original-batch retry | Native loopback booked/lost-response/replay and project/player/restart/int64 guards; practice stays local |
| Email Sending | Optional configured template queue to own email account and email status lookup | Synthetic loopback only; no real email sent in QA |
| Achievements | Current definitions/progress, explicit manual unlock and legacy reward reconciliation | Actual official sample methods; no local achievement reward addition |
| Friends / Groups | Current retained relationships/memberships, explicit pages and original revision/request actions | Durable local original blocks replacement through uncertainty and configuration changes |
| Inbox | Typed source references, current reward inspection and exact-entry claim | Official claim recipe; no historical item/value recreation |
| Inventory | Current instances, catalog pages, offer purchase, equip/deltas/discard | Official original-intent sample, current-state responses and retained data after lowering |
| Marketplace | All ten app routes, listing read/review, create/buy/cancel and protected returns | Stable project UUID; official durable journal/lease and Inventory/Values/Market reconciliation |
| Matches | Current ledger/detail, lifecycle actions and minimal original pending ranked sources | Server revisions/bytes retained; no automatic move, fresh replacement run or historical result reconstruction |
| Shared Objects / Chat | Current collection pages and opaque bytes; explicit channel subscription/plain-text send | Official sample bounds and current capabilities; account keys never enter the game |

The SDK lab is optional and disabled for offline practice. Every external write in
that panel requires its visible in-game action. An anonymous player without an
email cannot queue an email.

## About the Game

You play as a seagull on a beach, surviving waves of crabs, jellyfish, and pirate seagulls. Auto-aim feathers, dash through danger with Space, collect XP shells to choose one of three upgrades, combine four weapons, and defeat the final storm octopus. Rare heart pickups restore 15 HP. Upgrade coins create a reason to come back.

- **Genre:** Vampire Survivors-style auto-attack roguelike
- **Session Length:** 3–5 minutes
- **Art Style:** Shared cel-shaded coastal artwork, square-headed horizOn seagull, dark charcoal UI and warm orange/teal accents
- **Font:** Godot default readable UI font (legacy Press Start 2P retained for compatibility)

The gull and crab use the shared cutout rig in `assets/shared/cutout/rig.json`.
Separate full-canvas parts rotate around authored pivots, with linear filtering
and a contact shadow. Movement controls facing and the walk cycle. Actual weapon
fire, melee attacks and damage trigger attack and hurt poses. Pausing freezes
the rig clock and individual limbs. The walk cycle keeps running underneath
attacks while the actor moves. Actor sizes, collision shapes and balance
keep the existing gameplay values.

## Getting Started

### Step 1 — Clone and Open

1. Clone this repository
2. Open the project in **Godot 4.7**

### Step 2 — Optional Online Setup: Account and API Key

1. Go to [horizon.pm](https://horizon.pm) and create a free account
2. Open the **Dashboard** and create a new project
3. Navigate to **Settings > API Keys** and generate an API key
4. Download the config JSON file — it contains your `apiKey` and `backendUrl`

### Step 3 — Import the Config into the SDK

The horizOn SDK is already included in this project at `addons/horizon_sdk/`.

1. In the Godot editor, go to **Project > Tools > horizOn: Import Config...**
2. Select the config JSON file you downloaded from the dashboard
3. The SDK saves the config to `addons/horizon_sdk/horizon_config.tres`. This file holds
   your API key and is ignored by Git, so it stays on your machine. Until it exists, the
   SDK logs "Config not found" and the title screen cannot connect.

You can also play without importing a config: choose **Play offline practice**.
There is no retry loop or blocked title screen when configuration is missing.

If the menu entry is not visible, make sure the plugin is enabled:
**Project > Project Settings > Plugins > horizOn SDK > Enable**

### Step 4 — Set Up Remote Config (Optional)

The game works out of the box with built-in defaults. To customize the game balance, set up Remote Config variables in the horizOn Dashboard under **Remote Config**. See the [Remote Config Reference](#remote-config-reference) below for all available keys.

### Step 5 — Run

Press **F5** or click **Run Project** in the Godot editor.

## SDK Source and Verification

Embedded SDK: complete merged Develop snapshot `1bf60decc35712daa531f29a44573ffbf94b2b3b`, including all current compact feature contracts and configurable-limit readers. `SDK-SOURCE.json` records the 140 official file hashes; `python3 tests/verify_sdk_source.py` checks them. Generated Godot UID/import companions are separate. This pin creates no SDK release. Existing primary-checkout commits and editor changes remain separately backed up and untouched.

The current feature lab reuses the official SDK examples. No network action runs when a panel or Hello scene opens. Choose a read, inspect its state, then explicitly confirm a write. Empty definitions and unsupported capabilities remain visible. Marketplace asks for the stable project UUID once per API project key; regional host changes do not replace pending ownership. Pending originals, expired operations and migration refusals require reconciliation instead of a new identifier.

Group member pages accept the current configured size; Group/Friends pending timestamps may be unknown. Retained lists and exact metadata remain readable after lowering current limits. Match state accepts its physical 14,648 KiB envelope, Shared Objects its 1 MiB envelope; those technical shapes are separate from SystemConfig product quotas. The minimal pending Match reference permits only recovery of its original final revision/run, without reconstructing historical items or results.

The Player Values action opens even offline to explain its guarded state. Online, read the snapshot and offers, inspect costs/rewards, then choose a purchase or an enabled +1 adjustment. One immutable project/player-bound command is saved before HTTP. Guest connection restores a saved anonymous identity first and fails closed if that restore is temporarily unavailable. A lost response or `OPERATION_EXPIRED` retains its original ID and payload; a new click cannot replace it. An unreadable pending file blocks replacement and remains available for reconciliation. Server state replaces the displayed balances; no local reward delta is added. Before a new purchase the panel fetches offers again; changed offers require another explicit confirmation. Persistence binds to project/player across regional host changes, while request fences also include host/session. A definitive no-write refusal may release only a first-send command with an authoritative state; a durable attempt marker and actual transport-event count protect older attempts and internal retries. The API purchases an offer key at current server conditions, so this client refresh is not a transactional quoted-price guarantee.

On macOS with Godot 4.7:

```bash
python3 tests/verify_sdk_source.py
python3 tests/run_checks.py
python3 tests/run_feature_lab_checks.py
python3 tests/run_checks.py --render
Godot --headless --editor --path . --import --quit
Godot --headless --path . --export-release macOS exports/SeagullStorm.zip
# Full macOS verification, including the exported native executable:
python3 tests/verify_macos_export.py
```

The test runner copies the project without secrets to `tmp/qa-project`, uses its
own unique `horizon-task913-godot-qa-<run>` userdata directory, and exercises real SDK transport
against an ephemeral **127.0.0.1-only synthetic HTTP server**. It checks player
physics, dash, pause/resume, XP/weapon choices, real waves/kills, victory, boss
spawn/defeat, duplicate end protection, upgrades and replay. It checks protected
SDK requests carry the fixture player session; test emails never leave loopback.
Generated exports, logs and captures are ignored by Git.
The cutout fixture also checks individual limb transforms, real gameplay attack
and hurt hooks, facing, pause, death cleanup and absence of a full static sprite.
Each fixture invocation removes only its own unique QA userdata directory. The
macOS export verifier also removes its temporary project and instrumented app,
while preserving the normal ZIP, logs and captures under `tmp/verification-artifacts`.
The fixture also verifies balances/offers, three requests retaining one original purchase ID after lost responses, an explicit adjustment, and unchanged practice/cloud coins. Pending-intent restart/project/corruption guards run offline.
The fixture also checks account-switch isolation, stale config/cloud responses,
serialized cloud snapshots, authentication across recreated title screens,
ticket failure while controls change, early/stale evidence events and log limits.

A native macOS ZIP export requires the official Godot macOS export template. The
provided preset disables code signing for local testing. Distribution signing and
notarization are separate release steps. `--export-pack` also builds a PCK usable
with the matching Godot runtime.

## Session Statistics and standalone Hello

In the Dashboard configure `rounds` and `kills` as **sum**, and `best_score` as
**max**, each with reset **none**. Optional `maxPerUpdate` must cover the entire
queued batch. These client-reported metrics do not replace authoritative
Validated Actions or award balances.

Every completed online run persists one local aggregate before result navigation.
Open **SDK lab > Statistics**, choose **Read snapshot**, then **Report runs**.
The display shows the server revision, definition version, `hasValue` and period.
A snapshot read never clears an uncertain batch. **Retry original** uses its exact
saved ID and payload; timeout, expiry, out-of-order rejection and corruption never
create a replacement. Later rounds wait in a separate aggregate until the original
batch is confirmed. Practice rounds never enter the online queue. A configuration
mode/bound mismatch leaves the aggregate intact for reconciliation.

A binary Variant file preserves int64 exactly and is scoped to the API project,
player and example namespace. Host/session belong to the request fence and do not
change pending ownership during regional failover. Atomic directory locks serialize queue mutations across game processes. Interrupted
writes and stale locks remain blocked for manual reconciliation rather than
overwriting unknown state. Queued rounds are reported against
the current server definitions after an explicit read; counters must retain the
same intended meaning. Catalog changes and expired intents need operator/game
reconciliation; the sample offers no discard/rebook shortcut or quoted-time rule.

Open `examples/hello_features/hello_features.tscn` and press **F6** for the complete current Hello: connect/restore explicitly, choose an official sample read, then confirm one reviewed action. It shares the protected Gift V2 and feature-lab integrations with the game. `examples/public_marketplace/marketplace_demo.gd` is the unchanged public quickstart: one explicit listing read and one explicit reviewed purchase through the SDK's durable helper.

Open `examples/hello_statistics/hello_statistics.tscn` and press **F6** for a minimal
standalone Hello. It makes no automatic requests. Connect/restore the guest, queue
an explicit sample round, then read/report. It uses the same protected authentication
and batching code with a separate `hello` namespace. This scene is separate from the
vendored SDK examples, which remain byte-identical to the pinned SDK source.

The native fixture books a batch and loses two responses, retries the exact original,
then reports a later aggregate once. It verifies values beyond 32-bit and near the
safe-integer limit. These are synthetic loopback proofs, not a live cloud write.

## Known Limitations

- There is no dedicated QA backend/key in the checked workspace. Production API
  writes were not used for testing. Loopback fixtures verify transport and game
  integration, but do not prove customer backend configuration or provider delivery.
- Google/Apple OAuth needs the SDK's platform-specific setup. This compact title
  provides guest and email flows; it does not open incomplete OAuth requests.
- Localization changes the launch action and uses SDK translation keys, with EN/DE
  fallback. It is a small integration example, not a complete translated game.
- Email templates, cosmetics, gift codes, server values and validated board rules
  must be configured for your API key in the dashboard.
- Score acceptance means the server accepted configured rules. The client input
  log is review evidence; it does not establish an authoritative deterministic replay.
- This refresh does not constitute full TASK-615 production integration readiness.

## Validated Actions

Validated Actions lets the server check a run before the score reaches the leaderboard.
At run start the game asks for a single-use run ticket bound to the leaderboard and seeds
its random numbers with the server seed. During the run it records a compact input log.
At game over it submits the score with the SHA-256 hash of that log. The server checks the
ticket and your rules (score limits, minimum duration, score per second, stage rules)
before it writes anything, and asks for the log itself when the run lands in the top N.

The integration lives in `scripts/systems/validated_run_recorder.gd` and is used by
`GameManager.start_run()` and `GameManager.end_run()`.

**Availability.** The integration only activates when the bundled SDK has
`Horizon.validatedActions` (the first horizOn SDK for Godot release that ships Validated
Actions, TASK-883). The project bundles the exact Develop snapshot described above. Select a board and request validation in the hub;
a validated-only board forces validation. A standard online run uses ordinary submit.

### Dashboard Setup

1. **Rules:** open **Validated Actions** in the horizOn Dashboard, pick your API key and
   set the rules. Seagull Storm's score is kills + collected XP + survived seconds, so a
   starting point is `minDurationSeconds: 20`, `maxScorePerSecond: 50` and a `maxScore`
   that fits your balancing. Rules stay on the server and never reach the game.
2. **Validated-only board:** open **Leaderboards**, edit the board the game uses
   (`default` unless you set `validated_runs_board`) and turn on **Validated submissions
   only**. From then on the board refuses normal submits (`VALIDATED_SUBMIT_REQUIRED`).
3. **Top N evidence:** on the same board set how many top places need evidence
   (`evidenceTopN`). Runs that land there upload their input log automatically, and you
   can review them in the dashboard.
4. **Stages (optional):** the game sends the reached wave as stage key `wave_<n>`
   (for example `wave_4`). Add stage rules with these keys if you want limits per wave.

### Enabling It in the Game

Set these Remote Config keys in the dashboard:

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| `validated_runs_enabled` | bool | `false` | Enable validation by default in the hub; the player can choose standard runs on ordinary boards |
| `validated_runs_board` | string | `default` | Initial leaderboard key; the hub board picker can select another board |
| `validated_runs_send_coins` | bool | `false` | Also send the coins of the run as earned value `coins`. Turn on only when your rules define a `coins` value, otherwise the server rejects the run (`UNKNOWN_VALUE_KEY`) |

If a requested run ticket cannot be issued, the run switches to the independent
practice save and default balance before it starts. Its rewards and score stay local. A rejected validated submit is never retried through ordinary submit. A rejected run
shows a short reason on the game over screen, for example "Score not accepted: run was too
short".
Score acceptance and evidence upload are displayed separately. If the bounded
input log fills up, the ticket is discarded and the score stays local rather than
submitting incomplete evidence.

### Input Log Format

The log is at most 32 KB (a full run uses a few kilobytes). All numbers are little endian.

| Part | Bytes | Content |
|------|-------|---------|
| Header | 5 | format version `1` (u8), run seed (u32) |
| Event | 3 | physics ticks since the previous event (u16), event code (u8) |

Event codes: `0x00` to `0x0F` movement (bit 0 left, bit 1 right, bit 2 up, bit 3 down,
written when the direction changes), `0x10` to `0x1F` level-up choice (low 4 bits are the
button index), `0xFF` run end. Event `0x20` records a dash. The game is not fully deterministic (frame timing), so
the log serves as evidence for review, not for an exact replay.

## Remote Config Reference

All values are optional — the game ships with sensible built-in defaults. Set these in the horizOn Dashboard under **Remote Config** to customize the game balance without updating the client.

### General

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| `run_duration_seconds` | float | `180.0` | Duration of a survival run in seconds before the boss spawns |
| `boss_wave_enabled` | bool | `true` | Whether a boss wave spawns when the timer runs out |
| `coin_divisor` | int | `10` | Score is divided by this value to calculate coins earned |
| `xp_level_curve` | float | `1.4` | XP-to-next-level scaling exponent (higher = steeper curve) |
| `xp_per_kill_base` | int | `10` | Base XP unit for the level curve. Reaching level 2 requires 5x this value (50 XP by default); later levels scale by `xp_level_curve` |

### Wave Spawning

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| `wave_interval_seconds` | float | `10.0` | Seconds between enemy waves |
| `wave_enemy_count_base` | int | `6` | Number of enemies in the first wave |
| `wave_enemy_count_growth` | float | `1.2` | Enemy count multiplier per wave (e.g. 1.3 = +30% each wave) |
| `wave_boss_hp` | float | `500.0` | Boss hit points (overrides `enemy_boss_hp`) |

### Enemy Stats

Each enemy type (`crab`, `jellyfish`, `pirate`) has four config keys following the pattern `enemy_{type}_{stat}`:

| Key Pattern | Type | Default | Description |
|-------------|------|---------|-------------|
| `enemy_{type}_hp` | int | `30` | Hit points |
| `enemy_{type}_speed` | float | crab `62`, jellyfish `52`, pirate `91`, boss `68` | Movement speed (pixels/sec) |
| `enemy_{type}_damage` | int | `10` | Melee attack damage |
| `enemy_{type}_xp` | int | `10` | XP dropped on death |

**Example keys:** `enemy_crab_hp`, `enemy_jellyfish_speed`, `enemy_pirate_damage`

### Weapon Stats

Each weapon type (`feather`, `screech`, `dive`, `gust`) has config keys following the pattern `weapon_{type}_{stat}`:

| Key Pattern | Type | Default | Description |
|-------------|------|---------|-------------|
| `weapon_{type}_damage` | float | feather `20`, screech `18`, dive `50`, gust `10` | Base damage per hit |
| `weapon_{type}_cooldown` | float | feather `0.8`, screech `2.2`, dive `3.0`, gust `2.5` | Seconds between attacks |
| `weapon_{type}_projectiles` | int | `1` | Number of projectiles (feather only) |
| `weapon_{type}_radius` | float | `80.0` | AoE radius (screech only) |
| `weapon_{type}_range` | float | `120.0` | Dash range (dive only) |
| `weapon_{type}_knockback` | float | `60.0` | Knockback force (gust only) |

**Example keys:** `weapon_feather_damage`, `weapon_screech_cooldown`, `weapon_dive_range`

### Upgrade System

Each upgrade type (`speed`, `damage`, `hp`, `magnet`) has three config keys:

| Key Pattern | Type | Default | Description |
|-------------|------|---------|-------------|
| `upgrade_{type}_max` | int | `5` | Maximum upgrade level |
| `upgrade_{type}_costs` | JSON array | `[10, 25, 50, 100, 200]` | Coin cost per level (array index = level) |
| `upgrade_{type}_values` | JSON array | *(see below)* | Stat value at each level (array index = level) |

**Default upgrade values:**

| Upgrade | Values (level 0–5) |
|---------|---------------------|
| `speed` | `[1.0, 1.1, 1.2, 1.3, 1.4, 1.5]` (multiplier) |
| `damage` | `[1.0, 1.15, 1.3, 1.5, 1.75, 2.0]` (multiplier) |
| `hp` | `[100, 120, 140, 170, 200, 250]` (max HP) |
| `magnet` | `[50, 65, 80, 100, 120, 150]` (pickup radius in px) |

**Example keys:** `upgrade_speed_max`, `upgrade_damage_costs`, `upgrade_hp_values`

### Level-Up Choices

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| `levelup_choices` | int | `3` | Number of choices shown on level up |
| `levelup_pool` | JSON array | *(built-in pool)* | Pool of available upgrades with weighted random selection |

**`levelup_pool` format** — each entry is an object with `id`, `type`, and `weight`:
```json
[
  {"id": "feather_dmg",   "type": "weapon_upgrade", "weight": 3},
  {"id": "feather_speed", "type": "weapon_upgrade", "weight": 2},
  {"id": "screech_new",   "type": "weapon_new",     "weight": 1},
  {"id": "dive_new",      "type": "weapon_new",     "weight": 1},
  {"id": "gust_new",      "type": "weapon_new",     "weight": 1},
  {"id": "move_speed",    "type": "stat_boost",     "weight": 2},
  {"id": "max_hp",        "type": "stat_boost",     "weight": 2},
  {"id": "xp_magnet",     "type": "stat_boost",     "weight": 1}
]
```

## Project Structure

```
addons/horizon_sdk/    # horizOn SDK addon (auto-updated)
assets/                # Sprites, fonts, audio
scenes/                # Godot scenes (.tscn)
scripts/
  autoloads/           # GameManager, AudioManager, ConfigCache
  entities/            # Player, EnemyBase, Crab, Jellyfish, Pirate, Boss
  weapons/             # WeaponBase, Feather, Screech, Dive, Gust
  systems/             # WaveSpawner, ValidatedRunRecorder
  pickups/             # XP Shell
  data/                # GameData, RunState
resources/             # Theme, configurations
project.godot          # Project configuration
```

## Requirements

- [Godot Engine 4.5 or later](https://godotengine.org/) (the horizOn SDK requires 4.5; the project was last checked with Godot 4.7)
- [horizOn Account](https://horizon.pm) (optional for online SDK features)
- [horizOn SDK for Godot](https://github.com/ProjectMakersDE/horizOn-SDK-Godot)

## Related Projects

- [horizOn-SDK-Godot](https://github.com/ProjectMakersDE/horizOn-SDK-Godot) — The SDK this example uses
- [horizOn-Example-Unity](https://github.com/ProjectMakersDE/horizOn-Example-Unity) — Same game in Unity
- [horizOn-Example-Unreal](https://github.com/ProjectMakersDE/horizOn-Example-Unreal) — Same game in Unreal Engine

## License

[MIT](LICENSE). The bundled Press Start 2P font is licensed under the SIL Open Font License 1.1,
see [THIRD-PARTY-NOTICES.md](THIRD-PARTY-NOTICES.md).
