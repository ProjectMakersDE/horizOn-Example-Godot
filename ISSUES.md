# Seagull Storm Godot — Open Issues

These issues were found during a design-doc audit and must be fixed before the project is considered complete.

> **Status 2026-07-02:** All issues below are resolved in code. The only remaining external item is a real platform OAuth flow for Google Sign-In (see G1).

---

## General Issues (shared across all engines)

### G1: Google OAuth is a stub
**Expected:** Functional Google OAuth flow using `Horizon.auth.signUpGoogle()` / `signInGoogle()`.
**Actual:** `_on_google_pressed()` only sets a status text label. No OAuth call is made.
**Acceptance:** The Google button triggers the SDK's Google OAuth methods. If OAuth is not available on the platform, show a proper error message (not "WIP" in the button label).
**RESOLVED (partially, 2026-07-02):** The unreachable dead `signInGoogle()` call was removed; the button now shows a clear in-game message ("Google Sign-In is not available on this platform.") and fires no doomed network request. Still open externally: the SDK's `signInGoogle(code, redirect_uri)` needs an authorization code from a platform-specific browser/loopback OAuth flow, which this example does not implement (the SDK has no built-in Google browser flow, unlike Apple).

### G2: Pause Menu News should use cached data
**Expected:** News loaded once at hub, reused in pause menu from cache.
**Actual:** Pause menu calls `loadNews()` again (uses SDK cache, so no extra request — acceptable but verify).
**Acceptance:** Confirm that the pause menu does NOT trigger an additional network request. If it does, use locally cached data instead.
**RESOLVED:** Verified. The pause menu uses `Horizon.news.getCachedNews()` and only falls back to `loadNews()` when the cache is empty. No extra network request in the normal path.

### G3: Remote Config must only be loaded once per session
**Expected:** `getAllConfigs()` called once at first hub entry, cached for entire app session.
**Actual:** Currently OK in Godot (ConfigCache handles this). Verify no re-fetch on hub re-entry.
**Acceptance:** Returning to hub after a run must NOT re-fetch remote config.
**RESOLVED:** Verified. `ConfigCache.load_all()` returns immediately once `_loaded` is true and ConfigCache is an autoload, so hub re-entry never re-fetches.

---

## Godot-Specific Issues

### GD1: Remote Config key schema mismatch
**Expected (Design Doc):** Flat keys like `enemy_crab_speed = 40`, `enemy_crab_hp = 30`, `weapon_feather_damage = 20`.
**Actual:** Code reads grouped JSON objects like `enemy_crab_stats = {"hp":30,"speed":40,"damage":10,"score":10}`.
**Acceptance:** Either update the code to use flat keys matching the design doc, OR update the design doc to reflect the grouped JSON approach. Choose one and be consistent. Document the actual required Remote Config keys clearly.
**RESOLVED:** Code, README, and the `config_cache.gd` header comment all describe the flat-key schema (`enemy_{type}_{stat}`, `weapon_{type}_{stat}`); `get_json()` is only used for the JSON-array keys (`upgrade_*_costs`, `upgrade_*_values`, `levelup_pool`).

### GD2: Extra getRank() call in hub load
**Expected:** Hub load makes 6 requests (config, save, leaderboard top, news, crash session + auth from title).
**Actual:** Hub also calls `getRank()` — total is 7 requests.
**Acceptance:** Remove the `getRank()` call from hub load. Player rank is shown at Game Over, not in the Hub. The hub leaderboard only needs `getTop(10)`.
**RESOLVED (2026-07-02):** The `getRank()` block and the `_show_user_rank()` helper were removed from `hub_screen.gd`. Rank is shown at Game Over only; hub load is back to the designed request budget.

### GD3: No Seagull Logo on Title Screen
**Expected:** Design layout shows `[Seagull Logo]` above the title text.
**Actual:** Only text labels exist on the title screen.
**Acceptance:** Add a `TextureRect` node for the seagull logo placeholder (can be a simple white rectangle until real art is added). The node must exist and be positioned above the title.
**RESOLVED:** `seagull_logo.png` (128x128 mascot art) is wired into a `TextureRect` above the title label in `title_screen.tscn`.

### GD4: Sprites exist but are unused — everything is ColorRect
**Expected:** Placeholder sprite sheets are wired into scenes (even as simple colored rectangles in the PNG files).
**Actual:** All entities render as `ColorRect` nodes. The PNG sprite files exist but are never referenced.
**Acceptance:** Player, enemies, weapons, and pickups must use `Sprite2D` or `AnimatedSprite2D` nodes that reference the placeholder sprite sheets. The sprite sheets have the correct dimensions and colored placeholder content — they just need to be wired in.
**RESOLVED:** Player, enemies, weapons, and pickups all render via `AnimatedSprite2D` with `AtlasTexture` rows from the mascot sprite sheets. The leftover dead `_enemy_colors` dictionary from the ColorRect era was removed from `wave_spawner.gd` (2026-07-02).

### GD5: No TileMap — ground is a single ColorRect
**Expected:** Ground rendered using a `TileMap` node with `tilemap.png`.
**Actual:** `_generate_ground()` creates a single 2000x2000 `ColorRect`.
**Acceptance:** Replace the ground ColorRect with a `TileMap` node using a `TileSet` sourced from `tilemap.png`. The tilemap should render sand tiles with water edges.
**RESOLVED (2026-07-02):** `_generate_ground()` builds a `TileMapLayer` with a `TileSetAtlasSource` from the real pixel-art `tilemap.png`, registers all 8x4 tiles via `create_tile()`, and paints a sand island: random sand variants (v1 weighted highest) in the interior, a water edge/corner border ring from row 1, and roughly 3% sand decorations (shell/starfish/seaweed/rock).

### GD6: Pickup collection bug — PickupArea signal not connected
**Expected:** Walking into an XP shell collects it.
**Actual:** The player's `PickupArea` (Area2D) has `collision_mask=8` but its `area_entered` signal is never connected. Pickups are only collected via the magnet proximity check. Walking directly into a pickup outside the magnet radius does nothing.
**Acceptance:** Connect the `PickupArea.area_entered` signal to a handler that collects the pickup on direct contact, OR ensure the magnet radius is large enough to cover the player's collision area so direct overlap always triggers collection.
**RESOLVED:** `PickupArea.area_entered` is connected and collects on direct contact. A `_collected` guard was added to `xp_shell._collect()` (2026-07-02) so the magnet path and the area signal cannot grant XP twice in the same frame.

### GD7: feather_speed levelup label mismatch
**Expected:** "Feather+ Speed +15%" should increase projectile speed.
**Actual:** The `weapon_upgrade` handler calls `w.upgrade()` which increases damage +15% and adds a projectile. The label is misleading.
**Acceptance:** Either change the label to match the actual effect ("Feather+ DMG +15%") or implement a separate speed upgrade path for feather_speed that actually increases projectile speed.
**RESOLVED:** `feather_speed` now multiplies the feather weapon's `projectile_speed` by 1.15; `feather_dmg` keeps the damage/projectile upgrade. Labels match their effects.

### GD8: Settings button labeled "Sign Out"
**Expected:** Design layout shows `[Settings]`.
**Actual:** Button text is "Sign Out".
**Acceptance:** Either rename to "Settings" and add a settings panel (with sign-out inside it), or keep "Sign Out" but be consistent with the design. Recommended: rename to "Settings" with a panel that includes volume and sign-out.
**RESOLVED:** The button is labeled "Settings" and opens a settings popup with a music volume slider, a Sign Out button, and Close.

### GD9: Score calculation — enemy score increments overwritten
**Expected:** Clean score calculation.
**Actual:** `enemy_base._die()` increments `currentScore` directly, but `survival_run._process()` overwrites `currentScore` every frame with `_calculate_score()`. The direct increments are discarded.
**Acceptance:** Remove the direct score increment in `enemy_base._die()` since the frame-calculated score already accounts for kills via `kills * xp_per_kill_base`. The score calculation should have a single source of truth.
**RESOLVED:** `enemy_base._die()` only increments `run_state.kills`; the per-frame `_calculate_score()` (kills + XP collected + survival time) is the single source of truth. The unused `score_value` field was removed from `enemy_base.gd` (2026-07-02).

---

## Additional fixes from the 2026-07-02 polish pass

- **Boss end-run:** the boss's `died` signal now ends the run via `GameManager.end_run()`; the wave spawner stops spawning normal waves once the boss is out; the HUD timer clamps at 0:00; with `boss_wave_enabled=false` the run ends cleanly on timer expiry (previously a pseudo player-death hack).
- **xp_magnet levelup boost:** the per-frame magnet check now uses `player.pickup_radius` and the PickupArea collision radius grows with the boost, so the levelup choice has a real effect.
- **Levelup pool dedupe:** `weapon_new` choices whose weapon is already active are filtered out before selection and `_add_weapon()` guards against duplicates.
- **Music looping:** the three music OGG imports set `loop=true`, and `audio_manager.play_music()` also enforces looping at runtime as a fallback.
- **News dates:** hub and pause news items show the title plus the shortened `releaseDate`.
- **Config-driven XP curve:** `xp_per_kill_base` (default 10) now drives the level curve (base x5, so level 2 still needs 50 XP by default); documented in the README config table.
- **Dead code cleanups:** removed the unused `RunTimer` node and its `@onready` var, the dead `_enemy_colors` dictionary, and the unreachable Google sign-in branch.
- **Pixel-art UI:** `game_theme.tres` uses `StyleBoxTexture` button styles (normal/hover/pressed/disabled) and a 9-slice panel from `ui.png`; the theme is applied project-wide; the run HUD HP/XP bars are `TextureProgressBar` nodes with atlas fill/empty regions; levelup choice cards use the upgrade card frame region.
