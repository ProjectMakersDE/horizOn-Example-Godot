## Game Manager - Global game state singleton
extends Node

signal coins_changed(new_amount: int)
signal highscore_changed(new_score: int)

## Persistent data (from cloud save)
var coins: int = 0
var highscore: int = 0
var upgrades: Dictionary = {"speed": 0, "damage": 0, "hp": 0, "magnet": 0}
var total_runs: int = 0
var gift_codes_redeemed: Array = []

## Current run state
var current_score: int = 0
var current_wave: int = 0
var current_level: int = 1
var run_kills: int = 0
var run_xp_collected: int = 0
var run_duration: float = 0.0
var run_coins_earned: int = 0
var run_active: bool = false

## Auth state
var is_signed_in: bool = false
var display_name: String = ""
var user_rank: int = 0
var user_best_rank: int = 0

## Consecutive wave-1 deaths (for WARN log)
var _consecutive_early_deaths: int = 0


func _ready() -> void:
	pass


func start_run() -> void:
	current_score = 0
	current_wave = 0
	current_level = 1
	run_kills = 0
	run_xp_collected = 0
	run_duration = 0.0
	run_coins_earned = 0
	run_active = true


func end_run() -> void:
	run_active = false
	var coin_divisor := ConfigManager.get_int("coin_divisor", 10)
	run_coins_earned = current_score / coin_divisor
	coins += run_coins_earned
	total_runs += 1

	if current_score > highscore:
		highscore = current_score
		highscore_changed.emit(highscore)

	coins_changed.emit(coins)

	# Track consecutive early deaths
	if current_wave <= 1:
		_consecutive_early_deaths += 1
	else:
		_consecutive_early_deaths = 0


func should_warn_early_deaths() -> bool:
	return _consecutive_early_deaths >= 3


func can_afford_upgrade(upgrade_name: String) -> bool:
	var current_level_val: int = upgrades.get(upgrade_name, 0)
	var max_level := ConfigManager.get_int("upgrade_%s_max" % upgrade_name, 0)
	if current_level_val >= max_level:
		return false
	var costs = ConfigManager.get_json("upgrade_%s_costs" % upgrade_name)
	if costs is Array and current_level_val < costs.size():
		return coins >= int(costs[current_level_val])
	return false


func buy_upgrade(upgrade_name: String) -> bool:
	if not can_afford_upgrade(upgrade_name):
		return false
	var current_level_val: int = upgrades.get(upgrade_name, 0)
	var costs = ConfigManager.get_json("upgrade_%s_costs" % upgrade_name)
	if costs is Array and current_level_val < costs.size():
		var cost: int = int(costs[current_level_val])
		coins -= cost
		upgrades[upgrade_name] = current_level_val + 1
		coins_changed.emit(coins)
		return true
	return false


func get_upgrade_cost(upgrade_name: String) -> int:
	var current_level_val: int = upgrades.get(upgrade_name, 0)
	var costs = ConfigManager.get_json("upgrade_%s_costs" % upgrade_name)
	if costs is Array and current_level_val < costs.size():
		return int(costs[current_level_val])
	return 0


func get_upgrade_value(upgrade_name: String) -> float:
	var current_level_val: int = upgrades.get(upgrade_name, 0)
	var values = ConfigManager.get_json("upgrade_%s_values" % upgrade_name)
	if values is Array and current_level_val < values.size():
		return float(values[current_level_val])
	# Default values
	match upgrade_name:
		"speed": return 1.0
		"damage": return 1.0
		"hp": return 100.0
		"magnet": return 50.0
	return 1.0


func is_upgrade_maxed(upgrade_name: String) -> bool:
	var current_level_val: int = upgrades.get(upgrade_name, 0)
	var max_level := ConfigManager.get_int("upgrade_%s_max" % upgrade_name, 0)
	return current_level_val >= max_level


func to_save_data() -> Dictionary:
	return {
		"coins": coins,
		"highscore": highscore,
		"upgrades": upgrades.duplicate(),
		"totalRuns": total_runs,
		"giftCodesRedeemed": gift_codes_redeemed.duplicate()
	}


func from_save_data(data: Dictionary) -> void:
	coins = int(data.get("coins", 0))
	highscore = int(data.get("highscore", 0))
	var saved_upgrades = data.get("upgrades", {})
	if saved_upgrades is Dictionary:
		for key in saved_upgrades:
			upgrades[key] = int(saved_upgrades[key])
	total_runs = int(data.get("totalRuns", 0))
	var codes = data.get("giftCodesRedeemed", [])
	if codes is Array:
		gift_codes_redeemed = codes.duplicate()
	coins_changed.emit(coins)
	highscore_changed.emit(highscore)
