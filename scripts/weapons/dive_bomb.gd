## Dive Bomb - Dash-damage in move direction
extends "res://scripts/weapons/weapon_base.gd"

var dive_range: float = 120.0
var dive_width: float = 30.0


func _ready() -> void:
	var stats := ConfigCache.get_weapon_stats("dive")
	weapon_damage = float(stats.get("damage", 50.0))
	cooldown = float(stats.get("cooldown", 3.0))
	dive_range = float(stats.get("range", 120.0))
	super._ready()


func fire() -> void:
	if owner_node == null:
		return
	AudioManager.play_sfx("sfx_dive")

	var dir: Vector2 = owner_node.move_direction.normalized()
	var start_pos := owner_node.global_position

	var effect := ColorRect.new()
	effect.color = Color(0.4, 0.8, 1.0, 0.5)
	effect.size = Vector2(dive_range, dive_width)
	effect.position = start_pos - Vector2(0, dive_width / 2)
	effect.rotation = dir.angle()
	effect.pivot_offset = Vector2(0, dive_width / 2)
	get_tree().current_scene.add_child(effect)
	var tween := effect.create_tween()
	tween.tween_property(effect, "modulate:a", 0.0, 0.3)
	tween.tween_callback(effect.queue_free)

	var enemies := get_tree().get_nodes_in_group("enemies")
	for enemy in enemies:
		if enemy.has_method("take_damage") and not enemy.is_dead:
			var to_enemy := enemy.global_position - start_pos
			var along := to_enemy.dot(dir)
			var perp := abs(to_enemy.dot(dir.orthogonal()))
			if along >= 0 and along <= dive_range and perp <= dive_width:
				enemy.take_damage(int(get_damage()))


func upgrade() -> void:
	weapon_damage *= 1.15
	dive_range += 20.0
