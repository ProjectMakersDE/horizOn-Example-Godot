# Seagull Storm Godot — Open Issues

These issues were found during a design-doc audit and must be fixed before the project is considered complete.

---

## General Issues (shared across all engines)

### G1: Google OAuth is a stub
**Expected:** Functional Google OAuth flow using `Horizon.auth.signUpGoogle()` / `signInGoogle()`.
**Actual:** `_on_google_pressed()` only sets a status text label. No OAuth call is made.
**Acceptance:** The Google button triggers the SDK's Google OAuth methods. If OAuth is not available on the platform, show a proper error message (not "WIP" in the button label).

### G2: Pause Menu News should use cached data
**Expected:** News loaded once at hub, reused in pause menu from cache.
**Actual:** Pause menu calls `loadNews()` again (uses SDK cache, so no extra request — acceptable but verify).
**Acceptance:** Confirm that the pause menu does NOT trigger an additional network request. If it does, use locally cached data instead.

### G3: Remote Config must only be loaded once per session
**Expected:** `getAllConfigs()` called once at first hub entry, cached for entire app session.
**Actual:** Currently OK in Godot (ConfigCache handles this). Verify no re-fetch on hub re-entry.
**Acceptance:** Returning to hub after a run must NOT re-fetch remote config.

---

## Godot-Specific Issues

### GD1: Remote Config key schema mismatch
**Expected (Design Doc):** Flat keys like `enemy_crab_speed = 40`, `enemy_crab_hp = 30`, `weapon_feather_damage = 20`.
**Actual:** Code reads grouped JSON objects like `enemy_crab_stats = {"hp":30,"speed":40,"damage":10,"score":10}`.
**Acceptance:** Either update the code to use flat keys matching the design doc, OR update the design doc to reflect the grouped JSON approach. Choose one and be consistent. Document the actual required Remote Config keys clearly.

### GD2: Extra getRank() call in hub load
**Expected:** Hub load makes 6 requests (config, save, leaderboard top, news, crash session + auth from title).
**Actual:** Hub also calls `getRank()` — total is 7 requests.
**Acceptance:** Remove the `getRank()` call from hub load. Player rank is shown at Game Over, not in the Hub. The hub leaderboard only needs `getTop(10)`.

### GD3: No Seagull Logo on Title Screen
**Expected:** Design layout shows `[Seagull Logo]` above the title text.
**Actual:** Only text labels exist on the title screen.
**Acceptance:** Add a `TextureRect` node for the seagull logo placeholder (can be a simple white rectangle until real art is added). The node must exist and be positioned above the title.

### GD4: Sprites exist but are unused — everything is ColorRect
**Expected:** Placeholder sprite sheets are wired into scenes (even as simple colored rectangles in the PNG files).
**Actual:** All entities render as `ColorRect` nodes. The PNG sprite files exist but are never referenced.
**Acceptance:** Player, enemies, weapons, and pickups must use `Sprite2D` or `AnimatedSprite2D` nodes that reference the placeholder sprite sheets. The sprite sheets have the correct dimensions and colored placeholder content — they just need to be wired in.

### GD5: No TileMap — ground is a single ColorRect
**Expected:** Ground rendered using a `TileMap` node with `tilemap.png`.
**Actual:** `_generate_ground()` creates a single 2000x2000 `ColorRect`.
**Acceptance:** Replace the ground ColorRect with a `TileMap` node using a `TileSet` sourced from `tilemap.png`. The tilemap should render sand tiles with water edges.

### GD6: Pickup collection bug — PickupArea signal not connected
**Expected:** Walking into an XP shell collects it.
**Actual:** The player's `PickupArea` (Area2D) has `collision_mask=8` but its `area_entered` signal is never connected. Pickups are only collected via the magnet proximity check. Walking directly into a pickup outside the magnet radius does nothing.
**Acceptance:** Connect the `PickupArea.area_entered` signal to a handler that collects the pickup on direct contact, OR ensure the magnet radius is large enough to cover the player's collision area so direct overlap always triggers collection.

### GD7: feather_speed levelup label mismatch
**Expected:** "Feather+ Speed +15%" should increase projectile speed.
**Actual:** The `weapon_upgrade` handler calls `w.upgrade()` which increases damage +15% and adds a projectile. The label is misleading.
**Acceptance:** Either change the label to match the actual effect ("Feather+ DMG +15%") or implement a separate speed upgrade path for feather_speed that actually increases projectile speed.

### GD8: Settings button labeled "Sign Out"
**Expected:** Design layout shows `[Settings]`.
**Actual:** Button text is "Sign Out".
**Acceptance:** Either rename to "Settings" and add a settings panel (with sign-out inside it), or keep "Sign Out" but be consistent with the design. Recommended: rename to "Settings" with a panel that includes volume and sign-out.

### GD9: Score calculation — enemy score increments overwritten
**Expected:** Clean score calculation.
**Actual:** `enemy_base._die()` increments `currentScore` directly, but `survival_run._process()` overwrites `currentScore` every frame with `_calculate_score()`. The direct increments are discarded.
**Acceptance:** Remove the direct score increment in `enemy_base._die()` since the frame-calculated score already accounts for kills via `kills * xp_per_kill_base`. The score calculation should have a single source of truth.
