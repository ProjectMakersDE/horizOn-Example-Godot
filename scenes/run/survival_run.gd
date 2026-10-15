## Survival Run - Main gameplay scene controller
extends Node2D

@onready var player: CharacterBody2D = $Entities/Player
@onready var enemies_container: Node2D = $Entities/Enemies
@onready var pickups_container: Node2D = $Entities/Pickups
@onready var weapons_container: Node2D = $Weapons
@onready var camera: Camera2D = $Camera2D
@onready var wave_spawner: Node = $WaveSpawner

# Native-resolution UI is separate from game-world coordinates.
var hud: Control
var wave_label: Label
var timer_label: Label
var score_label: Label
var hp_bar: ProgressBar
var xp_bar: ProgressBar
var level_label: Label
var pause_button: Button
var pause_menu: Control
var levelup_panel: Control
var dash_label: Label
var toast: Label
var boss_bar: ProgressBar
var _boss: Node = null
var _toast_timer := 0.0
var _choices: Array = []
var _ending := false

var run_timer: float = 180.0
var boss_spawned: bool = false
var _pause_news_panel: Control = null
var _pause_feedback_panel: Control = null


func _ready() -> void:
	_build_ui()
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

	# Fixed arena: the whole island and incoming enemies remain readable.
	camera.position = Vector2.ZERO

	_update_hud()
	if not GameManager.validated_run.last_error_code.is_empty() and not GameManager.validated_run.is_active():
		_show_toast("Validation unavailable · score stays local")


func _process(delta: float) -> void:
	if get_tree().paused or _ending or GameManager.run_ending():
		return
	_toast_timer = maxf(_toast_timer - delta, 0.0)
	toast.visible = _toast_timer > 0
	run_timer -= delta
	GameManager.run_state.duration += delta
	GameManager.run_state.timeRemaining = run_timer
	GameManager.run_state.currentScore = _calculate_score()

	if is_instance_valid(_boss):
		boss_bar.value = float(_boss.hp) / maxf(float(_boss.max_hp), 1.0) * 100.0

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
				_boss = boss
				boss_bar.visible = true
				_show_toast("FINAL WAVE · Defeat the storm octopus!")
		else:
			# No boss configured: the run ends cleanly when the timer expires
			_finish_run(true)
			return

	# Attract XP pickups within magnet range (includes xp_magnet levelup boosts)
	var magnet_radius: float = player.pickup_radius
	var pickups := get_tree().get_nodes_in_group("xp_pickups")
	for pickup in pickups:
		if pickup.has_method("check_magnet"):
			pickup.check_magnet(player, magnet_radius)

	_update_hud()


func _input(event: InputEvent) -> void:
	if levelup_panel != null and levelup_panel.visible and event is InputEventKey and event.pressed:
		var choice_index: int = event.keycode - KEY_1
		if choice_index >= 0 and choice_index < _choices.size():
			_apply_levelup_choice(_choices[choice_index], choice_index)
	if event.is_action_pressed("pause"):
		_toggle_pause()


func _update_hud() -> void:
	var run := GameManager.run_state
	wave_label.text = "Wave %d" % run.currentWave
	var time_left := maxi(int(run_timer), 0)
	var minutes := time_left / 60
	var seconds := time_left % 60
	timer_label.text = "%d:%02d" % [minutes, seconds]
	score_label.text = "SCORE  %d" % run.currentScore
	dash_label.text = "SPACE · DASH READY" if player.dash_cooldown <= 0.0 else "DASH  %.1fs" % player.dash_cooldown
	level_label.text = "Lv. %d" % run.currentLevel
	xp_bar.value = player.get_xp_progress() * 100.0
	hp_bar.value = float(player.current_hp) / float(player.max_hp) * 100.0


func _calculate_score() -> int:
	return GameManager.run_state.kills + GameManager.run_state.xpCollected + int(GameManager.run_state.duration)


func _on_health_changed(current: int, maximum: int) -> void:
	hp_bar.value = float(current) / float(maximum) * 100.0


func _on_player_died() -> void:
	_finish_run(false)


func _on_boss_died(_enemy: Node2D, _pos: Vector2) -> void:
	_finish_run(true)

func _finish_run(victory: bool) -> void:
	if _ending:
		return
	_ending = true
	GameManager.end_run.call_deferred(victory)


func _on_level_up(new_level: int) -> void:
	GameManager.on_levelup(new_level)
	GameManager.run_state.currentLevel = new_level
	get_tree().paused = true
	_show_levelup_choices()


func _on_wave_started(wave_number: int) -> void:
	GameManager.run_state.currentWave = wave_number
	GameManager.on_wave_started(wave_number)
	_show_toast("WAVE %d · Keep moving. Gather shells." % wave_number)


func _show_levelup_choices() -> void:
	levelup_panel.visible = true

	var pool = ConfigCache.get_json("levelup_pool")
	var num_choices := clampi(ConfigCache.get_int("levelup_choices", 3), 1, 3)

	if pool == null or not pool is Array:
		pool = [
			{"id": "feather_dmg", "type": "weapon_upgrade", "weight": 3},
			{"id": "feather_speed", "type": "weapon_upgrade", "weight": 2},
			{"id": "screech_new", "type": "weapon_new", "weight": 2},
			{"id": "dive_new", "type": "weapon_new", "weight": 2},
			{"id": "gust_new", "type": "weapon_new", "weight": 2},
			{"id": "move_speed", "type": "stat_boost", "weight": 2},
			{"id": "max_hp", "type": "stat_boost", "weight": 2},
			{"id": "xp_magnet", "type": "stat_boost", "weight": 1}
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
	_choices = choices

	var container := levelup_panel.get_node("ChoiceContainer")
	_clear_children(container)

	var card_style := _make_card_style()
	for i in choices.size():
		var choice: Dictionary = choices[i]
		var btn := Button.new()
		btn.text = "%d

%s" % [i + 1, _get_choice_label(choice)]
		btn.custom_minimum_size = Vector2(230, 150)
		for style_name in ["normal", "hover", "pressed", "focus"]:
			btn.add_theme_stylebox_override(style_name, card_style)
		btn.pressed.connect(func(): _apply_levelup_choice(choice, i))
		container.add_child(btn)


func _make_card_style() -> StyleBoxFlat:
	return StormUI.box(StormUI.PANEL.lightened(0.08), StormUI.ORANGE)


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


func _apply_levelup_choice(choice: Dictionary, index: int) -> void:
	var id: String = choice.get("id", "")
	var type: String = choice.get("type", "")
	GameManager.validated_run.record_levelup_choice(index)

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
	if _ending or levelup_panel.visible:
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


func _pause_sdk_panel() -> VBoxContainer:
	var panel := VBoxContainer.new()
	panel.visible = false
	panel.process_mode = Node.PROCESS_MODE_ALWAYS
	panel.set_script(load("res://scripts/ui/sdk_panel.gd"))
	$CanvasLayer.add_child(panel)
	return panel

func _show_pause_news() -> void:
	var panel := _pause_sdk_panel()
	await panel._news()
	if is_instance_valid(panel):
		var dialog: VBoxContainer = panel._dialog("Island news")
		StormUI.label(dialog, panel.output.text, 16)

func _show_pause_feedback() -> void:
	_pause_sdk_panel()._feedback()


func _generate_ground() -> void:
	var ground := Sprite2D.new()
	ground.name = "Ground"
	ground.z_index = -10
	ground.texture = load("res://assets/shared/arena_background.png")
	ground.scale = Vector2(960.0 / ground.texture.get_width(), 540.0 / ground.texture.get_height())
	add_child(ground)

func _show_toast(message: String) -> void:
	toast.text = message
	toast.visible = true
	_toast_timer = 3.0

func _build_ui() -> void:
	var canvas := $CanvasLayer
	hud = Control.new()
	hud.theme = StormUI.theme()
	hud.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.add_child(hud)
	var top := PanelContainer.new()
	top.position = Vector2(20, 14)
	top.size = Vector2(920, 58)
	hud.add_child(top)
	var row := HBoxContainer.new()
	top.add_child(row)
	wave_label = StormUI.label(row, "", 20, StormUI.ORANGE)
	timer_label = StormUI.label(row, "", 26)
	timer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	score_label = StormUI.label(row, "", 20)
	score_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	var bottom := PanelContainer.new()
	bottom.position = Vector2(20, 455)
	bottom.size = Vector2(920, 68)
	hud.add_child(bottom)
	var bottom_row := HBoxContainer.new()
	bottom.add_child(bottom_row)
	var hp_col := VBoxContainer.new()
	hp_col.custom_minimum_size.x = 220
	bottom_row.add_child(hp_col)
	StormUI.label(hp_col, "HEALTH", 13, StormUI.MUTED)
	hp_bar = _bar(hp_col, StormUI.ORANGE)
	var xp_col := VBoxContainer.new()
	xp_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bottom_row.add_child(xp_col)
	level_label = StormUI.label(xp_col, "", 13, StormUI.MUTED)
	xp_bar = _bar(xp_col, StormUI.TEAL)
	dash_label = StormUI.label(bottom_row, "SPACE · DASH READY", 15, StormUI.ORANGE)
	pause_button = StormUI.button(bottom_row, "Pause / Esc", func(): pass)
	toast = Label.new()
	toast.position = Vector2(180, 85)
	toast.size = Vector2(600, 42)
	toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toast.add_theme_color_override("font_color", StormUI.NAVY)
	toast.add_theme_font_size_override("font_size", 20)
	hud.add_child(toast)
	boss_bar = _bar(hud, Color("a46184"))
	boss_bar.position = Vector2(300, 128)
	boss_bar.size = Vector2(360, 12)
	boss_bar.visible = false
	pause_menu = _overlay(canvas)
	var pause_column := VBoxContainer.new()
	pause_column.name = "VBox"
	pause_column.position = Vector2(335, 135)
	pause_column.size = Vector2(290, 270)
	pause_menu.add_child(pause_column)
	StormUI.label(pause_column, "TAKE A BREATHER", 27)
	for entry in [["ResumeButton", "Resume"], ["NewsButton", "News"], ["FeedbackButton", "Feedback"], ["QuitButton", "Abandon run / hub"]]:
		var button := StormUI.button(pause_column, entry[1], func(): pass)
		button.name = entry[0]
		button.disabled = GameManager.practice_mode and entry[0] in ["NewsButton", "FeedbackButton"]
	levelup_panel = _overlay(canvas)
	var title := StormUI.label(levelup_panel, "LEVEL UP · Choose your advantage", 30, StormUI.ORANGE)
	title.position = Vector2(150, 125)
	title.size = Vector2(660, 50)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var choices := HBoxContainer.new()
	choices.name = "ChoiceContainer"
	choices.position = Vector2(100, 200)
	choices.size = Vector2(760, 160)
	choices.alignment = BoxContainer.ALIGNMENT_CENTER
	levelup_panel.add_child(choices)
	var hint := StormUI.label(levelup_panel, "Click a card or press 1 / 2 / 3", 18, StormUI.MUTED)
	hint.position = Vector2(280, 390)
	hint.size = Vector2(400, 40)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

func _overlay(canvas: Node) -> Control:
	var layer := Control.new()
	layer.theme = StormUI.theme()
	layer.process_mode = Node.PROCESS_MODE_ALWAYS
	layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	canvas.add_child(layer)
	var shade := ColorRect.new()
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.color = Color(0.07, 0.065, 0.075, 0.91)
	layer.add_child(shade)
	return layer

func _bar(parent: Node, color: Color) -> ProgressBar:
	var result := ProgressBar.new()
	result.show_percentage = false
	result.custom_minimum_size.y = 12
	result.add_theme_stylebox_override("background", StormUI.box(StormUI.NAVY))
	result.add_theme_stylebox_override("fill", StormUI.box(color))
	parent.add_child(result)
	return result


func _clear_children(node: Node) -> void:
	for child in node.get_children():
		child.queue_free()
