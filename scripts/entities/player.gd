## Player - Seagull character controller
extends CharacterBody2D

const CutoutRig = preload("res://scripts/visuals/cutout_rig.gd")

signal died
signal xp_gained(amount: int)
signal leveled_up(new_level: int)
signal health_changed(current: int, maximum: int)

const BASE_SPEED: float = 145.0

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

var dash_cooldown: float = 0.0
var _dash_time: float = 0.0

var _hurt_timer: float = 0.0
var _invincible_time: float = 0.5
var _death_signal_emitted: bool = false

@onready var visual: CutoutRig = $Visual
@onready var pickup_area: Area2D = $PickupArea
@onready var hitbox: Area2D = $Hitbox


func _ready() -> void:
	_setup_visual()
	add_to_group("player")
	_apply_upgrades()
	xp_to_next_level = _xp_curve_base()
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

	dash_cooldown = maxf(dash_cooldown - delta, 0.0)
	_dash_time = maxf(_dash_time - delta, 0.0)
	if is_dead:
		_update_animation(false)
		return

	if _hurt_timer > 0:
		_hurt_timer -= delta

	input.x = Input.get_axis("move_left", "move_right")
	input.y = Input.get_axis("move_up", "move_down")
	# Validated Actions: one input log event per direction change
	GameManager.validated_run.record_move(input)

	if input.length() > 0:
		is_moving = true
		input = input.normalized()
		move_direction = input
		velocity = input * BASE_SPEED * speed_multiplier
	else:
		velocity = Vector2.ZERO

	if Input.is_action_just_pressed("dash") and dash_cooldown <= 0.0:
		dash_cooldown = 3.0
		_dash_time = 0.18
		_hurt_timer = maxf(_hurt_timer, 0.25)
		GameManager.run_state.dashes += 1
		GameManager.validated_run.record_dash()
	if _dash_time > 0.0:
		velocity = move_direction * 430.0
	_update_animation(is_moving)
	move_and_slide()
	position = position.clamp(Vector2(-350, -158), Vector2(350, 158))


func take_damage(amount: int) -> void:
	if is_dead or _hurt_timer > 0:
		return
	_hurt_timer = _invincible_time
	visual.trigger_hurt()
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
	xp_to_next_level = int(float(_xp_curve_base()) * pow(curve, level - 1))
	AudioManager.play_sfx("sfx_levelup")
	leveled_up.emit(level)


func _xp_curve_base() -> int:
	# Level curve starts at 5x the configurable per-kill XP base (default 10),
	# so the first level still needs 50 XP like the old hardcoded value.
	return ConfigCache.get_int("xp_per_kill_base", 10) * 5


func increase_pickup_radius(amount: float) -> void:
	pickup_radius += amount
	var pickup_shape := pickup_area.get_node("CollisionShape2D")
	if pickup_shape and pickup_shape.shape is CircleShape2D:
		pickup_shape.shape.radius = pickup_radius


func _on_pickup_area_entered(area: Area2D) -> void:
	if area.has_method("_collect"):
		area._collect(self)


func get_xp_progress() -> float:
	if xp_to_next_level <= 0:
		return 0.0
	return float(xp) / float(xp_to_next_level)


func _setup_visual() -> void:
	visual.setup("gull", 52.0)


func animate_attack() -> void:
	if not is_dead:
		visual.trigger_attack()


func _update_animation(is_moving: bool) -> void:
	if visual == null:
		return

	if is_dead:
		visual.die()
		return
	visual.set_locomotion(is_moving, move_direction.x)


func _on_visual_animation_finished() -> void:
	if is_dead and not _death_signal_emitted:
		_death_signal_emitted = true
		died.emit()
