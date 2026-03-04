## Enemy Jellyfish - Leaves poison zone periodically
extends "res://scripts/entities/enemy_base.gd"

var _poison_timer: float = 5.0
var _poison_interval: float = 5.0
var _poison_radius: float = 30.0
var _poison_damage: int = 5
var _poison_duration: float = 3.0


func _get_enemy_type() -> String:
	return "jellyfish"


func _on_special_behavior(delta: float) -> void:
	_poison_timer -= delta
	if _poison_timer <= 0:
		_poison_timer = _poison_interval
		_spawn_poison_zone()


func _spawn_poison_zone() -> void:
	var zone := Area2D.new()
	zone.collision_layer = 0
	zone.collision_mask = 1  # player layer

	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = _poison_radius
	shape.shape = circle
	zone.add_child(shape)

	var visual := ColorRect.new()
	visual.color = Color(0.608, 0.349, 0.714, 0.3)
	visual.size = Vector2(_poison_radius * 2, _poison_radius * 2)
	visual.position = Vector2(-_poison_radius, -_poison_radius)
	zone.add_child(visual)

	zone.global_position = global_position
	get_tree().current_scene.add_child(zone)

	# Damage on overlap
	zone.body_entered.connect(func(body):
		if body.has_method("take_damage"):
			body.take_damage(_poison_damage)
	)

	# Fade out and remove
	var tween := zone.create_tween()
	tween.tween_interval(_poison_duration)
	tween.tween_property(visual, "modulate:a", 0.0, 0.5)
	tween.tween_callback(zone.queue_free)
