## Dive Bomb - Dash-damage in move direction
extends "res://scripts/weapons/weapon_base.gd"

const SpriteSheetHelper = preload("res://scripts/visuals/sprite_sheet_helper.gd")
const WEAPON_TEXTURE = preload("res://assets/sprites/weapons.png")

var dive_range: float = 120.0
var dive_width: float = 30.0


func _ready() -> void:
	var stats := ConfigCache.get_weapon_stats("dive")
	weapon_damage = float(stats.get("damage", 50.0))
	cooldown = float(stats.get("cooldown", 3.0))
	dive_range = float(stats.get("range", 120.0))
	super._ready()


func fire() -> void:
	if owner_node == null:
		return
	AudioManager.play_sfx("sfx_dive")

	var dir: Vector2 = owner_node.move_direction.normalized()
	var start_pos := owner_node.global_position

	var effect := AnimatedSprite2D.new()
	var frames := SpriteFrames.new()
	SpriteSheetHelper.add_row_animation(frames, "dive", WEAPON_TEXTURE, Vector2i(32, 32), 2, 4, 14.0, false)
	effect.sprite_frames = frames
	effect.global_position = start_pos + dir * 18.0
	effect.rotation = dir.angle()
	effect.scale = Vector2.ONE * max(dive_width / 20.0, 1.0)
	get_tree().current_scene.add_child(effect)
	effect.play("dive")
	effect.animation_finished.connect(effect.queue_free, CONNECT_ONE_SHOT)

	var enemies := get_tree().get_nodes_in_group("enemies")
	for enemy in enemies:
		if enemy.has_method("take_damage") and not enemy.is_dead:
			var to_enemy := enemy.global_position - start_pos
			var along := to_enemy.dot(dir)
			var perp := abs(to_enemy.dot(dir.orthogonal()))
			if along >= 0 and along <= dive_range and perp <= dive_width:
				enemy.take_damage(int(get_damage()))


func upgrade() -> void:
	weapon_damage *= 1.15
	dive_range += 20.0
