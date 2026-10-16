extends Control

var status_label: Label
var rank_label: Label
var replay: Button
var hub: Button

func _ready() -> void:
	AudioManager.play_music("music_menu")
	var run := GameManager.run_state
	var page := StormUI.page(self, "Island defended!" if run.victory else "The storm won this time", "Every run builds a stronger seagull. Try a different weapon path next time.")
	var row := HBoxContainer.new()
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	page.add_child(row)
	var art := StormUI.card(row, 290)
	StormUI.art(art, "res://assets/shared/seagull_hero.png", 190)
	StormUI.label(art, "ONE MORE\nRUN?", 39, StormUI.ORANGE)
	var result := StormUI.scroll_card(row, 570)
	StormUI.label(result, str(run.currentScore), 64, StormUI.ORANGE)
	StormUI.label(result, "SCORE    /    PERSONAL BEST %d" % GameManager.save_data.highscore, 18)
	var buttons := HBoxContainer.new()
	result.add_child(buttons)
	replay = StormUI.button(buttons, "Play again", _replay, true)
	hub = StormUI.button(buttons, "Spend coins / hub", GameManager.go_to_hub)
	StormUI.label(result, "%02d:%02d survived   ·   wave %d   ·   level %d\n%d %s defeated   ·   %d shell XP collected\n+%d coins   ·   %d coins in your stash" % [int(run.duration) / 60, int(run.duration) % 60, run.currentWave, run.currentLevel, run.kills, "enemy" if run.kills == 1 else "enemies", run.xpCollected, run.coinsEarned, GameManager.save_data.coins], 20)
	rank_label = StormUI.label(result, "Practice scores remain on this device." if GameManager.practice_mode else "Board: " + GameManager.selected_board, 16, StormUI.TEAL)
	status_label = StormUI.label(result, GameManager.submission_status, 16, StormUI.MUTED)
	GameManager.submission_changed.connect(_refresh)
	_refresh()

func _refresh() -> void:
	status_label.text = GameManager.submission_status + "\n" + GameManager.cloud_status
	if not GameManager.validated_run.last_message.is_empty():
		status_label.text = GameManager.validated_run.last_message + "\n" + GameManager.cloud_status
	if not GameManager.practice_mode:
		status_label.text += "\n" + GameManager.statistics_status
	replay.disabled = GameManager.is_finishing()
	hub.disabled = GameManager.is_finishing()
	if not GameManager.is_finishing() and GameManager.online_available():
		var entry = await Horizon.leaderboard.getRank(GameManager.selected_board)
		if not is_instance_valid(self) or not is_instance_valid(rank_label) or not is_inside_tree():
			return
		if entry != null and entry.position > 0:
			rank_label.text = "Board %s · rank #%d · best %d" % [GameManager.selected_board, entry.position, entry.score]

func _replay() -> void:
	replay.disabled = true
	hub.disabled = true
	await GameManager.start_run()
