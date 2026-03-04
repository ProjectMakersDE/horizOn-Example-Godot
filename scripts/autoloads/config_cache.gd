## Config Cache - Remote config cache with typed getters
extends Node

var _configs: Dictionary = {}
var _loaded: bool = false


func load_all() -> void:
	if not Horizon.isConnected() or not Horizon.isSignedIn():
		return
	_configs = await Horizon.remoteConfig.getAllConfigs()
	_loaded = true


func is_loaded() -> bool:
	return _loaded


func get_string(key: String, default: String = "") -> String:
	return str(_configs.get(key, default))


func get_int(key: String, default: int = 0) -> int:
	var val = _configs.get(key, "")
	if val is String and val.is_valid_int():
		return val.to_int()
	if val is float or val is int:
		return int(val)
	return default


func get_float(key: String, default: float = 0.0) -> float:
	var val = _configs.get(key, "")
	if val is String and val.is_valid_float():
		return val.to_float()
	if val is float or val is int:
		return float(val)
	return default


func get_bool(key: String, default: bool = false) -> bool:
	var val = str(_configs.get(key, ""))
	if val.is_empty():
		return default
	return val.to_lower() in ["true", "1", "yes"]


func get_json(key: String) -> Variant:
	var val = str(_configs.get(key, ""))
	if val.is_empty():
		return null
	return JSON.parse_string(val)


## Helper: get enemy stats dict from config key "enemy_{type}_stats"
func get_enemy_stats(enemy_type: String) -> Dictionary:
	var stats = get_json("enemy_%s_stats" % enemy_type)
	if stats is Dictionary:
		return stats
	# Defaults
	return {"hp": 30, "speed": 40.0, "damage": 10, "score": 10}


## Helper: get weapon stats dict from config key "weapon_{type}_stats"
func get_weapon_stats(weapon_type: String) -> Dictionary:
	var stats = get_json("weapon_%s_stats" % weapon_type)
	if stats is Dictionary:
		return stats
	return {"damage": 10, "cooldown": 1.0, "range": 100.0}


## Helper: get upgrade costs array
func get_upgrade_costs(upgrade_type: String) -> Array:
	var costs = get_json("upgrade_%s_costs" % upgrade_type)
	if costs is Array:
		return costs
	return []


## Helper: get upgrade values array
func get_upgrade_values(upgrade_type: String) -> Array:
	var values = get_json("upgrade_%s_values" % upgrade_type)
	if values is Array:
		return values
	return []


## Helper: get levelup pool array of dicts
func get_levelup_pool() -> Array:
	var pool = get_json("levelup_pool")
	if pool is Array:
		return pool
	return []
