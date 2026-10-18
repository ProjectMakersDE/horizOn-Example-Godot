extends Control
## Standalone feature entry. No identity, read, subscribe or write occurs in ready.
const Guide = preload("res://examples/public_marketplace/marketplace_demo.gd")
var _status: Label

func _ready() -> void:
	var page: VBoxContainer = StormUI.page(self, "Hello / current SDK", "The same explicit integrations used by Seagull Storm, without starting a game.")
	var card: VBoxContainer = StormUI.scroll_card(page)
	_status = StormUI.label(card, "Import your project config first. Existing identity and unresolved originals stay protected.", 15)
	StormUI.button(card, "Connect / restore existing guest", _connect)
	card.add_child(preload("res://scripts/ui/gift_redemption_demo.gd").new())
	card.add_child(preload("res://scripts/ui/feature_lab.gd").new())
	card.add_child(preload("res://scripts/ui/player_values_demo.gd").new())
	var statistics: Node = preload("res://scripts/ui/statistics_demo.gd").new()
	statistics.example = "hello"
	card.add_child(statistics)

func _connect() -> void:
	var manager: Node = get_node("/root/GameManager")
	if await manager.authenticate("guest"):
		manager.enter_online()
		_status.text = "Existing player: " + get_node("/root/Horizon").getCurrentUser().userId + ". Read current state before confirming any action."
	else:
		_status.text = "Connection / identity restore unavailable. Originals remain; no replacement identity was inferred."
