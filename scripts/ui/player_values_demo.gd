extends VBoxContainer
@onready var _manager: Node = get_node("/root/GameManager")
@onready var _horizon: Node = get_node("/root/Horizon")
## Explicit developer demo; server balances never become practice coins.
var _output: Label
var _status: Label
var _offer_info: Label
var _values := OptionButton.new()
var _offers := OptionButton.new()
var _catalogue: Array = []
var _definition: int = -1
var _busy := false

func _ready() -> void:
	StormUI.label(self, "Server balances are separate from practice coins.", 15, StormUI.MUTED)
	_status = StormUI.label(self, "Read balances and offers to begin.", 15, StormUI.TEAL)
	StormUI.button(self, "Read balances and offers", _load)
	add_child(_values)
	add_child(_offers)
	_offers.item_selected.connect(_select_offer)
	_offer_info = StormUI.label(self, "No current offer selected.", 14, StormUI.MUTED)
	StormUI.button(self, "Buy selected offer", _purchase)
	StormUI.button(self, "Adjust selected value +1", _adjust)
	StormUI.button(self, "Retry original pending action", _retry)
	_output = StormUI.label(self, "No server snapshot loaded.", 15)
	if _manager.practice_mode:
		_status.text = "Offline practice: connect a player to use server balances."

func _scope() -> String:
	if not _manager.online_available():
		return ""
	return _horizon.getConfig().api_key + "|" + _horizon.getCurrentUser().userId

func _context() -> String:
	return _horizon.getActiveHost() + "|" + _horizon._http.sessionToken + "|" + _scope()

func _begin() -> String:
	var scope := _scope()
	if _busy or scope.is_empty():
		return ""
	_busy = true
	_status.text = "Waiting for the server…"
	return _context()

func _current(scope: String, generation: int) -> bool:
	var current: bool = is_instance_valid(self) and is_inside_tree() and scope == _context() and generation == _manager.state_generation()
	if not current:
		_busy = false
	return current

func _load() -> void:
	var scope := _begin()
	if scope.is_empty():
		return
	var generation: int = _manager.state_generation()
	var user_id: String = _horizon.getCurrentUser().userId
	var state: Dictionary = await _horizon.playerValues.getState(user_id)
	if not _current(scope, generation):
		return
	_show_state(state.get("state", {}))
	if state.get("success", false):
		var offers: Dictionary = await _horizon.playerValues.getOffers(user_id)
		if not _current(scope, generation):
			return
		if offers.get("success", false):
			_catalogue_from(offers.data)
			if _horizon.playerValues.getCurrentState().is_empty():
				_values.clear()
				_output.text = "Definitions changed; reload balances before an adjustment."
			_status.text = "Snapshot loaded. Select an offer or an enabled adjustment."
		else:
			_status.text = "Offers unavailable: " + str(offers.errorCode)
	else:
		_status.text = "Balances unavailable: " + str(state.errorCode)
	_busy = false

func _show_state(state: Dictionary) -> void:
	if state.is_empty():
		return
	if int(state.definitionVersion) > _definition:
		_catalogue.clear()
		_offers.clear()
	_values.clear()
	var lines: Array[String] = []
	for value: Dictionary in state.values:
		_values.add_item(str(value.key))
		lines.append("%s: %d" % [value.key, value.balance])
	_output.text = "\n".join(lines) if not lines.is_empty() else "No configured balances."

func _purchase() -> void:
	var cached: Dictionary = _horizon.playerValues.getCurrentOffers() if _manager.online_available() else {}
	if _offers.selected < 0 or _offers.selected >= _catalogue.size() or cached.is_empty() or int(cached.definitionVersion) != _definition:
		_status.text = "Reload current balances and offers before buying."
		return
	if _busy or PlayerValueIntentStore.new(_scope()).exists():
		_status.text = "Retry the original pending action before creating another."
		return
	var selected: Dictionary = _catalogue[_offers.selected].duplicate(true)
	var previous_definition := _definition
	var context := _begin()
	if context.is_empty():
		return
	var generation: int = _manager.state_generation()
	var fresh: Dictionary = await _horizon.playerValues.getOffers(_horizon.getCurrentUser().userId)
	if not _current(context, generation):
		return
	_busy = false
	if not fresh.get("success", false):
		_status.text = "Cannot confirm the current offer. Nothing was sent."
		return
	_catalogue_from(fresh.data, selected.key)
	if _offers.selected < 0 or previous_definition != _definition or selected != _catalogue[_offers.selected]:
		_status.text = "Offer changed. Review current costs and select Buy again."
		return
	if not _catalogue[_offers.selected].active:
		_status.text = "This offer is no longer active."
		return
	await _new_intent({"kind": "purchase", "offerKey": selected.key})

func _catalogue_from(data: Dictionary, selected_key := "") -> void:
	_catalogue = data.offers.duplicate(true)
	_definition = int(data.definitionVersion)
	_offers.clear()
	for item: Dictionary in _catalogue:
		_offers.add_item(str(item.name))
		if item.key == selected_key:
			_offers.select(_offers.item_count - 1)
	if not selected_key.is_empty() and not _catalogue.any(func(item: Dictionary) -> bool: return item.key == selected_key):
		_offers.select(-1)
	_select_offer(_offers.selected)

func _adjust() -> void:
	if _values.selected < 0:
		return
	await _new_intent({"kind": "adjust", "key": _values.get_item_text(_values.selected), "amount": 1, "reason": "Seagull Storm example +1"})

func _new_intent(payload: Dictionary) -> void:
	var scope := _scope()
	if _busy or scope.is_empty():
		return
	var store := PlayerValueIntentStore.new(_scope())
	if store.exists():
		_status.text = "A pending action exists. Retry that original action; no replacement is created."
		return
	if not _horizon.playerValues.hasServerClock():
		_status.text = "Read the server snapshot before creating an action."
		return
	payload.userId = _horizon.getCurrentUser().userId
	payload.operationId = _horizon.playerValues.createOperationId()
	if not store.reserve(payload):
		_status.text = "Pending action could not be safely saved. Nothing was sent."
		return
	await _retry()

func _retry() -> void:
	var scope := _begin()
	if scope.is_empty():
		return
	var generation: int = _manager.state_generation()
	var store := PlayerValueIntentStore.new(_scope())
	var pending := store.read()
	if pending.is_empty() or pending.userId != _horizon.getCurrentUser().userId:
		_status.text = "No readable pending action. An existing damaged file is retained for reconciliation."
		_busy = false
		return
	if not store.begin_attempt(_horizon._http, "/api/v1/app/player-values/" + pending.kind):
		_status.text = "Could not persist the send marker. Nothing was sent."
		_busy = false
		return
	var result: Dictionary = await _horizon.playerValues.purchase(pending.userId, pending.offerKey, pending.operationId) if pending.kind == "purchase" else await _horizon.playerValues.adjust(pending.userId, pending.key, pending.amount, pending.reason, pending.operationId)
	var first_send := store.finish_attempt()
	if not _current(scope, generation):
		return
	_show_state(result.get("state", {}))
	if result.get("success", false):
		_status.text = "Server action confirmed." if store.confirm(pending.operationId) else "Confirmed; pending file retained because cleanup failed."
	elif first_send and not result.get("state", {}).is_empty() and result.errorCode in ["ADJUST_NOT_ALLOWED", "ADJUST_ABOVE_LIMIT", "INSUFFICIENT_BALANCE", "MAX_BALANCE_REACHED", "DAILY_LIMIT_REACHED", "OFFER_NOT_FOUND"]:
		_status.text = "Action refused (%s); nothing booked. Choose another action." % result.errorCode if store.confirm(pending.operationId) else "Refused; pending file cleanup failed."
	else:
		_status.text = "Server result: %s. Original action retained, including after OPERATION_EXPIRED." % result.errorCode
	_busy = false

func _select_offer(index: int) -> void:
	if index < 0 or index >= _catalogue.size():
		_offer_info.text = "No current offer selected."
		return
	var item: Dictionary = _catalogue[index]
	var lines: Array[String] = []
	for side: String in ["costs", "rewards"]:
		var amounts: Array[String] = []
		for entry: Dictionary in item[side]:
			amounts.append("%s %d" % [entry.key, entry.amount])
		lines.append(side.capitalize() + ": " + ", ".join(amounts))
	_offer_info.text = "\n".join(lines)
