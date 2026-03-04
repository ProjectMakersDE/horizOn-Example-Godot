## Enemy Base - Common enemy behavior
extends CharacterBody2D
class_name EnemyBase

signal died(enemy: EnemyBase, position: Vector2)

var speed: float = 40.0
var hp: int = 30
var max_hp: int = 30
var damage: int = 10
var xp_reward: int = 10
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

	var direction := (target.global_position - global_position).normalized()
	velocity = direction * speed
	move_and_slide()

	# Check if close enough to attack
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

	# Flash red
	var visual := get_node_or_null("Visual")
	if visual is ColorRect:
		var orig_color := visual.color
		visual.color = Color(1, 0.3, 0.3)
		var tween := create_tween()
		tween.tween_property(visual, "color", orig_color, 0.15)

	if hp <= 0:
		_die()


func _die() -> void:
	is_dead = true
	GameManager.run_kills += 1
	GameManager.current_score += xp_reward
	died.emit(self, global_position)
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.3)
	tween.tween_callback(queue_free)


func setup(config_prefix: String, player_target: Node2D) -> void:
	target = player_target
	speed = ConfigManager.get_float("enemy_%s_speed" % config_prefix, speed)
	hp = ConfigManager.get_int("enemy_%s_hp" % config_prefix, hp)
	max_hp = hp
	damage = ConfigManager.get_int("enemy_%s_damage" % config_prefix, damage)
	xp_reward = ConfigManager.get_int("enemy_%s_xp" % config_prefix, xp_reward)
