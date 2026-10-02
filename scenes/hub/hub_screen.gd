extends Control

var coins_label: Label
var best_label: Label
var status_label: Label
var upgrade_buttons: Dictionary = {}
var leaderboard_list: VBoxContainer
var board_picker: OptionButton
var view_picker: OptionButton
var rank_label: Label
var validated_toggle: CheckButton
var play_button: Button
var _boards: Array = []
var _loading := false

func _ready() -> void:
	AudioManager.play_music("music_menu")
	var page := StormUI.page(self, "Seagull Storm", "BUILD YOUR NEXT RUN  /  " + ("Offline practice • local progression" if GameManager.practice_mode else "Online • player session active"))
	var stats := HBoxContainer.new()
	page.add_child(stats)
	coins_label = StormUI.label(stats, "", 23, StormUI.ORANGE)
	best_label = StormUI.label(stats, "", 23)
	StormUI.button(stats, "Account / offline", GameManager.go_to_title)
	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	page.add_child(body)
	var upgrades := StormUI.scroll_card(body, 300)
	StormUI.label(upgrades, "Island upgrades", 23)
	play_button = StormUI.button(upgrades, "Launch survival run", _play, true)
	StormUI.label(upgrades, "Every run earns coins. Pick a lasting advantage, then find a new weapon build on the beach.", 16, StormUI.MUTED)
	for key in ["speed", "damage", "hp", "magnet"]:
		var button := StormUI.button(upgrades, "", func(): _buy_upgrade(key))
		button.add_theme_font_size_override("font_size", 15)
		upgrade_buttons[key] = button
	StormUI.label(upgrades, "WASD / arrows • Space dash (3 sec recharge)\nAuto-aim attacks • Collect shells to choose upgrades", 14, StormUI.MUTED)
	var tabs := TabContainer.new()
	tabs.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(tabs)
	var boards := VBoxContainer.new()
	boards.name = "Leaderboards"
	tabs.add_child(boards)
	var options := HBoxContainer.new()
	boards.add_child(options)
	board_picker = OptionButton.new()
	board_picker.add_item("Default board")
	board_picker.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	options.add_child(board_picker)
	view_picker = OptionButton.new()
	view_picker.add_item("Top 10")
	view_picker.add_item("Around me ±5")
	options.add_child(view_picker)
	StormUI.button(options, "Refresh", _refresh_leaderboard)
	board_picker.item_selected.connect(_select_board)
	view_picker.item_selected.connect(func(_index): _refresh_leaderboard())
	validated_toggle = CheckButton.new()
	validated_toggle.text = "Request server-validated run"
	validated_toggle.disabled = GameManager.practice_mode
	validated_toggle.button_pressed = GameManager.validation_requested
	validated_toggle.toggled.connect(func(enabled): GameManager.validation_requested = enabled)
	boards.add_child(validated_toggle)
	rank_label = StormUI.label(boards, "Sign in to view your rank and available boards." if GameManager.practice_mode else "Loading boards…", 16, StormUI.TEAL)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	boards.add_child(scroll)
	leaderboard_list = VBoxContainer.new()
	leaderboard_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(leaderboard_list)
	StormUI.label(boards, "Validated runs use a server ticket and evidence log. A refused ticket or score is never retried as a standard score.", 14, StormUI.MUTED)
	var sdk_scroll := ScrollContainer.new()
	sdk_scroll.name = "SDK lab"
	tabs.add_child(sdk_scroll)
	var lab := VBoxContainer.new()
	lab.set_script(load("res://scripts/ui/sdk_panel.gd"))
	lab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sdk_scroll.add_child(lab)
	status_label = StormUI.label(page, "", 14, StormUI.MUTED)
	GameManager.locale_changed.connect(_update_locale)
	_update_locale()
	GameManager.coins_changed.connect(func(_coins): _update_ui())
	GameManager.highscore_changed.connect(func(_best): _update_ui())
	_update_ui()
	await _load_data()

func _load_data() -> void:
	if GameManager.practice_mode:
		status_label.text = "Practice save ready. Leaderboards and SDK lab need an online project."
		return
	play_button.disabled = true
	status_label.text = "Loading balancing and cloud save…"
	await ConfigCache.load_all()
	if not is_instance_valid(self) or not is_inside_tree():
		return
	if GameManager.selected_board == "default":
		GameManager.selected_board = ConfigCache.get_string("validated_runs_board", "default")
	await GameManager.load_save_data()
	if not is_instance_valid(self) or not is_inside_tree():
		return
	validated_toggle.button_pressed = GameManager.validation_requested or ConfigCache.get_bool("validated_runs_enabled", false)
	GameManager.validation_requested = validated_toggle.button_pressed
	_boards = await Horizon.leaderboard.listBoards()
	if not is_instance_valid(self) or not is_inside_tree():
		return
	board_picker.clear()
	if _boards.is_empty():
		_boards = [{"key": "default", "name": "Default", "validatedOnly": false}]
	for i in _boards.size():
		var board: Dictionary = _boards[i]
		board_picker.add_item(str(board.get("name", board.get("key", "default"))) + (" · validated" if board.get("validatedOnly", false) else ""))
		if str(board.get("key", "default")) == GameManager.selected_board:
			board_picker.select(i)
	_select_board(board_picker.selected)
	play_button.disabled = false
	_update_ui()
	status_label.text = GameManager.cloud_status

func _select_board(index: int) -> void:
	if index < 0 or index >= _boards.size():
		return
	GameManager.selected_board = str(_boards[index].get("key", "default"))
	var validated_only: bool = _boards[index].get("validatedOnly", false)
	validated_toggle.disabled = validated_only or GameManager.practice_mode
	if validated_only:
		validated_toggle.button_pressed = true
		GameManager.validation_requested = true
	_refresh_leaderboard()

func _refresh_leaderboard() -> void:
	if _loading or not GameManager.online_available():
		return
	_loading = true
	var requested_board := GameManager.selected_board
	rank_label.text = "Refreshing board %s…" % GameManager.selected_board
	var entries: Array
	if view_picker.selected == 1:
		entries = await Horizon.leaderboard.getAround(5, false, requested_board)
	else:
		entries = await Horizon.leaderboard.getTop(10, false, requested_board)
	if not is_instance_valid(self) or not is_inside_tree():
		return
	StormUI.clear(leaderboard_list)
	if entries.is_empty():
		StormUI.label(leaderboard_list, "No entries returned. The board may be empty or unavailable.", 17, StormUI.MUTED)
	for entry in entries:
		var row := HBoxContainer.new()
		leaderboard_list.add_child(row)
		StormUI.label(row, "#%02d" % entry.position, 19, StormUI.ORANGE)
		StormUI.label(row, entry.username, 18)
		StormUI.label(row, str(entry.score), 19, StormUI.TEAL)
	var rank = await Horizon.leaderboard.getRank(requested_board)
	if not is_instance_valid(self) or not is_inside_tree():
		return
	rank_label.text = "Your rank: #%d · best score %d" % [rank.position, rank.score] if rank != null and rank.position > 0 else "You have no rank yet, or the rank request was unavailable."
	_loading = false
	if GameManager.selected_board != requested_board:
		_refresh_leaderboard.call_deferred()

func _update_ui() -> void:
	coins_label.text = "%d COINS" % GameManager.save_data.coins
	best_label.text = "PERSONAL BEST  %d" % GameManager.save_data.highscore
	var names := {"speed": "Tailwind / move faster", "damage": "Sharp feathers / more damage", "hp": "Sea legs / more health", "magnet": "Shell collector / larger radius"}
	for key in upgrade_buttons:
		var button: Button = upgrade_buttons[key]
		var level: int = GameManager.save_data.upgrades.get(key, 0)
		button.text = "%s  ·  %d/5\n%s" % [names[key], level, "MAXED" if GameManager.is_upgrade_maxed(key) else "%d coins" % GameManager.get_upgrade_cost(key)]
		button.disabled = not GameManager.can_afford_upgrade(key)

func _buy_upgrade(key: String) -> void:
	if GameManager.buy_upgrade(key):
		AudioManager.play_sfx("sfx_upgrade_select")
		_update_ui()
		if not GameManager.practice_mode:
			await GameManager.save_data_to_cloud()
			if is_instance_valid(status_label):
				status_label.text = GameManager.cloud_status

func _play() -> void:
	play_button.disabled = true
	board_picker.disabled = true
	view_picker.disabled = true
	validated_toggle.disabled = true
	for button in upgrade_buttons.values():
		button.disabled = true
	status_label.text = "Requesting run ticket…" if GameManager.validation_requested else "Launching…"
	await GameManager.start_run()


func _update_locale() -> void:
	play_button.text = GameManager.ui_text("seagull.play", "Launch survival run")
