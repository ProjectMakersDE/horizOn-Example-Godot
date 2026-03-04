## Wind Gust - Knockback wave all around
extends WeaponBase

var knockback_force: float = 60.0
var gust_radius: float = 100.0


func _ready() -> void:
	weapon_damage = ConfigManager.get_float("weapon_gust_damage", 10.0)
	cooldown = ConfigManager.get_float("weapon_gust_cooldown", 2.5)
	knockback_force = ConfigManager.get_float("weapon_gust_knockback", 60.0)
	super._ready()


func fire() -> void:
	if owner_node == null:
		return
	AudioManager.play_sfx("sfx_gust")

	# Visual effect
	var effect := _create_gust_effect()
	effect.global_position = owner_node.global_position
	get_tree().current_scene.add_child(effect)

	# Damage and knockback all nearby enemies
	var enemies := get_tree().get_nodes_in_group("enemies")
	for enemy in enemies:
		if enemy is EnemyBase and not enemy.is_dead:
			var dist := owner_node.global_position.distance_to(enemy.global_position)
			if dist <= gust_radius:
				enemy.take_damage(int(get_damage()))
				# Apply knockback
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
