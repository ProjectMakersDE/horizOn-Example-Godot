## Wave Manager - Spawns enemies in waves during survival run
extends Node

signal wave_started(wave_number: int)
signal boss_spawned

var current_wave: int = 0
var _wave_timer: float = 0.0
var _wave_interval: float = 15.0
var _enemy_count_base: int = 5
var _enemy_count_growth: float = 1.3
var _player: Node2D = null


func setup(player: Node2D) -> void:
	_player = player
	_wave_interval = ConfigManager.get_float("wave_interval_seconds", 15.0)
	_enemy_count_base = ConfigManager.get_int("wave_enemy_count_base", 5)
	_enemy_count_growth = ConfigManager.get_float("wave_enemy_count_growth", 1.3)


func _process(delta: float) -> void:
	if not GameManager.run_active:
		return
	_wave_timer -= delta
	if _wave_timer <= 0:
		_wave_timer = _wave_interval
		current_wave += 1
		GameManager.current_wave = current_wave
		_spawn_wave(current_wave)
		wave_started.emit(current_wave)


func _spawn_wave(wave: int) -> void:
	var count := int(_enemy_count_base * pow(_enemy_count_growth, wave - 1))
	count = mini(count, 50)

	for i in count:
		var enemy := _create_enemy(wave)
		if enemy:
			enemy.global_position = _get_spawn_position()
			get_tree().current_scene.add_child(enemy)


func spawn_boss() -> void:
	var boss := _create_boss()
	if boss:
		boss.global_position = _get_spawn_position()
		get_tree().current_scene.add_child(boss)
		boss_spawned.emit()


func _create_enemy(wave: int) -> EnemyBase:
	var enemy_size := Vector2(24, 24)
	var enemy := _build_enemy_node(enemy_size)

	if wave >= 5 and randf() < 0.3:
		enemy.setup("pirate", _player)
		_set_enemy_color(enemy, Color("#4A4A4A"))
	elif wave >= 3 and randf() < 0.4:
		enemy.setup("jellyfish", _player)
		_set_enemy_color(enemy, Color("#9B59B6"))
	else:
		enemy.setup("crab", _player)
		_set_enemy_color(enemy, Color("#E05B4B"))

	enemy.add_to_group("enemies")
	enemy.died.connect(_on_enemy_died)
	return enemy


func _create_boss() -> EnemyBase:
	var boss := _build_enemy_node(Vector2(48, 48))
	boss.speed = 30.0
	boss.hp = ConfigManager.get_int("wave_boss_hp", 500)
	boss.max_hp = boss.hp
	boss.damage = 30
	boss.xp_reward = 100
	boss.target = _player
	boss.add_to_group("enemies")
	boss.died.connect(_on_enemy_died)
	_set_enemy_color(boss, Color("#4A4A4A"))
	return boss


func _build_enemy_node(size: Vector2 = Vector2(24, 24)) -> EnemyBase:
	var enemy := EnemyBase.new()

	# Collision shape for CharacterBody2D
	var body_shape := CollisionShape2D.new()
	var body_rect := RectangleShape2D.new()
	body_rect.size = size
	body_shape.shape = body_rect
	enemy.add_child(body_shape)

	# Hitbox area (for projectile detection)
	var hitbox := Area2D.new()
	hitbox.name = "Hitbox"
	hitbox.collision_layer = 2
	hitbox.collision_mask = 4
	var hit_shape := CollisionShape2D.new()
	var hit_rect := RectangleShape2D.new()
	hit_rect.size = size
	hit_shape.shape = hit_rect
	hitbox.add_child(hit_shape)
	enemy.add_child(hitbox)

	# Visual placeholder
	var visual := ColorRect.new()
	visual.name = "Visual"
	visual.size = size
	visual.position = -size / 2
	enemy.add_child(visual)

	return enemy


func _set_enemy_color(enemy: EnemyBase, color: Color) -> void:
	var visual := enemy.get_node_or_null("Visual")
	if visual is ColorRect:
		visual.color = color


func _on_enemy_died(enemy: EnemyBase, pos: Vector2) -> void:
	_spawn_xp_pickup(pos, enemy.xp_reward)


func _spawn_xp_pickup(pos: Vector2, xp_value: int) -> void:
	var pickup := Area2D.new()
	pickup.name = "XPPickup"
	pickup.collision_layer = 8
	pickup.collision_mask = 1

	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 6.0
	shape.shape = circle
	pickup.add_child(shape)

	var visual := ColorRect.new()
	visual.color = Color("#FFD700")
	visual.size = Vector2(8, 8)
	visual.position = Vector2(-4, -4)
	pickup.add_child(visual)

	pickup.global_position = pos

	# Use a simple script for pickup behavior
	var script := GDScript.new()
	script.source_code = _get_pickup_script()
	script.reload()
	pickup.set_script(script)
	pickup.set("xp_value", xp_value)

	get_tree().current_scene.call_deferred("add_child", pickup)


func _get_pickup_script() -> String:
	return """extends Area2D

var xp_value: int = 10
var _attracted: bool = false
var _target: Node2D = null
var _lifetime: float = 30.0

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func _physics_process(delta: float) -> void:
	_lifetime -= delta
	if _lifetime <= 0:
		queue_free()
		return
	if _attracted and _target and is_instance_valid(_target):
		var dir := (_target.global_position - global_position).normalized()
		global_position += dir * 200.0 * delta
		if global_position.distance_to(_target.global_position) < 10:
			_collect()

func check_magnet(player: Node2D, radius: float) -> void:
	if not _attracted and global_position.distance_to(player.global_position) <= radius:
		_attracted = true
		_target = player

func _on_body_entered(body: Node2D) -> void:
	if body.has_method(\"add_xp\"):
		_target = body
		_collect()

func _collect() -> void:
	if _target and is_instance_valid(_target) and _target.has_method(\"add_xp\"):
		_target.add_xp(xp_value)
		AudioManager.play_sfx(\"sfx_pickup_xp\")
	queue_free()
"""


func _get_spawn_position() -> Vector2:
	if _player == null:
		return Vector2.ZERO
	var offset := Vector2.ZERO
	var side := randi() % 4
	match side:
		0: offset = Vector2(randf_range(-300, 300), -200)
		1: offset = Vector2(randf_range(-300, 300), 200)
		2: offset = Vector2(-300, randf_range(-200, 200))
		3: offset = Vector2(300, randf_range(-200, 200))
	return _player.global_position + offset
