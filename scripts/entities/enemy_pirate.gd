## Enemy Pirate - Faster, periodic direction change (evasive)
extends "res://scripts/entities/enemy_base.gd"

var _evade_timer: float = 2.0
var _evade_interval: float = 2.0
var _evade_direction: Vector2 = Vector2.ZERO


func _get_enemy_type() -> String:
	return "pirate"


func _on_special_behavior(delta: float) -> void:
	_evade_timer -= delta
	if _evade_timer <= 0:
		_evade_timer = _evade_interval
		# Random perpendicular strafe
		if target and is_instance_valid(target):
			var to_target := (target.global_position - global_position).normalized()
			_evade_direction = to_target.orthogonal() * (1.0 if randf() > 0.5 else -1.0)

	if _evade_direction != Vector2.ZERO:
		velocity += _evade_direction * speed * 0.5
		_evade_direction = _evade_direction.lerp(Vector2.ZERO, delta * 2.0)
