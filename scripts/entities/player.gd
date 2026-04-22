## Player - Seagull character controller
extends CharacterBody2D

const SpriteSheetHelper = preload("res://scripts/visuals/sprite_sheet_helper.gd")
const PLAYER_TEXTURE = preload("res://assets/sprites/seagull.png")

signal died
signal xp_gained(amount: int)
signal leveled_up(new_level: int)
signal health_changed(current: int, maximum: int)

const BASE_SPEED: float = 200.0

var max_hp: int = 100
var current_hp: int = 100
var move_direction: Vector2 = Vector2.RIGHT
var xp: int = 0
var xp_to_next_level: int = 50
var level: int = 1
var pickup_radius: float = 50.0
var damage_multiplier: float = 1.0
var speed_multiplier: float = 1.0
var is_dead: bool = false

var _hurt_timer: float = 0.0
var _invincible_time: float = 0.5
var _death_signal_emitted: bool = false

@onready var visual: AnimatedSprite2D = $Visual
@onready var pickup_area: Area2D = $PickupArea
@onready var hitbox: Area2D = $Hitbox


func _ready() -> void:
	_setup_visual()
	add_to_group("player")
	_apply_upgrades()
	current_hp = max_hp
	health_changed.emit(current_hp, max_hp)
	var pickup_shape := pickup_area.get_node("CollisionShape2D")
	if pickup_shape and pickup_shape.shape is CircleShape2D:
		pickup_shape.shape.radius = pickup_radius
	pickup_area.area_entered.connect(_on_pickup_area_entered)
	visual.animation_finished.connect(_on_visual_animation_finished)


func _apply_upgrades() -> void:
	max_hp = int(GameManager.get_upgrade_value("hp"))
	damage_multiplier = GameManager.get_upgrade_value("damage")
	pickup_radius = GameManager.get_upgrade_value("magnet")
	speed_multiplier = GameManager.get_upgrade_value("speed")


func _physics_process(delta: float) -> void:
	var input := Vector2.ZERO
	var is_moving := false

	if is_dead:
		_update_animation(false)
		return

	if _hurt_timer > 0:
		_hurt_timer -= delta
		if visual:
			visual.modulate = Color(1, 0.5, 0.5) if int(_hurt_timer * 10) % 2 == 0 else Color.WHITE
	else:
		if visual:
			visual.modulate = Color.WHITE

	input.x = Input.get_axis("move_left", "move_right")
	input.y = Input.get_axis("move_up", "move_down")

	if input.length() > 0:
		is_moving = true
		input = input.normalized()
		move_direction = input
		velocity = input * BASE_SPEED * speed_multiplier
		if visual and input.x != 0:
			visual.flip_h = input.x < 0
	else:
		velocity = Vector2.ZERO

	_update_animation(is_moving)
	move_and_slide()


func take_damage(amount: int) -> void:
	if is_dead or _hurt_timer > 0:
		return
	_hurt_timer = _invincible_time
	current_hp -= amount
	GameManager.run_state.playerHP = current_hp
	health_changed.emit(current_hp, max_hp)
	AudioManager.play_sfx("sfx_player_hit")
	if current_hp <= 0:
		current_hp = 0
		_die()


func _die() -> void:
	if is_dead:
		return
	is_dead = true
	velocity = Vector2.ZERO
	collision_layer = 0
	collision_mask = 0
	hitbox.collision_layer = 0
	hitbox.collision_mask = 0
	pickup_area.collision_layer = 0
	pickup_area.collision_mask = 0
	_update_animation(false)
	AudioManager.play_sfx("sfx_game_over")


func add_xp(amount: int) -> void:
	xp += amount
	GameManager.run_state.xpCollected += amount
	xp_gained.emit(amount)
	if xp >= xp_to_next_level:
		_level_up()


func _level_up() -> void:
	xp -= xp_to_next_level
	level += 1
	var curve: float = ConfigCache.get_float("xp_level_curve", 1.4)
	xp_to_next_level = int(50.0 * pow(curve, level - 1))
	AudioManager.play_sfx("sfx_levelup")
	leveled_up.emit(level)


func _on_pickup_area_entered(area: Area2D) -> void:
	if area.has_method("_collect"):
		area._collect(self)


func get_xp_progress() -> float:
	if xp_to_next_level <= 0:
		return 0.0
	return float(xp) / float(xp_to_next_level)


func _setup_visual() -> void:
	var frames := SpriteFrames.new()
	SpriteSheetHelper.add_row_animation(frames, "idle", PLAYER_TEXTURE, Vector2i(32, 32), 0, 4, 6.0)
	SpriteSheetHelper.add_row_animation(frames, "walk", PLAYER_TEXTURE, Vector2i(32, 32), 1, 6, 10.0)
	SpriteSheetHelper.add_row_animation(frames, "hurt", PLAYER_TEXTURE, Vector2i(32, 32), 2, 2, 12.0)
	SpriteSheetHelper.add_row_animation(frames, "death", PLAYER_TEXTURE, Vector2i(32, 32), 3, 4, 8.0, false)
	visual.sprite_frames = frames
	visual.play("idle")


func _update_animation(is_moving: bool) -> void:
	if visual == null:
		return

	if is_dead:
		if visual.animation != "death":
			visual.play("death")
		return

	var next_animation := "idle"
	if _hurt_timer > 0:
		next_animation = "hurt"
	elif is_moving:
		next_animation = "walk"

	if visual.animation != next_animation:
		visual.play(next_animation)


func _on_visual_animation_finished() -> void:
	if is_dead and visual.animation == "death" and not _death_signal_emitted:
		_death_signal_emitted = true
		died.emit()
