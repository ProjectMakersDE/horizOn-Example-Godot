## Enemy Base - Common enemy behavior
extends CharacterBody2D

signal died(enemy: Node2D, position: Vector2)

var speed: float = 40.0
var hp: int = 30
var max_hp: int = 30
var damage: int = 10
var xp_reward: int = 10
var score_value: int = 10
var is_dead: bool = false
var target: Node2D = null

var _attack_cooldown: float = 1.0
var _attack_timer: float = 0.0


func _physics_process(delta: float) -> void:
	if is_dead or target == null:
		return
	if not is_instance_valid(target):
		return

	_attack_timer -= delta
	_on_special_behavior(delta)

	var direction := (target.global_position - global_position).normalized()
	velocity = direction * speed
	move_and_slide()

	var vis = get_node_or_null("Visual")
	if vis and vis is Sprite2D:
		vis.flip_h = direction.x < 0

	var dist := global_position.distance_to(target.global_position)
	if dist < 24.0 and _attack_timer <= 0:
		_attack_timer = _attack_cooldown
		_attack()


func _attack() -> void:
	if target and is_instance_valid(target) and target.has_method("take_damage"):
		target.take_damage(damage)
		AudioManager.play_sfx("sfx_enemy_attack")


func take_damage(amount: int) -> void:
	if is_dead:
		return
	hp -= amount
	AudioManager.play_sfx("sfx_enemy_hit")

	var visual := get_node_or_null("Visual")
	if visual:
		var orig_modulate := visual.modulate
		visual.modulate = Color(1, 0.3, 0.3)
		var tween := create_tween()
		tween.tween_property(visual, "modulate", orig_modulate, 0.15)

	if hp <= 0:
		_die()


func _die() -> void:
	is_dead = true
	GameManager.run_state.kills += 1
	died.emit(self, global_position)
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.3)
	tween.tween_callback(queue_free)


func setup(enemy_type: String, player_target: Node2D) -> void:
	target = player_target
	var stats := ConfigCache.get_enemy_stats(enemy_type)
	hp = int(stats.get("hp", 30))
	# Boss uses dedicated wave_boss_hp config key with higher default
	if enemy_type == "boss":
		hp = int(ConfigCache.get_float("wave_boss_hp", 500.0))
	max_hp = hp
	speed = float(stats.get("speed", 40.0))
	damage = int(stats.get("damage", 10))
	xp_reward = int(stats.get("xp", 10))
	score_value = xp_reward


func _get_enemy_type() -> String:
	return "crab"


func _on_special_behavior(_delta: float) -> void:
	pass
