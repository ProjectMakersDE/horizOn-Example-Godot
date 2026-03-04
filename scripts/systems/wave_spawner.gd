## Wave Spawner - Timer-based wave spawning system
extends Node

signal wave_started(wave_number: int)
signal boss_spawned()

var _player: Node2D = null
var _enemies_container: Node2D = null
var _pickups_container: Node2D = null
var _wave_number: int = 0
var _wave_timer: float = 0.0
var _wave_interval: float = 15.0
var _viewport_size: Vector2 = Vector2(480, 270)

var _enemy_scripts: Dictionary = {
	"crab": preload("res://scripts/entities/enemy_crab.gd"),
	"jellyfish": preload("res://scripts/entities/enemy_jellyfish.gd"),
	"pirate": preload("res://scripts/entities/enemy_pirate.gd"),
	"boss": preload("res://scripts/entities/enemy_boss.gd"),
}

var _enemy_colors: Dictionary = {
	"crab": Color("#E05B4B"),
	"jellyfish": Color("#9B59B6"),
	"pirate": Color("#4A4A4A"),
	"boss": Color("#4A4A4A"),
}


func setup(player: Node2D, enemies: Node2D, pickups: Node2D) -> void:
	_player = player
	_enemies_container = enemies
	_pickups_container = pickups
	_wave_interval = ConfigCache.get_float("wave_interval_seconds", 15.0)
	_wave_timer = 2.0  # First wave after 2 seconds


func _process(delta: float) -> void:
	if _player == null or not is_instance_valid(_player):
		return

	_wave_timer -= delta
	if _wave_timer <= 0:
		_wave_timer = _wave_interval
		_wave_number += 1
		_spawn_wave()
		wave_started.emit(_wave_number)


func _spawn_wave() -> void:
	var base_count := ConfigCache.get_int("wave_enemy_count_base", 5)
	var growth := ConfigCache.get_float("wave_enemy_count_growth", 1.3)
	var count := int(base_count * pow(growth, _wave_number - 1))

	for i in count:
		var enemy_type := _pick_enemy_type()
		_spawn_enemy(enemy_type)


func _pick_enemy_type() -> String:
	if _wave_number >= 5:
		var roll := randf()
		if roll < 0.3:
			return "pirate"
		elif roll < 0.5:
			return "jellyfish"
	elif _wave_number >= 3:
		if randf() < 0.3:
			return "jellyfish"
	return "crab"


func _spawn_enemy(enemy_type: String) -> void:
	var enemy := CharacterBody2D.new()
	enemy.collision_layer = 2
	enemy.collision_mask = 1

	var script = _enemy_scripts.get(enemy_type)
	if script:
		enemy.set_script(script)

	# Visual sprite
	var visual := Sprite2D.new()
	visual.name = "Visual"
	visual.texture = preload("res://assets/sprites/enemies.png")
	visual.region_enabled = true
	match enemy_type:
		"crab":
			visual.region_rect = Rect2(0, 0, 32, 32)
		"jellyfish":
			visual.region_rect = Rect2(0, 64, 32, 32)
		"pirate":
			visual.region_rect = Rect2(0, 128, 32, 32)
		"boss":
			visual.region_rect = Rect2(0, 192, 64, 64)
	enemy.add_child(visual)

	# Collision shape
	var size := 24.0 if enemy_type != "boss" else 48.0
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(size, size)
	shape.shape = rect
	enemy.add_child(shape)

	# Position outside viewport
	var spawn_pos := _get_spawn_position()
	enemy.global_position = spawn_pos

	enemy.add_to_group("enemies")
	_enemies_container.add_child(enemy)

	# Setup stats from config
	if enemy.has_method("setup"):
		enemy.setup(enemy_type, _player)

	# Connect death signal to spawn XP
	if enemy.has_signal("died"):
		enemy.died.connect(_on_enemy_died)


func spawn_boss() -> void:
	_spawn_enemy("boss")
	boss_spawned.emit()


func _get_spawn_position() -> Vector2:
	if _player == null:
		return Vector2.ZERO
	var edge := randi() % 4
	var offset := randf_range(-200, 200)
	var margin := 50.0
	var player_pos := _player.global_position
	match edge:
		0: return player_pos + Vector2(offset, -_viewport_size.y / 2 - margin)  # top
		1: return player_pos + Vector2(offset, _viewport_size.y / 2 + margin)   # bottom
		2: return player_pos + Vector2(-_viewport_size.x / 2 - margin, offset)  # left
		3: return player_pos + Vector2(_viewport_size.x / 2 + margin, offset)   # right
	return player_pos + Vector2(300, 0)


func _on_enemy_died(_enemy: EnemyBase, pos: Vector2) -> void:
	_spawn_xp_pickup(pos, _enemy.xp_reward)


func _spawn_xp_pickup(pos: Vector2, xp: int = 10) -> void:
	var pickup := Area2D.new()
	pickup.set_script(load("res://scripts/pickups/xp_shell.gd"))
	pickup.xp_amount = xp
	pickup.global_position = pos
	_pickups_container.add_child(pickup)
