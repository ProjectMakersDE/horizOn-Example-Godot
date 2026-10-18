## Native renderer captures the real scenes, without a backend or UI scripting.
extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _capture(name: String) -> void:
	print("CAPTURE_BEGIN: ", name)
	await process_frame
	await process_frame
	# Explicit draw also works when macOS has stopped automatic background redraw.
	RenderingServer.force_draw()
	root.get_texture().get_image().save_png("res://tmp/%s.png" % name)
	print("CAPTURE_DONE: ", name)

func _run() -> void:
	await process_frame
	if not str(ProjectSettings.get_setting("application/config/custom_user_dir_name", "")).begins_with("horizon-task913-godot-qa-"):
		push_error("Use tests/run_checks.py --render: isolated QA userdata is required")
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute("res://tmp")
	root.size = Vector2i(1440, 810)
	change_scene_to_file("res://scenes/title/title_screen.tscn")
	await _capture("qa-title")
	var manager = root.get_node("GameManager")
	manager.enter_practice()
	manager._save_path = "user://seagull_render_qa.json"
	manager.save_data = GameData.new()
	manager.go_to_hub()
	await _capture("qa-hub")
	var hub = current_scene
	var button_rect: Rect2 = hub.play_button.get_global_rect()
	assert(button_rect.end.y <= 540.0, "Launch action must remain visible at default viewport")
	var values_lab: Node
	for node in hub.find_children("*", "VBoxContainer", true, false):
		if node.has_method("_player_values"):
			values_lab = node
	assert(values_lab != null)
	values_lab._player_values()
	var values_modal = hub.get_child(hub.get_child_count() - 1)
	await _capture("qa-player-values")
	root.size = Vector2i(960, 540)
	await _capture("qa-player-values-small")
	values_modal.queue_free()
	await process_frame
	values_lab._statistics()
	var statistics_modal = hub.get_child(hub.get_child_count() - 1)
	await _capture("qa-statistics-small")
	statistics_modal.queue_free()
	await process_frame
	await _capture("qa-hub-small")
	await manager.start_run()
	await process_frame
	await create_timer(3.0).timeout
	await _capture("qa-run")
	var run = current_scene
	# Native close-up with overlapping crabs verifies contiguous actor layers
	# and the actual linear-filtered textures instead of a separate mockup.
	for enemy in run.enemies_container.get_children():
		enemy.queue_free()
	run.wave_spawner.stop_spawning()
	run.player.position = Vector2(-30, 0)
	for index in 2:
		var crab = run.wave_spawner._spawn_enemy("crab")
		crab.position = Vector2(28 + index * 9, index * 4)
		crab.speed = 0.0
		crab.get_node("Visual").trigger_attack()
	run.player.visual.trigger_attack()
	run.get_node("Camera2D").zoom = Vector2(3, 3)
	await create_timer(0.25).timeout
	paused = true
	await _capture("qa-cutout-overlap")
	paused = false
	run.get_node("Camera2D").zoom = Vector2.ONE
	run.player.position = Vector2.ZERO
	run.player.add_xp(50)
	await _capture("qa-levelup")
	run._apply_levelup_choice(run._choices[0], 0)
	run._finish_run(false)
	await _capture("qa-results")
	assert(current_scene.replay.get_global_rect().end.y <= 540.0, "Replay action must remain visible")
	manager.validated_run._submit_message = "Score accepted on validated board · rank #2"
	manager.validated_run._evidence_message = "evidence upload failed (EVIDENCE_TOO_LARGE)"
	manager.cloud_status = "Cloud save synced"
	current_scene._refresh()
	await _capture("qa-results-evidence")
	assert(current_scene.replay.get_global_rect().end.y <= 540.0, "Evidence detail must not clip the replay action")
	manager.validated_run._reset()
	manager.go_to_title()
	await _capture("qa-title-small")
	DirAccess.remove_absolute("user://seagull_render_qa.json")
	change_scene_to_file("res://examples/hello_statistics/hello_statistics.tscn")
	await _capture("qa-hello-statistics-small")
	change_scene_to_file("res://examples/hello_features/hello_features.tscn")
	await _capture("qa-hello-current-small")
	var lab_page: Control = Control.new()
	lab_page.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(lab_page)
	var page: VBoxContainer = StormUI.page(lab_page, "Current SDK feature lab", "Existing session only / explicit reads and original confirmations")
	StormUI.scroll_card(page).add_child(preload("res://scripts/ui/feature_lab.gd").new())
	await _capture("qa-feature-lab-small")
	root.size = Vector2i(1440, 810)
	await _capture("qa-feature-lab")
	lab_page.queue_free()
	print("NATIVE_LAYOUT_CAPTURE_PASS: default and 960x540 title/hub, run, cutout overlap, levelup, results")
	root.get_node("AudioManager").shutdown()
	await create_timer(0.15).timeout
	call_deferred("quit",0)
