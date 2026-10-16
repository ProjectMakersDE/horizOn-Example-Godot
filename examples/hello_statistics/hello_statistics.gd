extends Control
@onready var _horizon: Node = get_node("/root/Horizon")
@onready var _manager: Node = get_node("/root/GameManager")
## Standalone Hello: no authentication or HTTP until the player clicks an action.
var _status: Label
var _statistics: VBoxContainer

func _ready() -> void:
	var page := StormUI.page(self, "Hello / Statistics", "A minimal, explicit run batch. Uses a separate queue from Seagull Storm.")
	var card := StormUI.scroll_card(page)
	_status = StormUI.label(card, "Import your SDK configuration, then connect. A saved guest identity is restored first.", 15)
	StormUI.button(card, "Connect / restore guest", _connect)
	StormUI.button(card, "Complete a sample round (3 kills, score 250)", _complete)
	_statistics = preload("res://scripts/ui/statistics_demo.gd").new()
	_statistics.example = "hello"
	card.add_child(_statistics)

func _connect() -> void:
	if await _manager.authenticate("guest"):
		_manager.enter_online()
		_status.text = "Connected. Complete a sample round, then choose Report queued runs."
		_statistics._refresh_queue()
	else:
		_status.text = "Connection/restore failed. Existing identity and pending batches are retained."

func _complete() -> void:
	if not _horizon.isConnected() or not _horizon.isSignedIn():
		_status.text = "Connect a player first. No request was sent."
		return
	var store := StatisticsRunStore.new(_horizon.getConfig().api_key, _horizon.getCurrentUser().userId, "hello")
	_status.text = "Sample round queued locally; choose Report to send." if store.queue_run(3, 250) else "Queue cannot be saved safely. Existing data retained."
	_statistics._refresh_queue()
