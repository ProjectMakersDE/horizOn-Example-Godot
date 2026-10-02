## Feather Throw - Projectile weapon firing in move direction
extends "res://scripts/weapons/weapon_base.gd"

const SpriteSheetHelper = preload("res://scripts/visuals/sprite_sheet_helper.gd")
const WEAPON_TEXTURE = preload("res://assets/sprites/weapons.png")

var projectile_speed: float = 300.0
var projectile_count: int = 1


func _ready() -> void:
	var stats := ConfigCache.get_weapon_stats("feather")
	weapon_damage = float(stats.get("damage", 20.0))
	cooldown = float(stats.get("cooldown", 0.8))
	projectile_count = int(stats.get("projectiles", 1))
	super._ready()


func fire() -> void:
	if owner_node == null:
		return
	AudioManager.play_sfx("sfx_feather")
	for i in projectile_count:
		var proj := _create_projectile()
		var spread := 0.0
		if projectile_count > 1:
			spread = (float(i) - float(projectile_count - 1) / 2.0) * 0.2
		var aim: Vector2 = owner_node.move_direction
		var best_dist := 360.0
		for enemy in get_tree().get_nodes_in_group("enemies"):
			if enemy.is_dead:
				continue
			var distance: float = enemy.global_position.distance_to(owner_node.global_position)
			if distance < best_dist:
				best_dist = distance
				aim = owner_node.global_position.direction_to(enemy.global_position)
		var dir: Vector2 = aim.rotated(spread)
		proj.global_position = owner_node.global_position
		proj.setup(dir, projectile_speed, get_damage())
		get_tree().current_scene.add_child(proj)


func _create_projectile() -> Node2D:
	var proj := Area2D.new()
	proj.name = "FeatherProjectile"
	proj.collision_layer = 4
	proj.collision_mask = 2

	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 4.0
	shape.shape = circle
	proj.add_child(shape)

	var sprite := AnimatedSprite2D.new()
	var frames := SpriteFrames.new()
	SpriteSheetHelper.add_row_animation(frames, "fly", WEAPON_TEXTURE, Vector2i(32, 32), 0, 4, 14.0)
	sprite.sprite_frames = frames
	sprite.play("fly")
	proj.add_child(sprite)

	proj.set_script(preload("res://scripts/weapons/feather_projectile.gd"))
	return proj


func upgrade() -> void:
	weapon_damage *= 1.15
	if projectile_count < 5:
		projectile_count += 1
