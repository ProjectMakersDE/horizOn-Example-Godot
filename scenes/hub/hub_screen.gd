## Hub Screen - Main menu with upgrades, leaderboard, news, etc.
extends Control

@onready var coins_label: Label = $TopBar/CoinsLabel
@onready var best_label: Label = $TopBar/BestLabel
@onready var play_button: Button = $Content/RightPanel/PlayButton
@onready var leaderboard_list: VBoxContainer = $Content/RightPanel/LeaderboardPanel/LeaderboardList
@onready var news_list: VBoxContainer = $Content/RightPanel/NewsPanel/NewsList
@onready var gift_code_button: Button = $Content/RightPanel/BottomButtons/GiftCodeButton
@onready var feedback_button: Button = $Content/RightPanel/BottomButtons/FeedbackButton
@onready var settings_button: Button = $Content/RightPanel/BottomButtons/SettingsButton

# Upgrade buttons
@onready var speed_button: Button = $Content/LeftPanel/UpgradeList/SpeedUpgrade/BuyButton
@onready var speed_label: Label = $Content/LeftPanel/UpgradeList/SpeedUpgrade/InfoLabel
@onready var damage_button: Button = $Content/LeftPanel/UpgradeList/DamageUpgrade/BuyButton
@onready var damage_label: Label = $Content/LeftPanel/UpgradeList/DamageUpgrade/InfoLabel
@onready var hp_button: Button = $Content/LeftPanel/UpgradeList/HPUpgrade/BuyButton
@onready var hp_label: Label = $Content/LeftPanel/UpgradeList/HPUpgrade/InfoLabel
@onready var magnet_button: Button = $Content/LeftPanel/UpgradeList/MagnetUpgrade/BuyButton
@onready var magnet_label: Label = $Content/LeftPanel/UpgradeList/MagnetUpgrade/InfoLabel

@onready var status_label: Label = $StatusLabel

# Popup containers
@onready var gift_code_popup: PanelContainer = $Popups/GiftCodePopup
@onready var feedback_popup: PanelContainer = $Popups/FeedbackPopup


func _ready() -> void:
	AudioManager.play_music("music_menu")
	status_label.text = "Loading..."

	play_button.pressed.connect(_on_play_pressed)
	gift_code_button.pressed.connect(_on_gift_code_pressed)
	feedback_button.pressed.connect(_on_feedback_pressed)
	settings_button.pressed.connect(_on_settings_pressed)

	speed_button.pressed.connect(func(): _buy_upgrade("speed"))
	damage_button.pressed.connect(func(): _buy_upgrade("damage"))
	hp_button.pressed.connect(func(): _buy_upgrade("hp"))
	magnet_button.pressed.connect(func(): _buy_upgrade("magnet"))

	GameManager.coins_changed.connect(func(_c): _update_ui())
	GameManager.highscore_changed.connect(func(_s): _update_ui())

	await _load_hub_data()


func _load_hub_data() -> void:
	# Load remote config
	await ConfigCache.load_all()

	# Load cloud save
	await GameManager.load_save_data()

	# Load leaderboard
	var lb_entries := await Horizon.leaderboard.getTop(10)
	if lb_entries == null or lb_entries.is_empty():
		await Horizon.crashes.record_exception("Failed to load leaderboard in hub", "")
	else:
		_populate_leaderboard(lb_entries)

	# Load user's own rank
	var my_rank := await Horizon.leaderboard.getRank()
	if my_rank != null:
		_show_user_rank(my_rank)

	# Load news
	var news_entries := await Horizon.news.loadNews(5, "en")
	if news_entries == null:
		await Horizon.crashes.record_exception("Failed to load news in hub", "")
	else:
		_populate_news(news_entries)

	_update_ui()
	status_label.text = ""


func _populate_leaderboard(entries: Array) -> void:
	_clear_children(leaderboard_list)
	for entry in entries:
		var label := Label.new()
		label.text = "#%d  %s  %d" % [entry.position, entry.username, entry.score]
		label.add_theme_font_size_override("font_size", 6)
		leaderboard_list.add_child(label)


func _show_user_rank(entry: HorizonLeaderboardEntry) -> void:
	var separator := HSeparator.new()
	leaderboard_list.add_child(separator)
	var label := Label.new()
	label.text = "#%d  %s  %d" % [entry.position, entry.username, entry.score]
	label.add_theme_font_size_override("font_size", 6)
	label.add_theme_color_override("font_color", Color("#FFD700"))
	leaderboard_list.add_child(label)


func _populate_news(entries: Array) -> void:
	_clear_children(news_list)
	for entry in entries:
		var label := Label.new()
		label.text = "* %s" % entry.title
		label.add_theme_font_size_override("font_size", 6)
		news_list.add_child(label)


func _update_ui() -> void:
	coins_label.text = "Coins: %d" % GameManager.save_data.coins
	best_label.text = "Best: %d" % GameManager.save_data.highscore
	_update_upgrade_button("speed", speed_button, speed_label)
	_update_upgrade_button("damage", damage_button, damage_label)
	_update_upgrade_button("hp", hp_button, hp_label)
	_update_upgrade_button("magnet", magnet_button, magnet_label)


func _update_upgrade_button(upgrade_name: String, button: Button, label: Label) -> void:
	var lvl: int = GameManager.save_data.upgrades.get(upgrade_name, 0)
	if GameManager.is_upgrade_maxed(upgrade_name):
		label.text = "%s Lv.%d MAX" % [upgrade_name.capitalize(), lvl]
		button.text = "MAX"
		button.disabled = true
	else:
		var cost := GameManager.get_upgrade_cost(upgrade_name)
		label.text = "%s Lv.%d" % [upgrade_name.capitalize(), lvl]
		button.text = "[+] %d" % cost
		button.disabled = not GameManager.can_afford_upgrade(upgrade_name)


func _buy_upgrade(upgrade_name: String) -> void:
	if GameManager.buy_upgrade(upgrade_name):
		AudioManager.play_sfx("sfx_upgrade_select")
		_update_ui()


func _on_play_pressed() -> void:
	GameManager.start_run()


func _on_gift_code_pressed() -> void:
	gift_code_popup.visible = true


func _on_feedback_pressed() -> void:
	feedback_popup.visible = true


func _on_settings_pressed() -> void:
	if not has_node("Popups/SettingsPopup"):
		_create_settings_popup()
	$Popups/SettingsPopup.visible = true


func _create_settings_popup() -> void:
	var popup := PanelContainer.new()
	popup.name = "SettingsPopup"
	popup.set_anchors_preset(Control.PRESET_CENTER)
	popup.offset_left = -100.0
	popup.offset_top = -60.0
	popup.offset_right = 100.0
	popup.offset_bottom = 60.0

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)

	var title := Label.new()
	title.text = "Settings"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	var volume_label := Label.new()
	volume_label.text = "Music Volume"
	vbox.add_child(volume_label)

	var volume_slider := HSlider.new()
	volume_slider.min_value = 0.0
	volume_slider.max_value = 1.0
	volume_slider.step = 0.1
	volume_slider.value = 0.7
	volume_slider.value_changed.connect(func(val): AudioServer.set_bus_volume_db(0, linear_to_db(val)))
	vbox.add_child(volume_slider)

	var signout_btn := Button.new()
	signout_btn.text = "Sign Out"
	signout_btn.pressed.connect(func():
		Horizon.auth.signOut()
		GameManager.go_to_title()
	)
	vbox.add_child(signout_btn)

	var close_btn := Button.new()
	close_btn.text = "Close"
	close_btn.pressed.connect(func(): popup.visible = false)
	vbox.add_child(close_btn)

	popup.add_child(vbox)
	$Popups.add_child(popup)


func _clear_children(node: Node) -> void:
	for child in node.get_children():
		child.queue_free()
