## Seagull Screech - AoE ring around player
extends WeaponBase

var radius: float = 80.0


func _ready() -> void:
	var stats := ConfigCache.get_weapon_stats("screech")
	weapon_damage = float(stats.get("damage", 15.0))
	cooldown = float(stats.get("cooldown", 2.0))
	radius = float(stats.get("radius", 80.0))
	super._ready()


func fire() -> void:
	if owner_node == null:
		return
	AudioManager.play_sfx("sfx_screech")

	var effect := _create_screech_effect()
	effect.global_position = owner_node.global_position
	get_tree().current_scene.add_child(effect)

	var enemies := get_tree().get_nodes_in_group("enemies")
	for enemy in enemies:
		if enemy.has_method("take_damage") and not enemy.is_dead:
			var dist := owner_node.global_position.distance_to(enemy.global_position)
			if dist <= radius:
				enemy.take_damage(int(get_damage()))


func _create_screech_effect() -> Node2D:
	var effect := Node2D.new()
	var circle := Sprite2D.new()
	var img := Image.create(int(radius * 2), int(radius * 2), false, Image.FORMAT_RGBA8)
	img.fill(Color(1, 1, 0.4, 0.3))
	var tex := ImageTexture.create_from_image(img)
	circle.texture = tex
	effect.add_child(circle)
	var tween := effect.create_tween()
	tween.tween_property(circle, "modulate:a", 0.0, 0.3)
	tween.tween_callback(effect.queue_free)
	return effect


func upgrade() -> void:
	weapon_damage *= 1.15
	radius += 10.0
