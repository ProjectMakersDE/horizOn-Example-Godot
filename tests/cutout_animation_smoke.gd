## Exercises the real gameplay hooks with isolated offline userdata.
extends SceneTree

var _failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
		push_error(message)

func _run() -> void:
	await process_frame
	if not str(ProjectSettings.get_setting("application/config/custom_user_dir_name", "")).begins_with("horizon-task913-godot-qa-"):
		push_error("Use tests/run_checks.py: isolated QA userdata is required")
		quit(1)
		return
	var manager = root.get_node("GameManager")
	manager.enter_practice()
	manager._save_path = "user://cutout_qa.json"
	root.get_node("ConfigCache")._configs = {"run_duration_seconds": 120.0, "boss_wave_enabled": false}
	await manager.start_run()
	await process_frame
	var run = current_scene
	var player = run.player
	var rig = player.get_node("Visual")
	_check(rig.has_method("trigger_attack"), "Player renders the cutout rig")
	if not rig.has_method("trigger_attack"):
		quit(1)
		return
	run.wave_spawner.stop_spawning()
	var weapon = run.get_node("Weapons").get_child(0)
	weapon._timer = 99.0
	_check(rig.parts.size() == 7, "Gull renders seven independent parts")
	_check(rig.get_node_or_null("FullSprite") == null and not rig is AnimatedSprite2D, "Gull has no full static sprite")
	_check(rig.texture_filter == CanvasItem.TEXTURE_FILTER_LINEAR and rig.texture_repeat == CanvasItem.TEXTURE_REPEAT_DISABLED, "Cutout parts use linear filtering and clamped edges")
	for part: Node2D in rig.parts.values():
		_check(part.z_index == 0, "All gull parts share their parent's layer for actor overlap")
		_check(part.get_child_count() == 1 and part.get_child(0).texture.resource_path.begins_with("res://assets/shared/cutout/gull/"), "Each gull joint owns only its isolated part texture")
	Input.action_press("move_right")
	await create_timer(0.18).timeout
	_check(rig.motion_state == "walk", "Real player input selects walking")
	_check(absf(rig.parts["leftFoot"].rotation) > 0.02, "Player foot rotates during native movement")
	_check(absf(rig.parts["frontWing"].rotation) > 0.02, "Player wing rotates independently")
	Input.action_release("move_right")
	Input.action_press("move_left")
	await create_timer(0.05).timeout
	_check(rig.facing == -1, "Player cutout faces movement direction")
	Input.action_release("move_left")
	await create_timer(0.05).timeout
	_check(rig.motion_state == "idle", "Stopped player selects idle")
	Input.action_press("move_right")
	weapon._timer = 0.0
	await create_timer(0.25).timeout
	_check(rig.motion_state == "attack", "Actual auto weapon firing selects gull attack")
	_check(absf(rig.parts["frontWing"].rotation) > 0.2, "Attack opens the front wing")
	_check(absf(rig.parts["leftFoot"].rotation) > 0.02 and rig._pose.position.y < rig._pose_origin.y - 0.1, "Real movement and automatic firing preserve the foot cycle and hop together")
	Input.action_release("move_right")
	# The real feather has been fired. Keep it from hurting the crab during
	# the following pursuit/attack assertions, which test separate events.
	weapon._timer = 99.0
	for child in run.get_children():
		if child.name.begins_with("FeatherProjectile"):
			child.queue_free()
	player.take_damage(1)
	await create_timer(0.05).timeout
	_check(rig.motion_state == "hurt", "Actual player damage selects hurt")
	var crab = run.wave_spawner._spawn_enemy("crab")
	crab.position = player.position + Vector2(70, 0)
	var crab_rig = crab.get_node("Visual")
	_check(crab_rig.parts.size() == 9, "Crab renders six legs, two claws and body")
	_check(not crab_rig is AnimatedSprite2D, "Crab has no full static sprite")
	for part: Node2D in crab_rig.parts.values():
		_check(part.z_index == 0, "All crab parts share their parent's layer for actor overlap")
		_check(part.get_child_count() == 1 and part.get_child(0).texture.resource_path.begins_with("res://assets/shared/cutout/crab/"), "Each crab joint owns only its isolated part texture")
	await create_timer(0.18).timeout
	_check(crab_rig.motion_state == "walk", "Crab pursuit selects walking")
	_check(absf(crab_rig.parts["leftBack"].rotation) > 0.02, "Crab leg rotates while pursuing")
	crab._attack()
	await create_timer(0.25).timeout
	_check(crab_rig.motion_state == "attack", "Real melee attack selects crab attack")
	_check(absf(crab_rig.parts["frontClaw"].rotation) > 0.1, "Crab attack moves the claw")
	_check(absf(crab_rig.parts["leftBack"].rotation) > 0.02, "Crab legs keep walking during its melee attack")
	crab.take_damage(1)
	await create_timer(0.05).timeout
	_check(crab_rig.motion_state == "hurt", "Actual crab damage selects hurt")
	run._toggle_pause()
	var gull_rotation: float = rig.parts["frontWing"].rotation
	var crab_rotation: float = crab_rig.parts["leftBack"].rotation
	var gull_time: float = rig.elapsed
	await create_timer(0.2).timeout
	_check(is_equal_approx(gull_rotation, rig.parts["frontWing"].rotation) and is_equal_approx(crab_rotation, crab_rig.parts["leftBack"].rotation), "Pause freezes individual cutout transforms")
	_check(is_equal_approx(gull_time, rig.elapsed), "Pause freezes rig clock")
	run._toggle_pause()
	crab.take_damage(99999)
	await create_timer(0.35).timeout
	_check(not is_instance_valid(crab), "Dead crab and all its parts are freed")
	player._hurt_timer = 0.0
	player.take_damage(99999)
	await create_timer(0.4).timeout
	_check(current_scene != run and current_scene.name == "Screen", "Player death animation reaches results")
	_check(not is_instance_valid(rig), "Scene teardown frees gull parts")
	DirAccess.remove_absolute("user://cutout_qa.json")
	if _failures.is_empty():
		print("CUTOUT_ANIMATION_SMOKE_PASS: independent limbs, gameplay movement/attack/hurt, facing, pause, static sprite absence, death and teardown")
	root.get_node("AudioManager").shutdown()
	await create_timer(0.15).timeout
	call_deferred("quit", 0 if _failures.is_empty() else 1)
