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

	var run := GameManager.run_state
	score_label.text = "Score: %d" % run.currentScore
	waves_label.text = "Waves: %d" % run.currentWave
	level_label.text = "Level: %d" % run.currentLevel
	coins_label.text = "Coins: +%d" % run.coinsEarned
	rank_label.text = "Loading rank..."
	best_label.text = "Best: %d" % GameManager.save_data.highscore

	play_again_button.pressed.connect(_on_play_again)
	hub_button.pressed.connect(_on_hub)

	await _load_rank()


func _load_rank() -> void:
	status_label.text = "Loading..."
	var rank_entry := await Horizon.leaderboard.getRank()
	if rank_entry:
		rank_label.text = "Your Rank: #%d" % rank_entry.position
		best_label.text = "Best: %d (#%d)" % [GameManager.save_data.highscore, rank_entry.position]
	else:
		rank_label.text = "Rank: N/A"

	Horizon.crashes.set_custom_key("last_score", str(GameManager.run_state.currentScore))
	Horizon.crashes.set_custom_key("last_wave", str(GameManager.run_state.currentWave))
	status_label.text = ""


func _on_play_again() -> void:
	GameManager.start_run()


func _on_hub() -> void:
	GameManager.go_to_hub()
