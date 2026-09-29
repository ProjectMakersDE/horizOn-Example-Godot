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
@onready var validation_label: Label = $Panel/VBox/ValidationLabel


func _ready() -> void:
	AudioManager.play_music("music_menu")

	var run := GameManager.run_state
	score_label.text = "Score: %d" % run.currentScore
	waves_label.text = "Waves: %d" % run.currentWave
	level_label.text = "Level: %d" % run.currentLevel
	coins_label.text = "Coins: +%d" % run.coinsEarned
	rank_label.text = "Loading rank..."
	best_label.text = "Best: %d" % GameManager.save_data.highscore
	_show_validation()

	play_again_button.pressed.connect(_on_play_again)
	hub_button.pressed.connect(_on_hub)

	await _load_rank()


## Validated Actions: accepted runs show their rank, rejected runs a short
## reason (e.g. "run was too short"). Hidden for a normal run.
func _show_validation() -> void:
	var recorder := GameManager.validated_run
	validation_label.text = recorder.last_message
	validation_label.visible = not recorder.last_message.is_empty()
	if not recorder.last_result.is_empty():
		validation_label.add_theme_color_override("font_color", Color(0.4, 0.9, 0.5))
	elif not recorder.last_error_code.is_empty():
		validation_label.add_theme_color_override("font_color", Color(1, 0.45, 0.4))


func _load_rank() -> void:
	status_label.text = "Loading..."
	# A validated submit already returned the rank on the run's board
	var validated_rank := int(GameManager.validated_run.last_result.get("rank", 0))
	if validated_rank > 0:
		rank_label.text = "Your Rank: #%d" % validated_rank
		var best := int(GameManager.validated_run.last_result.get("bestScore", GameManager.save_data.highscore))
		best_label.text = "Best: %d (#%d)" % [best, validated_rank]
	else:
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
