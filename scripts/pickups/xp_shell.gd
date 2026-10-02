## XP Shell - Pickup that grants XP to player
extends Area2D

const SpriteSheetHelper = preload("res://scripts/visuals/sprite_sheet_helper.gd")
const PICKUP_TEXTURE = preload("res://assets/sprites/pickups.png")

var xp_amount: int = 10
var is_heart: bool = false
var _attracted: bool = false
var _attract_speed: float = 200.0
var _collected: bool = false


func _ready() -> void:
	collision_layer = 8  # pickups layer
	collision_mask = 0
	add_to_group("xp_pickups")

	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 6.0
	shape.shape = circle
	add_child(shape)

	var visual := AnimatedSprite2D.new()
	visual.name = "Visual"
	var frames := SpriteFrames.new()
	var path := "res://assets/shared/pickup_heart.png" if is_heart else "res://assets/shared/pickup_shell.png"
	if ResourceLoader.exists(path):
		var texture: Texture2D = load(path)
		frames.add_animation("idle")
		frames.add_frame("idle", texture)
		visual.scale = Vector2.ONE * (22.0 / texture.get_width())
		visual.sprite_frames = frames
		visual.play("idle")
		add_child(visual)
		return
	SpriteSheetHelper.add_row_animation(frames, "idle", PICKUP_TEXTURE, Vector2i(16, 16), 0, 4, 8.0)
	visual.sprite_frames = frames
	visual.play("idle")
	add_child(visual)


func _physics_process(delta: float) -> void:
	if _attracted:
		var players := get_tree().get_nodes_in_group("player")
		if players.size() > 0:
			var player: Node2D = players[0]
			var dir: Vector2 = (player.global_position - global_position).normalized()
			global_position += dir * _attract_speed * delta
			if global_position.distance_to(player.global_position) < 12.0:
				_collect(player)


func check_magnet(player: Node2D, radius: float) -> void:
	if _attracted:
		return
	if global_position.distance_to(player.global_position) <= radius:
		_attracted = true


func _collect(player: Node2D) -> void:
	if _collected:
		return
	_collected = true
	if is_heart:
		player.current_hp = mini(player.current_hp + 15, player.max_hp)
		player.health_changed.emit(player.current_hp, player.max_hp)
	elif player.has_method("add_xp"):
		player.add_xp(xp_amount)
	AudioManager.play_sfx("sfx_pickup_xp")
	queue_free()
