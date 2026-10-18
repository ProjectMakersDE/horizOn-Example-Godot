## Fixture drives real scenes, input and physics without a backend config.
## Run through python3 tests/run_checks.py for isolated userdata.
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
	var cache = root.get_node("ConfigCache")
	manager.enter_practice()
	var space := InputEventKey.new()
	space.keycode = KEY_SPACE
	space.device = 0
	space.pressed = true
	_check(InputMap.event_is_action(space, "dash"), "Physical keyboard Space maps to dash")
	await preload("res://tests/player_values_safety_smoke.gd").run(self, _check)
	await preload("res://tests/statistics_safety_smoke.gd").run(self, _check)
	manager._save_path = "user://seagull_refresh_qa.json"
	manager.save_data = GameData.new()
	manager.save_data.coins = 20
	_check(manager.buy_upgrade("speed"), "Upgrade should be affordable")
	_check(manager.save_data.coins == 10, "Upgrade charges exact cost")
	cache._configs = {"run_duration_seconds": 20.0, "wave_interval_seconds": 4.0, "boss_wave_enabled": false}
	await manager.start_run()
	await process_frame
	var run = current_scene
	_check(run.name == "SurvivalRun", "Start run changes to survival scene")
	var player = run.get_node("Entities/Player")
	var start: Vector2 = player.position
	Input.action_press("move_right")
	Input.action_press("dash")
	await create_timer(0.3).timeout
	Input.action_release("dash")
	Input.action_release("move_right")
	_check(player.position.x > start.x, "Movement drives native physics")
	_check(manager.run_state.dashes == 1, "Dash triggers once")
	run._toggle_pause()
	_check(paused, "Pause activates")
	run._toggle_pause()
	_check(not paused, "Pause resumes")
	player.add_xp(50)
	_check(paused and run.levelup_panel.visible, "XP opens level-up choices")
	_check(run._choices.size() > 0, "Level-up always offers choices")
	var choice: Dictionary = {"id": "screech_new", "type": "weapon_new"}
	run._apply_levelup_choice(choice, 0)
	_check("seagull_screech" in manager.run_state.activeWeapons, "Level-up can grant additional weapon")
	_check(not paused, "Selecting upgrade resumes the run")
	player.current_hp = 9999
	player.max_hp = 9999
	var time := 0.0
	while is_instance_valid(run) and manager.run_state.duration < 21.0:
		if paused:
			run._apply_levelup_choice(run._choices[0], 0)
		time += 0.25
		Input.action_release("move_left")
		Input.action_release("move_right")
		Input.action_press("move_right" if sin(time) > 0 else "move_left")
		await create_timer(0.25).timeout
		if current_scene != run:
			break
	Input.action_release("move_left")
	Input.action_release("move_right")
	await process_frame
	_check(current_scene.name == "Screen", "Timed run opens results")
	_check(manager.run_state.victory, "No-boss timed run reports victory")
	_check(manager.run_state.currentWave >= 3, "Waves actually spawn")
	_check(manager.run_state.kills > 0, "Auto-aim weapon kills real enemies")
	_check(manager.submission_status.contains("no leaderboard"), "Practice never submits score")
	var coins: int = manager.save_data.coins
	await manager.end_run()
	_check(manager.save_data.coins == coins, "Duplicate run end cannot grant coins twice")
	cache._configs = {"run_duration_seconds": 2.0, "wave_interval_seconds": 1.0, "boss_wave_enabled": true}
	await manager.start_run()
	await process_frame
	var final_run = current_scene
	final_run.player.current_hp = 9999
	final_run.player.max_hp = 9999
	await create_timer(2.4).timeout
	_check(final_run.boss_spawned and is_instance_valid(final_run._boss), "Final boss actually spawns")
	final_run._boss.take_damage(99999)
	await process_frame
	await process_frame
	_check(manager.run_state.victory and current_scene.name == "Screen", "Boss defeat reaches victory results")
	_check(manager.run_state.currentScore == manager.run_state.kills + manager.run_state.xpCollected + int(manager.run_state.duration), "Final score includes the last physics tick and boss kill")
	manager.go_to_hub()
	await process_frame
	_check(current_scene.has_method("_buy_upgrade"), "Results can return to hub")
	DirAccess.remove_absolute("user://seagull_refresh_qa.json")
	if _failures.is_empty():
		print("OFFLINE_SMOKE_PASS: movement, dash, pause, XP, weapons, waves, kills, victory, save isolation, duplicate end, boss spawn/defeat, restart, hub")
	var audio = root.get_node("AudioManager")
	audio.shutdown()
	audio.play_music("music_menu")
	audio.play_sfx("sfx_enemy_hit")
	for child in audio.get_children():
		_check(not child is AudioStreamPlayer or child.stream == null, "Late scene callbacks cannot restart shutdown audio")
	await create_timer(0.15).timeout
	_check(audio.get_child_count() == 0, "Terminal audio shutdown releases its owned player nodes")
	# stop() schedules AudioServer fade-out/deletion on the mixer. Native process
	# exit must wait for those actual references, not just a fixed number of frames.
	var owned_paths := ["res://assets/audio/music/music_menu.ogg", "res://assets/audio/music/music_boss.ogg", "res://assets/audio/sfx/sfx_enemy_hit.ogg"]
	var deadline := Time.get_ticks_msec() + 3000
	while Time.get_ticks_msec() < deadline:
		var pending := false
		for path in owned_paths:
			pending = pending or ResourceLoader.has_cached(path)
		if not pending:
			break
		await process_frame
	for path in owned_paths:
		_check(not ResourceLoader.has_cached(path), "Stopped mixer releases stream resource: " + path)
	print("AUDIO_SHUTDOWN_DRAIN: driver=" + AudioServer.get_driver_name() + " lastMixSeconds=" + str(AudioServer.get_time_since_last_mix()))
	call_deferred("quit", 0 if _failures.is_empty() else 1)
