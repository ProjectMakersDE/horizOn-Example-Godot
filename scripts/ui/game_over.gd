## Game Over Screen - Shows results and submits score
extends Control

@onready var score_label: Label = $Panel/VBox/ScoreLabel
@onready var waves_label: Label = $Panel/VBox/WavesLabel
@onready var level_label: Label = $Panel/VBox/LevelLabel
@onready var coins_label: Label = $Panel/VBox/CoinsLabel
@onready var rank_label: Label = $Panel/VBox/RankLabel
@onready var best_label: Label = $Panel/VBox/BestLabel
@onready var play_again_button: Button = $Panel/VBox/Buttons/PlayAgainButton
@onready var hub_button: Button = $Panel/VBox/Buttons/HubButton
@onready var status_label: Label = $Panel/VBox/StatusLabel


func _ready() -> void:
	AudioManager.play_music("music_menu")

	score_label.text = "Score: %d" % GameManager.current_score
	waves_label.text = "Waves: %d" % GameManager.current_wave
	level_label.text = "Level: %d" % GameManager.current_level
	coins_label.text = "Coins: +%d" % GameManager.run_coins_earned
	rank_label.text = "Loading rank..."
	best_label.text = "Best: %d" % GameManager.highscore

	play_again_button.pressed.connect(_on_play_again)
	hub_button.pressed.connect(_on_hub)

	# Submit score, save data, get rank, log run
	await _submit_results()


func _submit_results() -> void:
	status_label.text = "Saving..."

	# Submit score to leaderboard
	await Horizon.leaderboard.submitScore(GameManager.current_score)

	# Get rank
	var rank_entry := await Horizon.leaderboard.getRank()
	if rank_entry:
		GameManager.user_rank = rank_entry.position
		rank_label.text = "Your Rank: #%d" % rank_entry.position
		best_label.text = "Best: %d (#%d)" % [GameManager.highscore, rank_entry.position]
	else:
		rank_label.text = "Rank: N/A"

	# Save cloud data
	await SaveManager.save_game()

	# Submit user log
	var duration_min := int(GameManager.run_duration) / 60
	var duration_sec := int(GameManager.run_duration) % 60
	var log_msg := "Run ended | Waves: %d | Level: %d | Score: %d | Duration: %dm%02ds | Upgrades: speed:%d,dmg:%d,hp:%d | Coins earned: %d" % [
		GameManager.current_wave,
		GameManager.current_level,
		GameManager.current_score,
		duration_min, duration_sec,
		GameManager.upgrades.get("speed", 0),
		GameManager.upgrades.get("damage", 0),
		GameManager.upgrades.get("hp", 0),
		GameManager.run_coins_earned
	]
	await Horizon.userLogs.info(log_msg)

	# Warn if consecutive early deaths
	if GameManager.should_warn_early_deaths():
		await Horizon.userLogs.warn("Player died in wave 1 three consecutive times - possible balancing issue")

	Horizon.crashes.set_custom_key("last_score", str(GameManager.current_score))
	Horizon.crashes.set_custom_key("last_wave", str(GameManager.current_wave))

	status_label.text = ""


func _on_play_again() -> void:
	Horizon.crashes.record_breadcrumb("navigation", "play_again")
	get_tree().change_scene_to_file("res://scenes/run/survival_run.tscn")


func _on_hub() -> void:
	Horizon.crashes.record_breadcrumb("navigation", "back_to_hub")
	get_tree().change_scene_to_file("res://scenes/hub/hub_screen.tscn")
