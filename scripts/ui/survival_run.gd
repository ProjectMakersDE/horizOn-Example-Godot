## Survival Run - Main gameplay scene controller
extends Node2D

@onready var player: CharacterBody2D = $Player
@onready var hud: CanvasLayer = $HUD
@onready var wave_label: Label = $HUD/TopBar/WaveLabel
@onready var timer_label: Label = $HUD/TopBar/TimerLabel
@onready var score_label: Label = $HUD/TopBar/ScoreLabel
@onready var hp_bar: ProgressBar = $HUD/TopBar/HPBar
@onready var xp_bar: ProgressBar = $HUD/BottomBar/XPBar
@onready var level_label: Label = $HUD/TopBar/LevelLabel
@onready var pause_button: Button = $HUD/BottomBar/PauseButton
@onready var pause_menu: Control = $HUD/PauseMenu
@onready var levelup_panel: Control = $HUD/LevelupPanel
@onready var camera: Camera2D = $Player/Camera2D

var wave_manager: Node
var weapon_manager: Node
var run_timer: float = 180.0
var boss_spawned: bool = false


func _ready() -> void:
	AudioManager.play_music("music_battle")
	GameManager.start_run()

	run_timer = ConfigManager.get_float("run_duration_seconds", 180.0)

	# Setup wave manager
	wave_manager = Node.new()
	wave_manager.name = "WaveManager"
	wave_manager.set_script(load("res://scripts/managers/wave_manager.gd"))
	add_child(wave_manager)
	wave_manager.setup(player)

	# Setup weapon manager
	weapon_manager = Node.new()
	weapon_manager.name = "WeaponManager"
	weapon_manager.set_script(load("res://scripts/managers/weapon_manager.gd"))
	add_child(weapon_manager)
	weapon_manager.setup(player)

	# Connect signals
	player.died.connect(_on_player_died)
	player.health_changed.connect(_on_health_changed)
	player.leveled_up.connect(_on_level_up)
	pause_button.pressed.connect(_toggle_pause)
	pause_menu.visible = false
	levelup_panel.visible = false

	# Setup pause menu buttons
	_setup_pause_menu()

	# Generate ground tiles
	_generate_ground()

	_update_hud()


func _process(delta: float) -> void:
	if not GameManager.run_active:
		return

	run_timer -= delta
	GameManager.run_duration += delta
	GameManager.current_score = _calculate_score()

	# Check for boss wave
	if run_timer <= 0 and not boss_spawned:
		run_timer = 0
		if ConfigManager.get_bool("boss_wave_enabled", true):
			boss_spawned = true
			AudioManager.play_music("music_boss")
			wave_manager.spawn_boss()
		else:
			_on_player_died()

	# Attract XP pickups within magnet range
	var magnet_radius := GameManager.get_upgrade_value("magnet")
	var pickups := get_tree().get_nodes_in_group("xp_pickups")
	for pickup in pickups:
		if pickup.has_method("check_magnet"):
			pickup.check_magnet(player, magnet_radius)

	_update_hud()


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		_toggle_pause()


func _update_hud() -> void:
	wave_label.text = "Wave %d" % GameManager.current_wave
	var minutes := int(run_timer) / 60
	var seconds := int(run_timer) % 60
	timer_label.text = "%d:%02d" % [minutes, seconds]
	score_label.text = "Score: %d" % GameManager.current_score
	level_label.text = "Lv. %d" % GameManager.current_level
	xp_bar.value = player.get_xp_progress() * 100.0
	hp_bar.value = float(player.current_hp) / float(player.max_hp) * 100.0


func _calculate_score() -> int:
	var base_xp := ConfigManager.get_int("xp_per_kill_base", 10)
	return GameManager.run_kills * base_xp + GameManager.run_xp_collected + int(GameManager.run_duration)


func _on_health_changed(current: int, maximum: int) -> void:
	hp_bar.value = float(current) / float(maximum) * 100.0


func _on_player_died() -> void:
	GameManager.end_run()
	Horizon.crashes.record_breadcrumb("state", "game_over_wave_%d" % GameManager.current_wave)
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/ui/game_over.tscn")


func _on_level_up(new_level: int) -> void:
	Horizon.crashes.record_breadcrumb("state", "level_%d" % new_level)
	get_tree().paused = true
	_show_levelup_choices()


func _show_levelup_choices() -> void:
	levelup_panel.visible = true

	# Get levelup pool from config
	var pool = ConfigManager.get_json("levelup_pool")
	var num_choices := ConfigManager.get_int("levelup_choices", 3)

	if pool == null or not pool is Array:
		pool = [
			{"id": "feather_dmg", "type": "weapon_upgrade", "weight": 3},
			{"id": "move_speed", "type": "stat_boost", "weight": 2},
			{"id": "max_hp", "type": "stat_boost", "weight": 2}
		]

	# Weighted random selection
	var choices: Array = _weighted_random_select(pool, num_choices)

	# Build UI for choices
	var container := levelup_panel.get_node("Choices")
	_clear_children(container)

	for choice in choices:
		var btn := Button.new()
		btn.text = _get_choice_label(choice)
		btn.custom_minimum_size = Vector2(120, 60)
		btn.pressed.connect(func(): _apply_levelup_choice(choice))
		container.add_child(btn)


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
			match id:
				"feather_dmg":
					weapon_manager.upgrade_weapon("feather_throw")
				"feather_speed":
					# Decrease cooldown
					for w in weapon_manager.weapons:
						if w is preload("res://scripts/weapons/feather_throw.gd"):
							w.cooldown *= 0.85
		"weapon_new":
			match id:
				"screech_new":
					if not weapon_manager.has_weapon("seagull_screech"):
						weapon_manager.add_weapon("seagull_screech")
				"dive_new":
					if not weapon_manager.has_weapon("dive_bomb"):
						weapon_manager.add_weapon("dive_bomb")
				"gust_new":
					if not weapon_manager.has_weapon("wind_gust"):
						weapon_manager.add_weapon("wind_gust")
		"stat_boost":
			match id:
				"move_speed":
					# Temporary boost via a multiplier
					pass  # Handled by upgrade values
				"max_hp":
					player.max_hp += 20
					player.current_hp = mini(player.current_hp + 20, player.max_hp)
				"xp_magnet":
					player.pickup_radius += 15.0
					player.pickup_area.get_node("CollisionShape2D").shape.radius = player.pickup_radius

	levelup_panel.visible = false
	get_tree().paused = false


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
		# Show news in pause menu
		pass
	)
	feedback_btn.pressed.connect(func():
		# Show feedback form
		pass
	)
	quit_btn.pressed.connect(func():
		GameManager.end_run()
		get_tree().paused = false
		get_tree().change_scene_to_file("res://scenes/hub/hub_screen.tscn")
	)


func _generate_ground() -> void:
	# Create a sand-colored background
	var bg := ColorRect.new()
	bg.color = Color("#F2D2A9")
	bg.size = Vector2(2000, 2000)
	bg.position = Vector2(-1000, -1000)
	bg.z_index = -10
	add_child(bg)


func _clear_children(node: Node) -> void:
	for child in node.get_children():
		child.queue_free()
