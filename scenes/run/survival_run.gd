## Survival Run - Main gameplay scene controller
extends Node2D

@onready var player: CharacterBody2D = $Entities/Player
@onready var enemies_container: Node2D = $Entities/Enemies
@onready var pickups_container: Node2D = $Entities/Pickups
@onready var weapons_container: Node2D = $Weapons
@onready var camera: Camera2D = $Camera2D
@onready var wave_spawner: Node = $WaveSpawner

# HUD references
@onready var hud: Control = $CanvasLayer/HUD
@onready var wave_label: Label = $CanvasLayer/HUD/TopBar/WaveLabel
@onready var timer_label: Label = $CanvasLayer/HUD/TopBar/TimerLabel
@onready var score_label: Label = $CanvasLayer/HUD/TopBar/ScoreLabel
@onready var hp_bar: TextureProgressBar = $CanvasLayer/HUD/HPBar
@onready var xp_bar: TextureProgressBar = $CanvasLayer/HUD/XPBar
@onready var level_label: Label = $CanvasLayer/HUD/LevelLabel
@onready var pause_button: Button = $CanvasLayer/HUD/PauseButton
@onready var pause_menu: Control = $CanvasLayer/PauseMenu
@onready var levelup_panel: Control = $CanvasLayer/LevelupOverlay

var run_timer: float = 180.0
var boss_spawned: bool = false
var _pause_news_panel: Control = null
var _pause_feedback_panel: Control = null


func _ready() -> void:
	AudioManager.play_music("music_battle")

	run_timer = ConfigCache.get_float("run_duration_seconds", 180.0)
	GameManager.run_state.timeRemaining = run_timer

	# Connect player signals
	player.died.connect(_on_player_died)
	player.health_changed.connect(_on_health_changed)
	player.leveled_up.connect(_on_level_up)
	pause_button.pressed.connect(_toggle_pause)
	pause_menu.visible = false
	levelup_panel.visible = false

	# Setup wave spawner
	wave_spawner.setup(player, enemies_container, pickups_container)
	wave_spawner.wave_started.connect(_on_wave_started)

	# Setup pause menu buttons
	_setup_pause_menu()

	# Add starting weapon
	_add_weapon("feather_throw")

	# Generate ground
	_generate_ground()

	# Camera follows player
	camera.position = player.position

	_update_hud()


func _process(delta: float) -> void:
	run_timer -= delta
	GameManager.run_state.duration += delta
	GameManager.run_state.timeRemaining = run_timer
	GameManager.run_state.currentScore = _calculate_score()

	# Camera follow
	camera.position = player.position

	# Check for boss wave
	if run_timer <= 0 and not boss_spawned:
		boss_spawned = true
		run_timer = 0
		wave_spawner.stop_spawning()
		if ConfigCache.get_bool("boss_wave_enabled", true):
			AudioManager.play_music("music_boss")
			var boss: Node = wave_spawner.spawn_boss()
			if boss != null and boss.has_signal("died"):
				boss.connect("died", _on_boss_died)
		else:
			# No boss configured: the run ends cleanly when the timer expires
			GameManager.end_run()
			return

	# Attract XP pickups within magnet range (includes xp_magnet levelup boosts)
	var magnet_radius: float = player.pickup_radius
	var pickups := get_tree().get_nodes_in_group("xp_pickups")
	for pickup in pickups:
		if pickup.has_method("check_magnet"):
			pickup.check_magnet(player, magnet_radius)

	_update_hud()


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		_toggle_pause()


func _update_hud() -> void:
	var run := GameManager.run_state
	wave_label.text = "Wave %d" % run.currentWave
	var time_left := maxi(int(run_timer), 0)
	var minutes := time_left / 60
	var seconds := time_left % 60
	timer_label.text = "%d:%02d" % [minutes, seconds]
	score_label.text = "Score: %d" % run.currentScore
	level_label.text = "Lv. %d" % run.currentLevel
	xp_bar.value = player.get_xp_progress() * 100.0
	hp_bar.value = float(player.current_hp) / float(player.max_hp) * 100.0


func _calculate_score() -> int:
	return GameManager.run_state.kills + GameManager.run_state.xpCollected + int(GameManager.run_state.duration)


func _on_health_changed(current: int, maximum: int) -> void:
	hp_bar.value = float(current) / float(maximum) * 100.0


func _on_player_died() -> void:
	GameManager.end_run()


func _on_boss_died(_enemy: Node2D, _pos: Vector2) -> void:
	GameManager.end_run()


func _on_level_up(new_level: int) -> void:
	GameManager.on_levelup(new_level)
	GameManager.run_state.currentLevel = new_level
	get_tree().paused = true
	_show_levelup_choices()


func _on_wave_started(wave_number: int) -> void:
	GameManager.run_state.currentWave = wave_number
	GameManager.on_wave_started(wave_number)


func _show_levelup_choices() -> void:
	levelup_panel.visible = true

	var pool = ConfigCache.get_json("levelup_pool")
	var num_choices := ConfigCache.get_int("levelup_choices", 3)

	if pool == null or not pool is Array:
		pool = [
			{"id": "feather_dmg", "type": "weapon_upgrade", "weight": 3},
			{"id": "move_speed", "type": "stat_boost", "weight": 2},
			{"id": "max_hp", "type": "stat_boost", "weight": 2}
		]

	# Filter out new-weapon choices whose weapon is already active
	var available: Array = []
	for entry in pool:
		if entry.get("type", "") == "weapon_new":
			var weapon_id := _weapon_id_for_choice(entry.get("id", ""))
			if weapon_id.is_empty() or weapon_id in GameManager.run_state.activeWeapons:
				continue
		available.append(entry)

	# Guard against a pathological remote config (e.g. only weapon_new entries
	# for weapons already active): never pause with zero choices
	if available.is_empty():
		available = [
			{"id": "max_hp", "type": "stat_boost", "weight": 1},
			{"id": "move_speed", "type": "stat_boost", "weight": 1}
		]

	var choices: Array = _weighted_random_select(available, num_choices)

	var container := levelup_panel.get_node("ChoiceContainer")
	_clear_children(container)

	var card_style := _make_card_style()
	for choice in choices:
		var btn := Button.new()
		btn.text = _get_choice_label(choice)
		btn.custom_minimum_size = Vector2(100, 90)
		for style_name in ["normal", "hover", "pressed", "focus"]:
			btn.add_theme_stylebox_override(style_name, card_style)
		btn.pressed.connect(func(): _apply_levelup_choice(choice))
		container.add_child(btn)


func _make_card_style() -> StyleBoxTexture:
	# Upgrade card frame from ui.png, 9-slice safe margins 18 px top / 6 px others
	var style := StyleBoxTexture.new()
	style.texture = preload("res://assets/sprites/ui.png")
	style.region_rect = Rect2(0, 96, 64, 80)
	style.texture_margin_left = 6.0
	style.texture_margin_top = 18.0
	style.texture_margin_right = 6.0
	style.texture_margin_bottom = 6.0
	return style


func _weapon_id_for_choice(choice_id: String) -> String:
	match choice_id:
		"screech_new": return "seagull_screech"
		"dive_new": return "dive_bomb"
		"gust_new": return "wind_gust"
	return ""


func _weighted_random_select(pool: Array, count: int) -> Array:
	var result: Array = []
	var remaining := pool.duplicate(true)
	for i in mini(count, remaining.size()):
		var total_weight: float = 0.0
		for item in remaining:
			total_weight += float(item.get("weight", 1))
		var roll := randf() * total_weight
		var cumulative: float = 0.0
		for j in remaining.size():
			cumulative += float(remaining[j].get("weight", 1))
			if roll <= cumulative:
				result.append(remaining[j])
				remaining.remove_at(j)
				break
	return result


func _get_choice_label(choice: Dictionary) -> String:
	var id: String = choice.get("id", "")
	match id:
		"feather_dmg": return "Feather+\nDMG +15%"
		"feather_speed": return "Feather+\nSpeed +15%"
		"screech_new": return "NEW!\nScreech AoE"
		"dive_new": return "NEW!\nDive Bomb"
		"gust_new": return "NEW!\nWind Gust"
		"move_speed": return "Speed+\nMove +10%"
		"max_hp": return "HP+\nMax HP +20"
		"xp_magnet": return "Magnet+\nRadius +15"
	return id


func _apply_levelup_choice(choice: Dictionary) -> void:
	var id: String = choice.get("id", "")
	var type: String = choice.get("type", "")

	AudioManager.play_sfx("sfx_upgrade_select")
	Horizon.crashes.record_breadcrumb("user_action", "levelup_%s" % id)

	match type:
		"weapon_upgrade":
			for w in weapons_container.get_children():
				if w.has_method("fire"):
					match id:
						"feather_speed":
							if w.weapon_id == "feather_throw":
								w.projectile_speed *= 1.15
						"feather_dmg":
							if w.weapon_id == "feather_throw":
								w.upgrade()
						_:
							w.upgrade()
		"weapon_new":
			var new_weapon_id := _weapon_id_for_choice(id)
			if not new_weapon_id.is_empty():
				_add_weapon(new_weapon_id)
		"stat_boost":
			match id:
				"move_speed":
					player.speed_multiplier += 0.1
				"max_hp":
					player.max_hp += 20
					player.current_hp = mini(player.current_hp + 20, player.max_hp)
				"xp_magnet":
					player.increase_pickup_radius(15.0)

	levelup_panel.visible = false
	get_tree().paused = false


func _add_weapon(weapon_id: String) -> void:
	if weapon_id in GameManager.run_state.activeWeapons:
		return
	var path := "res://scripts/weapons/%s.gd" % weapon_id
	if not ResourceLoader.exists(path):
		return
	var weapon := Node2D.new()
	weapon.set_script(load(path))
	weapon.weapon_id = weapon_id
	weapon.owner_node = player
	weapons_container.add_child(weapon)
	GameManager.run_state.activeWeapons.append(weapon_id)


func _toggle_pause() -> void:
	if levelup_panel.visible:
		return
	get_tree().paused = not get_tree().paused
	pause_menu.visible = get_tree().paused


func _setup_pause_menu() -> void:
	var resume_btn := pause_menu.get_node("VBox/ResumeButton")
	var news_btn := pause_menu.get_node("VBox/NewsButton")
	var feedback_btn := pause_menu.get_node("VBox/FeedbackButton")
	var quit_btn := pause_menu.get_node("VBox/QuitButton")

	resume_btn.pressed.connect(func():
		get_tree().paused = false
		pause_menu.visible = false
	)
	news_btn.pressed.connect(func():
		_show_pause_news()
	)
	feedback_btn.pressed.connect(func():
		_show_pause_feedback()
	)
	quit_btn.pressed.connect(func():
		get_tree().paused = false
		GameManager.go_to_hub()
	)


func _show_pause_news() -> void:
	if _pause_news_panel != null:
		_pause_news_panel.visible = true
		return
	# Create a simple news panel overlay
	_pause_news_panel = PanelContainer.new()
	_pause_news_panel.set_anchors_preset(Control.PRESET_CENTER)
	_pause_news_panel.offset_left = -140.0
	_pause_news_panel.offset_top = -80.0
	_pause_news_panel.offset_right = 140.0
	_pause_news_panel.offset_bottom = 80.0
	_pause_news_panel.process_mode = Node.PROCESS_MODE_ALWAYS

	var vbox := VBoxContainer.new()
	var title := Label.new()
	title.text = "NEWS"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	var news_list := VBoxContainer.new()
	news_list.name = "NewsList"
	news_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(news_list)

	var close_btn := Button.new()
	close_btn.text = "Close"
	close_btn.pressed.connect(func(): _pause_news_panel.visible = false)
	vbox.add_child(close_btn)

	_pause_news_panel.add_child(vbox)
	pause_menu.add_child(_pause_news_panel)

	# Use cached news from hub loading instead of making a new request
	var entries = Horizon.news.getCachedNews()
	if entries.is_empty():
		# Fallback: load from server if cache is empty
		entries = await Horizon.news.loadNews(5, "en")
	for entry in entries:
		var label := Label.new()
		var date_str := _short_date(entry.releaseDate)
		if date_str.is_empty():
			label.text = "* %s" % entry.title
		else:
			label.text = "* %s (%s)" % [entry.title, date_str]
		label.add_theme_font_size_override("font_size", 6)
		news_list.add_child(label)


func _short_date(release_date: String) -> String:
	# ISO timestamps like "2026-07-02T10:30:00Z" -> "2026-07-02"
	if release_date.length() >= 10:
		return release_date.substr(0, 10)
	return release_date


func _show_pause_feedback() -> void:
	if _pause_feedback_panel != null:
		_pause_feedback_panel.visible = true
		return
	# Create a simple feedback dialog overlay
	_pause_feedback_panel = PanelContainer.new()
	_pause_feedback_panel.set_anchors_preset(Control.PRESET_CENTER)
	_pause_feedback_panel.offset_left = -140.0
	_pause_feedback_panel.offset_top = -100.0
	_pause_feedback_panel.offset_right = 140.0
	_pause_feedback_panel.offset_bottom = 100.0
	_pause_feedback_panel.process_mode = Node.PROCESS_MODE_ALWAYS

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)

	var title_lbl := Label.new()
	title_lbl.text = "FEEDBACK"
	title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title_lbl)

	var title_input := LineEdit.new()
	title_input.name = "TitleInput"
	title_input.placeholder_text = "Title..."
	vbox.add_child(title_input)

	var msg_input := TextEdit.new()
	msg_input.name = "MessageInput"
	msg_input.placeholder_text = "Your message..."
	msg_input.custom_minimum_size = Vector2(0, 50)
	vbox.add_child(msg_input)

	var email_input := LineEdit.new()
	email_input.name = "EmailInput"
	email_input.placeholder_text = "Email (optional)..."
	vbox.add_child(email_input)

	var category := OptionButton.new()
	category.name = "CategoryOption"
	category.add_item("BUG", 0)
	category.add_item("FEATURE_REQUEST", 1)
	category.add_item("GENERAL", 2)
	vbox.add_child(category)

	var status_lbl := Label.new()
	status_lbl.name = "StatusLabel"
	status_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(status_lbl)

	var btn_row := HBoxContainer.new()
	var submit_btn := Button.new()
	submit_btn.text = "Submit"
	submit_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var close_btn := Button.new()
	close_btn.text = "Close"
	close_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_row.add_child(submit_btn)
	btn_row.add_child(close_btn)
	vbox.add_child(btn_row)

	close_btn.pressed.connect(func(): _pause_feedback_panel.visible = false)
	submit_btn.pressed.connect(func():
		var t := title_input.text.strip_edges()
		var m := msg_input.text.strip_edges()
		if t.is_empty() or m.is_empty():
			status_lbl.text = "Fill in title and message."
			return
		var cat := category.get_item_text(category.selected)
		var em := email_input.text.strip_edges()
		status_lbl.text = "Submitting..."
		submit_btn.disabled = true
		var success := await Horizon.feedback.submit(t, m, cat, em)
		if success:
			status_lbl.text = "Feedback sent!"
			title_input.text = ""
			msg_input.text = ""
			email_input.text = ""
			Horizon.crashes.record_breadcrumb("user_action", "submitted_feedback_pause")
		else:
			status_lbl.text = "Failed to send."
		submit_btn.disabled = false
	)

	_pause_feedback_panel.add_child(vbox)
	pause_menu.add_child(_pause_feedback_panel)


func _generate_ground() -> void:
	var tilemap := TileMapLayer.new()
	tilemap.name = "Ground"
	tilemap.z_index = -10

	var tileset := TileSet.new()
	tileset.tile_size = Vector2i(16, 16)

	var source := TileSetAtlasSource.new()
	source.texture = preload("res://assets/sprites/tilemap.png")
	source.texture_region_size = Vector2i(16, 16)
	# Register every tile of the 8x4 atlas so set_cell can reference them
	for cx in 8:
		for cy in 4:
			source.create_tile(Vector2i(cx, cy))
	tileset.add_source(source, 0)

	tilemap.tile_set = tileset

	# Sand variants (row 0, cols 0-3), v1 weighted highest
	var sand_variants: Array[Vector2i] = [
		Vector2i(0, 0), Vector2i(0, 0), Vector2i(0, 0), Vector2i(0, 0),
		Vector2i(1, 0), Vector2i(2, 0), Vector2i(3, 0),
	]

	# Fill a 125x125 tile area (2000x2000 pixels / 16px tiles) centered at origin:
	# sand island interior with a water-edge border ring (row 1) and sparse
	# sand decorations (row 0, cols 4-7).
	var half := 62
	for x in range(-half, half + 1):
		for y in range(-half, half + 1):
			var is_north := y == -half
			var is_south := y == half
			var is_west := x == -half
			var is_east := x == half
			var atlas: Vector2i
			if is_north and is_west:
				atlas = Vector2i(4, 1)  # water corner NW
			elif is_north and is_east:
				atlas = Vector2i(5, 1)  # water corner NE
			elif is_south and is_west:
				atlas = Vector2i(6, 1)  # water corner SW
			elif is_south and is_east:
				atlas = Vector2i(7, 1)  # water corner SE
			elif is_north:
				atlas = Vector2i(0, 1)  # water edge N
			elif is_south:
				atlas = Vector2i(1, 1)  # water edge S
			elif is_east:
				atlas = Vector2i(2, 1)  # water edge E
			elif is_west:
				atlas = Vector2i(3, 1)  # water edge W
			elif randf() < 0.03:
				atlas = Vector2i(4 + randi() % 4, 0)  # sand decoration
			else:
				atlas = sand_variants[randi() % sand_variants.size()]
			tilemap.set_cell(Vector2i(x, y), 0, atlas)

	add_child(tilemap)


func _clear_children(node: Node) -> void:
	for child in node.get_children():
		child.queue_free()
