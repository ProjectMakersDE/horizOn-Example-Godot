## Feather Throw - Projectile weapon firing in move direction
extends "res://scripts/weapons/weapon_base.gd"

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
		var dir: Vector2 = owner_node.move_direction.rotated(spread)
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

	var sprite := Sprite2D.new()
	sprite.texture = preload("res://assets/sprites/weapons.png")
	sprite.region_enabled = true
	sprite.region_rect = Rect2(0, 0, 32, 32)
	proj.add_child(sprite)

	var script := GDScript.new()
	script.source_code = """extends Area2D

var direction: Vector2 = Vector2.RIGHT
var speed: float = 300.0
var damage: float = 20.0
var lifetime: float = 2.0

func setup(dir: Vector2, spd: float, dmg: float) -> void:
	direction = dir.normalized()
	speed = spd
	damage = dmg
	rotation = direction.angle()

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	area_entered.connect(_on_area_entered)

func _physics_process(delta: float) -> void:
	position += direction * speed * delta
	lifetime -= delta
	if lifetime <= 0:
		queue_free()

func _on_body_entered(body: Node2D) -> void:
	if body.has_method(\"take_damage\"):
		body.take_damage(int(damage))
		queue_free()

func _on_area_entered(area: Area2D) -> void:
	var parent := area.get_parent()
	if parent.has_method(\"take_damage\"):
		parent.take_damage(int(damage))
		queue_free()
"""
	script.reload()
	proj.set_script(script)
	return proj


func upgrade() -> void:
	weapon_damage *= 1.15
	if projectile_count < 5:
		projectile_count += 1
