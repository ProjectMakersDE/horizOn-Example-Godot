extends VBoxContainer
@onready var _horizon: Node = get_node("/root/Horizon")
@onready var _manager: Node = get_node("/root/GameManager")
## Shared game / standalone Hello panel. Reads and reports are explicit actions.
var example := "game"
var _status: Label
var _output: Label
var _queue: Label
var _busy := false
var _shown_scope := ""

func _ready() -> void:
	StormUI.label(self, "Session statistics", 23)
	StormUI.label(self, "Read the server snapshot, then report completed online runs. Timeout and expiry keep the original batch; later runs wait separately.", 15, StormUI.MUTED)
	_status = StormUI.label(self, "Read statistics to begin. No requests run automatically.", 15, StormUI.TEAL)
	var row := HBoxContainer.new()
	add_child(row)
	StormUI.button(row, "Read snapshot", _load)
	StormUI.button(row, "Report runs", _report)
	StormUI.button(row, "Retry original", _retry)
	_queue = StormUI.label(self, "Only online completed runs are queued; practice stays local.", 14, StormUI.MUTED)
	_output = StormUI.label(self, "Configure rounds=sum, kills=sum and best_score=max, all without reset, in the Dashboard.", 15)
	_refresh_queue()

func _online() -> bool:
	return _horizon.isConnected() and _horizon.isSignedIn() and (example == "hello" or _manager.online_available())

func _store() -> StatisticsRunStore:
	return StatisticsRunStore.new(_horizon.getConfig().api_key, _horizon.getCurrentUser().userId, example)

func _scope() -> String:
	return _store().scope_hash if _online() else ""

func _context() -> String:
	return JSON.stringify([_scope(), _horizon.getActiveHost(), _horizon._http.sessionToken, _manager.state_generation()])

func _begin() -> String:
	if _busy or not _online():
		_status.text = "Connect an online player first; practice statistics are never uploaded."
		return ""
	if _shown_scope != _scope():
		_output.text = "Read the current player's statistics."
		_shown_scope = _scope()
	_busy = true
	return _context()

func _current(context: String) -> bool:
	if not is_instance_valid(self) or not is_inside_tree():
		return false
	if context != _context():
		_busy = false
		_output.text = "Player, project or request context changed. Read the current snapshot."
		_status.text = "Original batch retained under its original owner."
		return false
	return true

func _load() -> bool:
	var context := _begin()
	if context.is_empty():
		return false
	var result: Dictionary = await _horizon.statistics.getStatistics()
	if not _current(context):
		return false
	_show(result)
	_status.text = "Server snapshot loaded." if not result.is_empty() else "Read failed: " + _horizon.statistics.getLastErrorCode()
	_busy = false
	_refresh_queue()
	return not result.is_empty()

func _report() -> void:
	if _busy or not _online():
		return
	var saved := _store().read()
	if saved.is_empty() or not saved.pending.is_empty():
		_status.text = "An original batch or damaged file needs reconciliation. Use Retry; no new ID created."
		return
	# Refresh server time and definitions before creating a genuinely new intent.
	var context := _context()
	if not await _load() or context != _context() or _horizon.statistics.getCurrentStatistics().is_empty():
		return
	if not _store().reserve(_horizon.statistics.createOperationId(), _horizon.statistics.getCurrentDefinitions()):
		_status.text = "Nothing sent. Queue is empty, bounds/modes differ, or persistence failed."
		_refresh_queue()
		return
	await _retry()

func _retry() -> void:
	var context := _begin()
	if context.is_empty():
		return
	var store := _store()
	var saved := store.read()
	if saved.is_empty() or saved.pending.is_empty():
		_status.text = "No valid pending batch. Existing damaged data stays blocked."
		_busy = false
		return
	var pending: Dictionary = saved.pending
	var result: Dictionary = await _horizon.statistics.updateStatistics(pending.updates, pending.operationId)
	if not _current(context):
		return
	_show(result)
	if result.is_empty():
		_status.text = "Result: %s. Original batch retained, including OPERATION_EXPIRED. Inspect status; no replacement ID." % _horizon.statistics.getLastErrorCode()
	else:
		_status.text = "Batch confirmed%s." % (" (replay)" if result.get("replayed", false) else "") if store.confirm(pending.operationId) else "Confirmed; pending file cleanup failed. Retry keeps the same ID."
	_busy = false
	_refresh_queue()

func _show(snapshot: Dictionary) -> void:
	if snapshot.is_empty():
		return
	var lines: Array[String] = ["Server revision %d · definition version %d" % [snapshot.revision, snapshot.definitionVersion]]
	for value: Dictionary in snapshot.values:
		lines.append("%s: %s · period %s" % [value.key, str(value.value) if value.hasValue else "unset", str(value.get("period", "none"))])
	_output.text = "\n".join(lines)

func _refresh_queue() -> void:
	if not _online():
		return
	var saved := _store().read()
	if saved.is_empty():
		_queue.text = "Unreadable/interrupted queue: retained for manual reconciliation."
		return
	_queue.text = "Queued: %d rounds, %d kills, best %d. Original batch: %s." % [saved.rounds, saved.kills, saved.bestScore, "pending" if not saved.pending.is_empty() else "none"]
