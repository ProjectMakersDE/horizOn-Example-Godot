## Enemy Base - Common enemy behavior
extends CharacterBody2D

const SpriteSheetHelper = preload("res://scripts/visuals/sprite_sheet_helper.gd")
const ENEMY_TEXTURE = preload("res://assets/sprites/enemies.png")
const CutoutRig = preload("res://scripts/visuals/cutout_rig.gd")

signal died(enemy: Node2D, position: Vector2)

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
	_on_special_behavior(delta)
	move_and_slide()

	var vis = get_node_or_null("Visual")
	if vis and vis is CutoutRig:
		vis.set_locomotion(velocity.length_squared() > 0.1, direction.x)
	elif vis and vis is AnimatedSprite2D:
		vis.flip_h = direction.x < 0
	elif vis and vis is Sprite2D:
		vis.flip_h = direction.x < 0

	var dist := global_position.distance_to(target.global_position)
	if dist < 24.0 and _attack_timer <= 0:
		_attack_timer = _attack_cooldown
		_attack()


func _attack() -> void:
	if target and is_instance_valid(target) and target.has_method("take_damage"):
		var visual := get_node_or_null("Visual")
		if visual is CutoutRig:
			visual.trigger_attack()
		target.take_damage(damage)
		AudioManager.play_sfx("sfx_enemy_attack")


func take_damage(amount: int) -> void:
	if is_dead:
		return
	hp -= amount
	AudioManager.play_sfx("sfx_enemy_hit")

	var visual: CanvasItem = get_node_or_null("Visual")
	if visual is CutoutRig:
		visual.trigger_hurt()
	elif visual:
		var orig_modulate: Color = visual.modulate
		visual.modulate = Color(1, 0.3, 0.3)
		var tween := create_tween()
		tween.tween_property(visual, "modulate", orig_modulate, 0.15)

	if hp <= 0:
		_die()


func _die() -> void:
	if is_dead:
		return
	is_dead = true
	velocity = Vector2.ZERO
	collision_layer = 0
	collision_mask = 0
	GameManager.run_state.kills += 1
	died.emit(self, global_position)

	var visual := get_node_or_null("Visual")
	if visual is CutoutRig:
		visual.animation_finished.connect(_on_death_animation_finished, CONNECT_ONE_SHOT)
		visual.die()
	elif visual and visual is AnimatedSprite2D and visual.sprite_frames and visual.sprite_frames.has_animation("death"):
		visual.play("death")
		visual.animation_finished.connect(_on_death_animation_finished, CONNECT_ONE_SHOT)
	else:
		queue_free()


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
	_setup_visual()


func _get_enemy_type() -> String:
	return "crab"


func _on_special_behavior(_delta: float) -> void:
	pass


func _setup_visual() -> void:
	var visual := get_node_or_null("Visual")
	if _get_enemy_type() == "crab":
		if visual:
			remove_child(visual)
			visual.free()
		var rig := CutoutRig.new()
		rig.name = "Visual"
		add_child(rig)
		rig.setup("crab", 46.0)
		return
	if visual == null or not visual is AnimatedSprite2D:
		return

	var art_name := "octopus" if _get_enemy_type() == "boss" else _get_enemy_type()
	var path := "res://assets/shared/enemy_%s.png" % art_name
	if ResourceLoader.exists(path):
		var texture: Texture2D = load(path)
		var new_frames := SpriteFrames.new()
		for animation_name in ["move", "death"]:
			new_frames.add_animation(animation_name)
			new_frames.add_frame(animation_name, texture)
			new_frames.set_animation_loop(animation_name, animation_name != "death")
			new_frames.set_animation_speed(animation_name, 6.0)
		visual.sprite_frames = new_frames
		visual.scale = Vector2.ONE * ((112.0 if art_name == "octopus" else 46.0) / texture.get_width())
		visual.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		visual.play("move")
		return
	var frames := SpriteFrames.new()
	match _get_enemy_type():
		"jellyfish":
			SpriteSheetHelper.add_row_animation(frames, "move", ENEMY_TEXTURE, Vector2i(32, 32), 2, 4, 6.0)
			SpriteSheetHelper.add_row_animation(frames, "death", ENEMY_TEXTURE, Vector2i(32, 32), 3, 3, 8.0, false)
		"pirate":
			SpriteSheetHelper.add_row_animation(frames, "move", ENEMY_TEXTURE, Vector2i(32, 32), 4, 4, 8.0)
			SpriteSheetHelper.add_row_animation(frames, "death", ENEMY_TEXTURE, Vector2i(32, 32), 5, 3, 8.0, false)
		"boss":
			SpriteSheetHelper.add_row_animation(frames, "move", ENEMY_TEXTURE, Vector2i(64, 64), 6, 4, 5.0)
			SpriteSheetHelper.add_row_animation(frames, "death", ENEMY_TEXTURE, Vector2i(64, 64), 7, 4, 6.0, false)
	visual.sprite_frames = frames
	visual.play("move")


func _on_death_animation_finished() -> void:
	queue_free()
