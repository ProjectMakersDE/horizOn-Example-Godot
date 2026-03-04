## Player - Seagull character controller
extends CharacterBody2D

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

@onready var visual: ColorRect = $Visual
@onready var pickup_area: Area2D = $PickupArea
@onready var hitbox: Area2D = $Hitbox


func _ready() -> void:
	add_to_group("player")
	_apply_upgrades()
	current_hp = max_hp
	health_changed.emit(current_hp, max_hp)
	var pickup_shape := pickup_area.get_node("CollisionShape2D")
	if pickup_shape and pickup_shape.shape is CircleShape2D:
		pickup_shape.shape.radius = pickup_radius


func _apply_upgrades() -> void:
	max_hp = int(GameManager.get_upgrade_value("hp"))
	damage_multiplier = GameManager.get_upgrade_value("damage")
	pickup_radius = GameManager.get_upgrade_value("magnet")
	speed_multiplier = GameManager.get_upgrade_value("speed")


func _physics_process(delta: float) -> void:
	if is_dead:
		return

	if _hurt_timer > 0:
		_hurt_timer -= delta
		if visual:
			visual.modulate = Color(1, 0.5, 0.5) if int(_hurt_timer * 10) % 2 == 0 else Color.WHITE
	else:
		if visual:
			visual.modulate = Color.WHITE

	var input := Vector2.ZERO
	input.x = Input.get_axis("move_left", "move_right")
	input.y = Input.get_axis("move_up", "move_down")

	if input.length() > 0:
		input = input.normalized()
		move_direction = input
		velocity = input * BASE_SPEED * speed_multiplier
	else:
		velocity = Vector2.ZERO

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
	is_dead = true
	AudioManager.play_sfx("sfx_game_over")
	died.emit()


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


func get_xp_progress() -> float:
	if xp_to_next_level <= 0:
		return 0.0
	return float(xp) / float(xp_to_next_level)
