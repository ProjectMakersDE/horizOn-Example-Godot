## Wind Gust - Knockback wave all around
extends "res://scripts/weapons/weapon_base.gd"

const SpriteSheetHelper = preload("res://scripts/visuals/sprite_sheet_helper.gd")
const WEAPON_TEXTURE = preload("res://assets/sprites/weapons.png")

var knockback_force: float = 60.0
var gust_radius: float = 100.0


func _ready() -> void:
	var stats := ConfigCache.get_weapon_stats("gust")
	weapon_damage = float(stats.get("damage", 10.0))
	cooldown = float(stats.get("cooldown", 2.5))
	knockback_force = float(stats.get("knockback", 60.0))
	super._ready()


func fire() -> void:
	if owner_node == null:
		return
	AudioManager.play_sfx("sfx_gust")

	var effect := _create_gust_effect()
	effect.global_position = owner_node.global_position
	get_tree().current_scene.add_child(effect)

	var enemies := get_tree().get_nodes_in_group("enemies")
	for enemy in enemies:
		if enemy.has_method("take_damage") and not enemy.is_dead:
			var dist := owner_node.global_position.distance_to(enemy.global_position)
			if dist <= gust_radius:
				enemy.take_damage(int(get_damage()))
				var dir := (enemy.global_position - owner_node.global_position).normalized()
				enemy.global_position += dir * knockback_force


func _create_gust_effect() -> Node2D:
	var effect := Node2D.new()
	var sprite := AnimatedSprite2D.new()
	var frames := SpriteFrames.new()
	SpriteSheetHelper.add_row_animation(frames, "gust", WEAPON_TEXTURE, Vector2i(32, 32), 3, 4, 12.0, false)
	sprite.sprite_frames = frames
	sprite.scale = Vector2.ONE * max(gust_radius / 24.0, 1.0)
	effect.add_child(sprite)
	sprite.play("gust")
	sprite.animation_finished.connect(effect.queue_free, CONNECT_ONE_SHOT)
	return effect


func upgrade() -> void:
	weapon_damage *= 1.15
	knockback_force += 15.0
