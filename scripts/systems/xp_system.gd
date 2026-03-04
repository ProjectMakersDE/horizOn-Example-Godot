## XP System - Tracks XP and level, emits signals
extends Node

signal xp_changed(current_xp: int, max_xp: int)
signal level_up(new_level: int)

var current_xp: int = 0
var current_level: int = 1
var xp_to_next: int = 50


func _ready() -> void:
	var base := ConfigCache.get_int("xp_per_kill_base", 10)
	xp_to_next = base * 5


func add_xp(amount: int) -> void:
	current_xp += amount
	xp_changed.emit(current_xp, xp_to_next)
	while current_xp >= xp_to_next:
		current_xp -= xp_to_next
		current_level += 1
		var curve := ConfigCache.get_float("xp_level_curve", 1.4)
		xp_to_next = int(50.0 * pow(curve, current_level - 1))
		level_up.emit(current_level)
		xp_changed.emit(current_xp, xp_to_next)


func get_progress() -> float:
	if xp_to_next <= 0:
		return 0.0
	return float(current_xp) / float(xp_to_next)
