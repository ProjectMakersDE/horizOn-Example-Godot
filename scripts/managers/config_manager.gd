## Config Manager - Caches remote config values
extends Node

var _configs: Dictionary = {}
var _loaded: bool = false


func _ready() -> void:
	pass


func load_configs() -> void:
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
