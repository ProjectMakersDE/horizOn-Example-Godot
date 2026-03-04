## Weapon Base - Auto-firing weapon system
extends Node2D
class_name WeaponBase

var weapon_damage: float = 20.0
var cooldown: float = 0.8
var _timer: float = 0.0
var owner_node: CharacterBody2D = null


func _ready() -> void:
	_timer = 0.0


func _process(delta: float) -> void:
	_timer -= delta
	if _timer <= 0:
		_timer = cooldown
		fire()


func fire() -> void:
	pass  # Override in subclass


func get_damage() -> float:
	return weapon_damage * GameManager.get_upgrade_value("damage")
