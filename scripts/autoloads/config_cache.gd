## Config Cache - Remote config cache with typed getters
##
## Remote Config key format for structured data (enemy stats, weapon stats):
## Each key stores a JSON object as its value string. For example:
##   key: "enemy_crab_stats"  ->  value: '{"hp":30,"speed":40,"damage":10,"score":10}'
##   key: "weapon_wave_stats" ->  value: '{"damage":15,"cooldown":1.5,"range":80}'
## Use get_json(key) to parse these into Dictionaries.
extends Node

var _configs: Dictionary = {}
var _loaded: bool = false


func load_all() -> void:
	if _loaded:
		return
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


## Helper: get enemy stats from flat config keys (enemy_{type}_hp, enemy_{type}_speed, etc.)
func get_enemy_stats(enemy_type: String) -> Dictionary:
	return {
		"hp": get_int("enemy_%s_hp" % enemy_type, 30),
		"speed": get_float("enemy_%s_speed" % enemy_type, 40.0),
		"damage": get_int("enemy_%s_damage" % enemy_type, 10),
		"xp": get_int("enemy_%s_xp" % enemy_type, 10),
	}


## Helper: get weapon stats from flat config keys (weapon_{type}_damage, weapon_{type}_cooldown, etc.)
func get_weapon_stats(weapon_type: String) -> Dictionary:
	return {
		"damage": get_float("weapon_%s_damage" % weapon_type, 20.0),
		"cooldown": get_float("weapon_%s_cooldown" % weapon_type, 1.0),
		"projectiles": get_int("weapon_%s_projectiles" % weapon_type, 1),
		"radius": get_float("weapon_%s_radius" % weapon_type, 80.0),
		"range": get_float("weapon_%s_range" % weapon_type, 120.0),
		"knockback": get_float("weapon_%s_knockback" % weapon_type, 60.0),
	}


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
