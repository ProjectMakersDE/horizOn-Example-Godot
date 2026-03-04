## Wind Gust - Knockback wave all around
extends "res://scripts/weapons/weapon_base.gd"

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
	var circle := Sprite2D.new()
	var r := int(gust_radius * 2)
	var img := Image.create(r, r, false, Image.FORMAT_RGBA8)
	img.fill(Color(0.78, 1.0, 0.78, 0.25))
	var tex := ImageTexture.create_from_image(img)
	circle.texture = tex
	effect.add_child(circle)
	var tween := effect.create_tween()
	tween.tween_property(circle, "scale", Vector2(1.5, 1.5), 0.3)
	tween.parallel().tween_property(circle, "modulate:a", 0.0, 0.3)
	tween.tween_callback(effect.queue_free)
	return effect


func upgrade() -> void:
	weapon_damage *= 1.15
	knockback_force += 15.0
