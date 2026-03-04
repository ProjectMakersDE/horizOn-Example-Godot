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

	# Load all data
	await _load_hub_data()


func _load_hub_data() -> void:
	# Load remote config
	await ConfigManager.load_configs()

	# Load cloud save
	await SaveManager.load_game()

	# Load leaderboard
	_load_leaderboard()

	# Load news
	_load_news()

	_update_ui()
	status_label.text = ""


func _load_leaderboard() -> void:
	var entries := await Horizon.leaderboard.getTop(10)
	_clear_children(leaderboard_list)
	for entry in entries:
		var label := Label.new()
		label.text = "#%d  %s  %d" % [entry.position, entry.username, entry.score]
		label.add_theme_font_size_override("font_size", 6)
		leaderboard_list.add_child(label)

	# Get user rank
	var rank_entry := await Horizon.leaderboard.getRank()
	if rank_entry:
		GameManager.user_rank = rank_entry.position
		var label := Label.new()
		label.text = "You: #%d (%d)" % [rank_entry.position, rank_entry.score]
		label.add_theme_font_size_override("font_size", 6)
		label.add_theme_color_override("font_color", Color("#D87943"))
		leaderboard_list.add_child(label)


func _load_news() -> void:
	var entries := await Horizon.news.loadNews(5, "en")
	_clear_children(news_list)
	for entry in entries:
		var label := Label.new()
		label.text = "* %s" % entry.title
		label.add_theme_font_size_override("font_size", 6)
		news_list.add_child(label)


func _update_ui() -> void:
	coins_label.text = "Coins: %d" % GameManager.coins
	best_label.text = "Best: %d" % GameManager.highscore
	_update_upgrade_button("speed", speed_button, speed_label)
	_update_upgrade_button("damage", damage_button, damage_label)
	_update_upgrade_button("hp", hp_button, hp_label)
	_update_upgrade_button("magnet", magnet_button, magnet_label)


func _update_upgrade_button(name: String, button: Button, label: Label) -> void:
	var lvl: int = GameManager.upgrades.get(name, 0)
	if GameManager.is_upgrade_maxed(name):
		label.text = "%s Lv.%d MAX" % [name.capitalize(), lvl]
		button.text = "MAX"
		button.disabled = true
	else:
		var cost := GameManager.get_upgrade_cost(name)
		label.text = "%s Lv.%d" % [name.capitalize(), lvl]
		button.text = "[+] %d" % cost
		button.disabled = not GameManager.can_afford_upgrade(name)


func _buy_upgrade(upgrade_name: String) -> void:
	if GameManager.buy_upgrade(upgrade_name):
		AudioManager.play_sfx("sfx_upgrade_select")
		Horizon.crashes.record_breadcrumb("user_action", "bought_%s_%d" % [upgrade_name, GameManager.upgrades[upgrade_name]])
		_update_ui()


func _on_play_pressed() -> void:
	Horizon.crashes.record_breadcrumb("navigation", "entered_run")
	get_tree().change_scene_to_file("res://scenes/run/survival_run.tscn")


func _on_gift_code_pressed() -> void:
	gift_code_popup.visible = true


func _on_feedback_pressed() -> void:
	feedback_popup.visible = true


func _on_settings_pressed() -> void:
	# Sign out and return to title
	Horizon.auth.signOut()
	GameManager.is_signed_in = false
	get_tree().change_scene_to_file("res://scenes/title/title_screen.tscn")


func _clear_children(node: Node) -> void:
	for child in node.get_children():
		child.queue_free()
