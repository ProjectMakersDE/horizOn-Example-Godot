## Weapon Manager - Manages player's active weapons
extends Node

var weapons: Array[WeaponBase] = []
var available_weapons: Array[String] = ["feather_throw"]
var _player: CharacterBody2D = null


func setup(player: CharacterBody2D) -> void:
	_player = player
	# Start with Feather Throw
	add_weapon("feather_throw")


func add_weapon(weapon_id: String) -> void:
	if _player == null:
		return
	var weapon: WeaponBase = null
	match weapon_id:
		"feather_throw":
			weapon = load("res://scripts/weapons/feather_throw.gd").new()
		"seagull_screech":
			weapon = load("res://scripts/weapons/seagull_screech.gd").new()
		"dive_bomb":
			weapon = load("res://scripts/weapons/dive_bomb.gd").new()
		"wind_gust":
			weapon = load("res://scripts/weapons/wind_gust.gd").new()

	if weapon:
		weapon.owner_node = _player
		weapons.append(weapon)
		if not weapon_id in available_weapons:
			available_weapons.append(weapon_id)
		_player.add_child(weapon)


func has_weapon(weapon_id: String) -> bool:
	return weapon_id in available_weapons


func upgrade_weapon(weapon_id: String) -> void:
	for w in weapons:
		if w.get_script().resource_path.get_file().get_basename() == weapon_id:
			if w.has_method("upgrade"):
				w.upgrade()
			return
