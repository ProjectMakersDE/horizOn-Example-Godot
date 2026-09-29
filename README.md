# horizOn Example — Godot

**Seagull Storm** is a mini Vampire Survivors-style roguelike built with Godot 4.5. It serves as an example project demonstrating 9 of the 11 [horizOn](https://horizon.pm) SDK features in a playable game. The SDK's Email Sending and Localization features are not used.

## Features Demonstrated

| # | horizOn Feature | In-Game Usage |
|---|----------------|---------------|
| 1 | **Authentication** | Guest, Email, Apple sign-in/sign-up on title screen (the Google button explains that a platform OAuth flow is required) |
| 2 | **Leaderboards** | Score submission, Top 10 display, player rank |
| 3 | **Cloud Save** | Persistent coins, upgrades, highscore across sessions |
| 4 | **Remote Config** | All game balancing (enemies, weapons, upgrades, wave timing) |
| 5 | **News** | In-game news feed in hub and pause menu |
| 6 | **Gift Codes** | Code redemption for coin rewards |
| 7 | **Feedback** | Bug reports and feature requests from in-game |
| 8 | **User Logs** | Aggregated run summary logged at game over |
| 9 | **Crash Reporting** | Session tracking, breadcrumbs, exception capture |
| + | **Validated Actions** (opt-in) | Run ticket and server seed at run start, input log, validated score submit, rejection reason on the game over screen (see [Validated Actions](#validated-actions)) |

## About the Game

You play as a seagull on a beach, surviving waves of crabs, jellyfish, and pirate seagulls. Auto-attack with upgradeable weapons, collect XP shells to level up, and try to survive the final boss — a giant octopus.

- **Genre:** Vampire Survivors-style auto-attack roguelike
- **Session Length:** 3–5 minutes
- **Art Style:** Pixel art (32x32 sprites) with a 16x16 beach tileset and textured UI atlas
- **Font:** Press Start 2P

## Getting Started

### Step 1 — Clone and Open

1. Clone this repository
2. Open the project in **Godot 4.5** or later

### Step 2 — Create a horizOn Account and API Key

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

If the menu entry is not visible, make sure the plugin is enabled:
**Project > Project Settings > Plugins > horizOn SDK > Enable**

### Step 4 — Set Up Remote Config (Optional)

The game works out of the box with built-in defaults. To customize the game balance, set up Remote Config variables in the horizOn Dashboard under **Remote Config**. See the [Remote Config Reference](#remote-config-reference) below for all available keys.

### Step 5 — Run

Press **F5** or click **Run Project** in the Godot editor.

## Known Limitations

- **Google Sign-In:** the Google button on the title screen only shows "Google Sign-In
  is not available on this platform." The SDK's `signInGoogle()` needs an OAuth
  authorization code from a platform-specific browser or loopback flow, which this
  example does not implement.

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
Actions, TASK-883). With an older SDK in `addons/horizon_sdk/`, or when the feature is
switched off, the game submits scores the normal way.

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
| `validated_runs_enabled` | bool | `false` | Start every run as a validated run. When `false`, the game uses the normal leaderboard submit |
| `validated_runs_board` | string | `default` | Leaderboard key the run ticket is bound to |
| `validated_runs_send_coins` | bool | `false` | Also send the coins of the run as earned value `coins`. Turn on only when your rules define a `coins` value, otherwise the server rejects the run (`UNKNOWN_VALUE_KEY`) |

If the run ticket cannot be issued (for example the backend does not support Validated
Actions), the run continues and the score is submitted the normal way. A rejected run
shows a short reason on the game over screen, for example "Score not accepted: run was too
short".

### Input Log Format

The log is at most 32 KB (a full run uses a few kilobytes). All numbers are little endian.

| Part | Bytes | Content |
|------|-------|---------|
| Header | 5 | format version `1` (u8), run seed (u32) |
| Event | 3 | physics ticks since the previous event (u16), event code (u8) |

Event codes: `0x00` to `0x0F` movement (bit 0 left, bit 1 right, bit 2 up, bit 3 down,
written when the direction changes), `0x10` to `0x1F` level-up choice (low 4 bits are the
button index), `0xFF` run end. The game is not fully deterministic (frame timing), so the
log serves as evidence for review, not for an exact replay.

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
| `wave_interval_seconds` | float | `15.0` | Seconds between enemy waves |
| `wave_enemy_count_base` | int | `5` | Number of enemies in the first wave |
| `wave_enemy_count_growth` | float | `1.3` | Enemy count multiplier per wave (e.g. 1.3 = +30% each wave) |
| `wave_boss_hp` | float | `500.0` | Boss hit points (overrides `enemy_boss_hp`) |

### Enemy Stats

Each enemy type (`crab`, `jellyfish`, `pirate`) has four config keys following the pattern `enemy_{type}_{stat}`:

| Key Pattern | Type | Default | Description |
|-------------|------|---------|-------------|
| `enemy_{type}_hp` | int | `30` | Hit points |
| `enemy_{type}_speed` | float | `40.0` | Movement speed (pixels/sec) |
| `enemy_{type}_damage` | int | `10` | Melee attack damage |
| `enemy_{type}_xp` | int | `10` | XP dropped on death |

**Example keys:** `enemy_crab_hp`, `enemy_jellyfish_speed`, `enemy_pirate_damage`

### Weapon Stats

Each weapon type (`feather`, `screech`, `dive`, `gust`) has config keys following the pattern `weapon_{type}_{stat}`:

| Key Pattern | Type | Default | Description |
|-------------|------|---------|-------------|
| `weapon_{type}_damage` | float | `20.0` | Base damage per hit |
| `weapon_{type}_cooldown` | float | `1.0` | Seconds between attacks |
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
- [horizOn Account](https://horizon.pm) (free tier works)
- [horizOn SDK for Godot](https://github.com/ProjectMakersDE/horizOn-SDK-Godot)

## Related Projects

- [horizOn-SDK-Godot](https://github.com/ProjectMakersDE/horizOn-SDK-Godot) — The SDK this example uses
- [horizOn-Example-Unity](https://github.com/ProjectMakersDE/horizOn-Example-Unity) — Same game in Unity
- [horizOn-Example-Unreal](https://github.com/ProjectMakersDE/horizOn-Example-Unreal) — Same game in Unreal Engine

## License

[MIT](LICENSE). The bundled Press Start 2P font is licensed under the SIL Open Font License 1.1,
see [THIRD-PARTY-NOTICES.md](THIRD-PARTY-NOTICES.md).
