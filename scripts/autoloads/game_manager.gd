## Game Manager - Global game state, save data, scene transitions
extends Node

signal coins_changed(new_amount: int)
signal highscore_changed(new_score: int)

var save_data: GameData = GameData.new()
var run_state: RunState = RunState.new()

## Consecutive wave-1 deaths for WARN log
var _consecutive_wave1_deaths: int = 0


func _ready() -> void:
	Horizon.sdk_connected.connect(_on_sdk_connected)


func _on_sdk_connected(_host: String) -> void:
	await Horizon.crashes.register_session()


## Cloud save
func load_save_data() -> void:
	var data = await Horizon.cloudSave.loadObject()
	if data is Dictionary and not data.is_empty():
		save_data = GameData.from_dict(data)
	coins_changed.emit(save_data.coins)
	highscore_changed.emit(save_data.highscore)


func save_data_to_cloud() -> void:
	await Horizon.cloudSave.saveObject(save_data.to_dict())


## Scene transitions
func go_to_hub() -> void:
	Horizon.crashes.record_breadcrumb("navigation", "entered_hub")
	get_tree().change_scene_to_file("res://scenes/hub/hub_screen.tscn")


func go_to_title() -> void:
	Horizon.crashes.record_breadcrumb("navigation", "entered_title")
	get_tree().change_scene_to_file("res://scenes/title/title_screen.tscn")


func start_run() -> void:
	run_state = RunState.new()
	run_state.playerMaxHP = int(get_upgrade_value("hp"))
	run_state.playerHP = run_state.playerMaxHP
	save_data.totalRuns += 1
	Horizon.crashes.record_breadcrumb("navigation", "entered_run")
	get_tree().change_scene_to_file("res://scenes/run/survival_run.tscn")


func end_run() -> void:
	# Calculate coins earned
	var coin_divisor := ConfigCache.get_int("coin_divisor", 10)
	if coin_divisor <= 0:
		coin_divisor = 10
	run_state.coinsEarned = run_state.currentScore / coin_divisor
	save_data.coins += run_state.coinsEarned

	# Update highscore
	if run_state.currentScore > save_data.highscore:
		save_data.highscore = run_state.currentScore
		highscore_changed.emit(save_data.highscore)

	coins_changed.emit(save_data.coins)

	# Submit score to leaderboard
	await Horizon.leaderboard.submitScore(run_state.currentScore)

	# Save to cloud
	await save_data_to_cloud()

	# User log - run summary
	var duration_str = "%dm%02ds" % [int(run_state.duration) / 60, int(run_state.duration) % 60]
	var upgrades_str = "speed:%d,dmg:%d,hp:%d,mag:%d" % [
		save_data.upgrades.get("speed", 0), save_data.upgrades.get("damage", 0),
		save_data.upgrades.get("hp", 0), save_data.upgrades.get("magnet", 0)
	]
	var log_msg = "Run ended | Waves: %d | Level: %d | Score: %d | Duration: %s | Upgrades: %s | Coins earned: %d" % [
		run_state.currentWave, run_state.currentLevel, run_state.currentScore,
		duration_str, upgrades_str, run_state.coinsEarned
	]
	await Horizon.userLogs.info(log_msg)

	# Track consecutive wave-1 deaths
	if run_state.currentWave <= 1:
		_consecutive_wave1_deaths += 1
		if _consecutive_wave1_deaths >= 3:
			await Horizon.userLogs.warn(
				"Player died in wave 1 three consecutive times - possible balancing issue",
				"BALANCING_WAVE1"
			)
			_consecutive_wave1_deaths = 0
	else:
		_consecutive_wave1_deaths = 0

	Horizon.crashes.record_breadcrumb("state", "run_ended_wave_%d_score_%d" % [run_state.currentWave, run_state.currentScore])
	get_tree().change_scene_to_file("res://scenes/game_over/game_over_screen.tscn")


## Upgrades
func can_afford_upgrade(upgrade_name: String) -> bool:
	var current_level: int = save_data.upgrades.get(upgrade_name, 0)
	var max_level := ConfigCache.get_int("upgrade_%s_max" % upgrade_name, 0)
	if current_level >= max_level:
		return false
	var costs = ConfigCache.get_json("upgrade_%s_costs" % upgrade_name)
	if costs is Array and current_level < costs.size():
		return save_data.coins >= int(costs[current_level])
	return false


func buy_upgrade(upgrade_name: String) -> bool:
	if not can_afford_upgrade(upgrade_name):
		return false
	var current_level: int = save_data.upgrades.get(upgrade_name, 0)
	var costs = ConfigCache.get_json("upgrade_%s_costs" % upgrade_name)
	if costs is Array and current_level < costs.size():
		var cost: int = int(costs[current_level])
		save_data.coins -= cost
		save_data.upgrades[upgrade_name] = current_level + 1
		coins_changed.emit(save_data.coins)
		Horizon.crashes.record_breadcrumb("user_action", "bought_%s_%d" % [upgrade_name, current_level + 1])
		return true
	return false


func get_upgrade_cost(upgrade_name: String) -> int:
	var current_level: int = save_data.upgrades.get(upgrade_name, 0)
	var costs = ConfigCache.get_json("upgrade_%s_costs" % upgrade_name)
	if costs is Array and current_level < costs.size():
		return int(costs[current_level])
	return 0


func get_upgrade_value(upgrade_name: String) -> float:
	var current_level: int = save_data.upgrades.get(upgrade_name, 0)
	var values = ConfigCache.get_json("upgrade_%s_values" % upgrade_name)
	if values is Array and current_level < values.size():
		return float(values[current_level])
	match upgrade_name:
		"speed": return 1.0
		"damage": return 1.0
		"hp": return 100.0
		"magnet": return 50.0
	return 1.0


func is_upgrade_maxed(upgrade_name: String) -> bool:
	var current_level: int = save_data.upgrades.get(upgrade_name, 0)
	var max_level := ConfigCache.get_int("upgrade_%s_max" % upgrade_name, 0)
	return current_level >= max_level


func on_levelup(level: int) -> void:
	Horizon.crashes.record_breadcrumb("state", "level_%d" % level)


func on_wave_started(wave: int) -> void:
	Horizon.crashes.set_custom_key("wave", str(wave))
	Horizon.crashes.set_custom_key("score", str(run_state.currentScore))
