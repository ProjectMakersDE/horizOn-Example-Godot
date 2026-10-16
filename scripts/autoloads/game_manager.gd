## Game Manager - Global game state, save data, scene transitions
extends Node

signal coins_changed(new_amount: int)
signal highscore_changed(new_score: int)
signal submission_changed
signal cloud_write_finished
signal cloud_load_finished
signal locale_changed
signal auth_finished
var _auth_busy := false
var language := "en"
var translations: Dictionary = {}

var practice_mode: bool = true
var selected_board: String = "default"
var validation_requested: bool = false
var submission_status: String = "Local practice"
var cloud_status: String = "Local save"
var _cloud_ready: bool = false
var _cloud_load_failed: bool = false
var _cloud_loading: bool = false
var _cloud_saving: bool = false
var _save_path: String = "user://practice_save.json"

var save_data: GameData = GameData.new()
var run_state: RunState = RunState.new()
## Validated Actions: ticket, input log and validated submit of the current run
var validated_run: ValidatedRunRecorder = ValidatedRunRecorder.new()

## Consecutive wave-1 deaths for WARN log
var _consecutive_wave1_deaths: int = 0

## Guards end_run() against double entry (e.g. player dies while the
## boss-kill end_run is still awaiting network calls)
var _run_ending: bool = false
var _online_finishing: bool = false

## Guards start_run() while the run ticket is requested (double click)
var _run_starting: bool = false
var _navigation_generation: int = 0
var _run_validation_requested: bool = false
var _run_board: String = "default"
var _run_statistics: StatisticsRunStore
var statistics_status := "Online run statistics wait for an explicit report."


func _ready() -> void:
	Horizon.sdk_connected.connect(_on_sdk_connected)
	Horizon.cloudSave.data_load_failed.connect(func(_error): _cloud_load_failed = true)


func _on_sdk_connected(_host: String) -> void:
	await Horizon.crashes.register_session()


## Practice and cloud caches never share a save file or economy.
func enter_practice() -> void:
	_navigation_generation += 1
	validated_run.cancel()
	practice_mode = true
	validation_requested = false
	_cloud_ready = false
	_save_path = "user://practice_save.json"
	save_data = GameData.new()
	_load_local()
	ConfigCache.reset()
	cloud_status = "Practice progress saved locally."

func enter_online() -> void:
	_navigation_generation += 1
	validated_run.cancel()
	practice_mode = false
	save_data = GameData.new()
	var user := Horizon.getCurrentUser()
	_save_path = "user://online_%s.json" % user.userId.sha256_text().substr(0, 16)
	_load_local()
	_cloud_ready = false
	ConfigCache.reset()

func online_available() -> bool:
	return not practice_mode and Horizon.isConnected() and Horizon.isSignedIn()

## The SDK updates its global user after authentication. Serialize operations
## across title instances so a late request cannot replace a newer account.
func authenticate(mode: String, email: String = "", password: String = "", display_name: String = "") -> bool:
	var generation := _navigation_generation
	while _auth_busy:
		await auth_finished
		if generation != _navigation_generation:
			return false
	_auth_busy = true
	var connected: bool = Horizon.isConnected() or await Horizon.connect_to_server()
	if not connected or generation != _navigation_generation:
		return _auth_complete(false)
	var ok := false
	if mode == "create":
		ok = await Horizon.auth.signUpEmail(email, password, display_name)
	elif mode == "email":
		ok = await Horizon.auth.signInEmail(email, password)
	else:
		var stored := _stored_guest_identity()
		var had_identity := Horizon.auth.isSignedIn() or not stored.is_empty()
		if Horizon.auth.isSignedIn():
			ok = await Horizon.auth.checkAuth()
		if generation != _navigation_generation:
			return _auth_complete(false)
		# Read without the legacy SDK getter, which deletes overlong cached tokens.
		# Invalid or damaged identities stay available for manual reconciliation.
		var token: Variant = stored.get("token")
		if not ok and token is String and not token.is_empty() and token.length() <= 32:
			ok = await Horizon.auth.signInAnonymous(token)
		if generation != _navigation_generation:
			return _auth_complete(false)
		# A transient restore failure must not replace an identity owning pending value operations.
		if not ok and not had_identity:
			ok = await Horizon.auth.signUpAnonymous(display_name if not display_name.is_empty() else "Seagull_%d" % (randi() % 9999))
	return _auth_complete(ok and generation == _navigation_generation)

func _stored_guest_identity() -> Dictionary:
	var cache := ConfigFile.new()
	var loaded := cache.load("user://horizon_cache.cfg")
	if loaded == ERR_FILE_NOT_FOUND:
		return {}
	if loaded != OK:
		return {"damaged": true}
	return {"token": cache.get_value("cache", HorizonAuth.CACHE_KEY_ANONYMOUS_TOKEN)} if cache.has_section_key("cache", HorizonAuth.CACHE_KEY_ANONYMOUS_TOKEN) else {}

func _auth_complete(ok: bool) -> bool:
	_auth_busy = false
	auth_finished.emit()
	return ok

func auth_in_progress() -> bool:
	return _auth_busy

func _load_local() -> void:
	if FileAccess.file_exists(_save_path):
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(_save_path))
		if parsed is Dictionary:
			save_data = GameData.from_dict(parsed)

func save_local() -> void:
	var file := FileAccess.open(_save_path, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(save_data.to_dict()))

func state_generation() -> int:
	return _navigation_generation

func state_owner() -> String:
	return "practice" if practice_mode else (Horizon.getCurrentUser().userId if Horizon.isSignedIn() else "signed-out")

func _same_context(generation: int, owner: String) -> bool:
	return generation == _navigation_generation and owner == state_owner()

func load_save_data() -> void:
	if not online_available():
		cloud_status = "Practice progress is saved on this device."
		return
	var generation := _navigation_generation
	var owner := state_owner()
	# SDK failure signals have no request ID; serialize loads so an old error
	# cannot poison a new player's request.
	while _cloud_loading:
		await cloud_load_finished
		if not _same_context(generation, owner):
			return
	_cloud_loading = true
	_cloud_load_failed = false
	var data: Dictionary = await Horizon.cloudSave.loadObject()
	var failed := _cloud_load_failed
	_cloud_loading = false
	cloud_load_finished.emit()
	if not _same_context(generation, owner):
		return
	_cloud_ready = not failed
	if not data.is_empty():
		save_data = GameData.from_dict(data)
		save_local()
	cloud_status = "Cloud save loaded" if _cloud_ready else "Cloud load failed — using player cache; cloud writes paused."
	coins_changed.emit(save_data.coins)
	highscore_changed.emit(save_data.highscore)

func can_mutate_progress() -> bool:
	return practice_mode or (online_available() and _cloud_ready and not _cloud_loading)

func save_data_to_cloud() -> bool:
	save_local()
	if practice_mode:
		cloud_status = "Practice progress saved locally."
		return true
	var generation := _navigation_generation
	var owner := state_owner()
	# Full snapshots must arrive in order. Waiting writers use the latest
	# snapshot once the previous request finishes, coalescing rapid purchases.
	while _cloud_saving:
		await cloud_write_finished
		if not _same_context(generation, owner):
			return false
	if not online_available() or not _cloud_ready:
		cloud_status = "Local player cache saved; cloud writes paused until a successful load."
		return false
	_cloud_saving = true
	var ok := await Horizon.cloudSave.saveObject(save_data.to_dict())
	_cloud_saving = false
	if _same_context(generation, owner):
		cloud_status = "Cloud save synced" if ok else "Cloud save failed; local player cache kept."
		submission_changed.emit()
	cloud_write_finished.emit()
	return ok and _same_context(generation, owner)


## Scene transitions
func go_to_hub() -> void:
	_navigation_generation += 1
	validated_run.cancel()
	Horizon.crashes.record_breadcrumb("navigation", "entered_hub")
	get_tree().change_scene_to_file("res://scenes/hub/hub_screen.tscn")


func go_to_title() -> void:
	_navigation_generation += 1
	validated_run.cancel()
	Horizon.crashes.record_breadcrumb("navigation", "entered_title")
	get_tree().change_scene_to_file("res://scenes/title/title_screen.tscn")


func start_run() -> void:
	if _run_starting or _online_finishing:
		return
	_run_starting = true
	var requested_generation := _navigation_generation
	var requested_validation := validation_requested
	var requested_board := selected_board
	# Validated Actions: request a run ticket and seed the RNG before the run
	# scene builds the ground and spawns enemies. Failed tickets stay local.
	await validated_run.begin()
	_run_starting = false
	if requested_generation != _navigation_generation:
		validated_run.cancel()
		return
	_run_ending = false
	_run_validation_requested = requested_validation
	_run_board = requested_board
	validation_requested = requested_validation
	selected_board = requested_board
	if requested_validation and not validated_run.is_active():
		# Validation was requested: failed ticket runs use the independent practice
		# economy and default balance, with no account rewards or cloud writes.
		enter_practice()
	_run_statistics = StatisticsRunStore.new(Horizon.getConfig().api_key, Horizon.getCurrentUser().userId) if online_available() else null
	run_state = RunState.new()
	run_state.playerMaxHP = int(get_upgrade_value("hp"))
	run_state.playerHP = run_state.playerMaxHP
	save_data.totalRuns += 1
	save_local()
	submission_status = "Run ticket active" if validated_run.is_active() else ("Local practice" if practice_mode else (validated_run.last_message + " · local score only" if validation_requested else "Standard online run"))
	Horizon.crashes.record_breadcrumb("navigation", "entered_run")
	get_tree().change_scene_to_file("res://scenes/run/survival_run.tscn")


func end_run(victory: bool = false) -> void:
	if _run_ending:
		return
	_run_ending = true
	_online_finishing = not practice_mode
	run_state.victory = victory
	get_tree().paused = false
	# Include the final physics tick's kill and collected XP before rewards.
	run_state.currentScore = run_state.kills + run_state.xpCollected + int(run_state.duration)
	if _run_statistics != null and online_available():
		var current := StatisticsRunStore.new(Horizon.getConfig().api_key, Horizon.getCurrentUser().userId)
		if current.scope_hash == _run_statistics.scope_hash:
			statistics_status = "Run statistics queued; report them in the SDK lab." if _run_statistics.queue_run(run_state.kills, run_state.currentScore) else "Statistics queue needs reconciliation; existing data retained."
	var divisor := maxi(ConfigCache.get_int("coin_divisor", 10), 1)
	run_state.coinsEarned = int(run_state.currentScore / divisor)
	save_data.coins += run_state.coinsEarned
	if run_state.currentScore > save_data.highscore:
		save_data.highscore = run_state.currentScore
		highscore_changed.emit(save_data.highscore)
	coins_changed.emit(save_data.coins)
	save_local()
	submission_status = "Saved locally — no leaderboard submission." if practice_mode else "Submitting score…"
	# Show results immediately; global manager owns the asynchronous SDK work.
	get_tree().change_scene_to_file("res://scenes/game_over/game_over_screen.tscn")
	await get_tree().process_frame
	await _finish_online()

func _finish_online() -> void:
	if practice_mode:
		_online_finishing = false
		submission_changed.emit()
		return
	if not online_available():
		submission_status = "Connection lost. Local result kept; score not submitted."
	elif validated_run.is_active():
		await validated_run.finish(run_state.currentScore, "wave_%d" % run_state.currentWave, _validated_earned())
		submission_status = validated_run.last_message
	elif _run_validation_requested:
		# A requested validated run is never silently downgraded to a normal score.
		submission_status = validated_run.last_message + " — score stayed local."
	else:
		var ok := await Horizon.leaderboard.submitScore(run_state.currentScore, _run_board)
		submission_status = "Score submitted to %s." % _run_board if ok else "Score refused: %s" % ValidatedRunRecorder.describe_error(Horizon.leaderboard.getLastErrorCode())
	await save_data_to_cloud()
	if online_available():
		await Horizon.userLogs.info("Seagull Storm | score:%d wave:%d level:%d duration:%ds victory:%s mode:%s" % [run_state.currentScore, run_state.currentWave, run_state.currentLevel, int(run_state.duration), str(run_state.victory), "validated" if _run_validation_requested else "standard"])
	_online_finishing = false
	submission_changed.emit()

func is_finishing() -> bool:
	return _online_finishing

func run_ending() -> bool:
	return _run_ending

## Earned values for the validated submit. Coins are sent only when Remote
## Config `validated_runs_send_coins` is true, because the server rejects a
## value key its rules do not define (UNKNOWN_VALUE_KEY).
func _validated_earned() -> Array:
	if not ConfigCache.get_bool("validated_runs_send_coins", false) or run_state.coinsEarned <= 0:
		return []
	return [{"key": "coins", "amount": run_state.coinsEarned}]


## Upgrades — built-in defaults so the game works without remote config
const _DEFAULT_UPGRADE_MAX: int = 5
const _DEFAULT_UPGRADE_COSTS: Array = [10, 25, 50, 100, 200]
const _DEFAULT_UPGRADE_VALUES: Dictionary = {
	"speed": [1.0, 1.1, 1.2, 1.3, 1.4, 1.5],
	"damage": [1.0, 1.15, 1.3, 1.5, 1.75, 2.0],
	"hp": [100.0, 120.0, 140.0, 170.0, 200.0, 250.0],
	"magnet": [50.0, 65.0, 80.0, 100.0, 120.0, 150.0],
}


func _get_upgrade_costs(upgrade_name: String) -> Array:
	var costs = ConfigCache.get_json("upgrade_%s_costs" % upgrade_name)
	if costs is Array and costs.size() > 0:
		return costs
	return _DEFAULT_UPGRADE_COSTS.duplicate()


func _get_upgrade_values(upgrade_name: String) -> Array:
	var values = ConfigCache.get_json("upgrade_%s_values" % upgrade_name)
	if values is Array and values.size() > 0:
		return values
	if _DEFAULT_UPGRADE_VALUES.has(upgrade_name):
		return _DEFAULT_UPGRADE_VALUES[upgrade_name].duplicate()
	return [1.0]


func _get_upgrade_max(upgrade_name: String) -> int:
	var m := ConfigCache.get_int("upgrade_%s_max" % upgrade_name, 0)
	if m > 0:
		return m
	return _DEFAULT_UPGRADE_MAX


func can_afford_upgrade(upgrade_name: String) -> bool:
	if not can_mutate_progress():
		return false
	var current_level: int = save_data.upgrades.get(upgrade_name, 0)
	if current_level >= _get_upgrade_max(upgrade_name):
		return false
	var costs := _get_upgrade_costs(upgrade_name)
	if current_level < costs.size():
		return save_data.coins >= int(costs[current_level])
	return false


func buy_upgrade(upgrade_name: String) -> bool:
	if not can_afford_upgrade(upgrade_name):
		return false
	var current_level: int = save_data.upgrades.get(upgrade_name, 0)
	var costs := _get_upgrade_costs(upgrade_name)
	if current_level < costs.size():
		var cost: int = int(costs[current_level])
		save_data.coins -= cost
		save_data.upgrades[upgrade_name] = current_level + 1
		coins_changed.emit(save_data.coins)
		save_local()
		Horizon.crashes.record_breadcrumb("user_action", "bought_%s_%d" % [upgrade_name, current_level + 1])
		return true
	return false


func get_upgrade_cost(upgrade_name: String) -> int:
	var current_level: int = save_data.upgrades.get(upgrade_name, 0)
	var costs := _get_upgrade_costs(upgrade_name)
	if current_level < costs.size():
		return int(costs[current_level])
	return 0


func get_upgrade_value(upgrade_name: String) -> float:
	var current_level: int = save_data.upgrades.get(upgrade_name, 0)
	var values := _get_upgrade_values(upgrade_name)
	if current_level < values.size():
		return float(values[current_level])
	match upgrade_name:
		"speed": return 1.0
		"damage": return 1.0
		"hp": return 100.0
		"magnet": return 50.0
	return 1.0


func is_upgrade_maxed(upgrade_name: String) -> bool:
	var current_level: int = save_data.upgrades.get(upgrade_name, 0)
	return current_level >= _get_upgrade_max(upgrade_name)


func on_levelup(level: int) -> void:
	Horizon.crashes.record_breadcrumb("state", "level_%d" % level)


func on_wave_started(wave: int) -> void:
	Horizon.crashes.set_custom_key("wave", str(wave))
	Horizon.crashes.set_custom_key("score", str(run_state.currentScore))


func ui_text(key: String, fallback: String) -> String:
	var remote: String = str(translations.get(key, ""))
	if not remote.is_empty():
		return remote
	var german := {"seagull.play": "Überlebensrunde starten", "seagull.upgrades": "Insel-Upgrades", "seagull.practice": "Offline üben"}
	return str(german.get(key, fallback)) if language == "de" else fallback
