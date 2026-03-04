## XP Shell - Pickup that grants XP to player
extends Area2D

var xp_amount: int = 10
var _attracted: bool = false
var _attract_speed: float = 200.0


func _ready() -> void:
	collision_layer = 8  # pickups layer
	collision_mask = 0
	add_to_group("xp_pickups")

	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 6.0
	shape.shape = circle
	add_child(shape)

	var visual := ColorRect.new()
	visual.name = "Visual"
	visual.color = Color("#FFD700")
	visual.size = Vector2(8, 8)
	visual.position = Vector2(-4, -4)
	add_child(visual)


func _physics_process(delta: float) -> void:
	if _attracted:
		var players := get_tree().get_nodes_in_group("player")
		if players.size() > 0:
			var player := players[0]
			var dir := (player.global_position - global_position).normalized()
			global_position += dir * _attract_speed * delta
			if global_position.distance_to(player.global_position) < 12.0:
				_collect(player)


func check_magnet(player: Node2D, radius: float) -> void:
	if _attracted:
		return
	if global_position.distance_to(player.global_position) <= radius:
		_attracted = true


func _collect(player: Node2D) -> void:
	if player.has_method("add_xp"):
		player.add_xp(xp_amount)
	AudioManager.play_sfx("sfx_pickup_xp")
	queue_free()
