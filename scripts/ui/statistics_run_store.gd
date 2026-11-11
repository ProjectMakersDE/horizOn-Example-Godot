class_name StatisticsRunStore
extends RefCounted
## Durable session aggregate plus one immutable original batch. No automatic transport.
const MAX_VALUE := 9007199254740991
const KEYS := ["rounds", "kills", "best_score"]
var path: String
var user_id: String
var scope_hash: String

func _init(project: String, player: String, example: String = "game") -> void:
	user_id = player
	scope_hash = JSON.stringify([project, player, example]).sha256_text()
	path = "user://seagull_statistics_" + scope_hash + ".bin"

func read() -> Dictionary:
	# Interrupted writes and malformed records require reconciliation, never replacement.
	if FileAccess.file_exists(path + ".next"):
		return {}
	if not FileAccess.file_exists(path):
		return {"version": 1, "scope": scope_hash, "userId": user_id, "rounds": 0, "kills": 0, "bestScore": 0, "pending": {}}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var saved: Variant = file.get_var(false)
	var error := file.get_error()
	file.close()
	if error != OK or not saved is Dictionary or saved.get("version") != 1 or saved.get("scope") != scope_hash or saved.get("userId") != user_id:
		return {}
	for key: String in ["rounds", "kills", "bestScore"]:
		if not _safe(saved.get(key)) or saved[key] < 0:
			return {}
	if not saved.get("pending") is Dictionary:
		return {}
	if not saved.pending.is_empty() and not _valid_pending(saved.pending):
		return {}
	return saved

func queue_run(kills: int, score: int) -> bool:
	return _mutate(func(saved: Dictionary) -> Dictionary:
		if kills < 0 or score < 0 or kills > MAX_VALUE or score > MAX_VALUE or saved.rounds == MAX_VALUE or saved.kills > MAX_VALUE - kills:
			return {}
		saved.rounds += 1
		saved.kills += kills
		saved.bestScore = maxi(saved.bestScore, score)
		return saved)

func reserve(operation_id: String, definitions: Array) -> bool:
	return _mutate(func(saved: Dictionary) -> Dictionary:
		if not saved.pending.is_empty() or saved.rounds == 0:
			return {}
		var updates: Array = [{"key": "rounds", "value": saved.rounds}, {"key": "kills", "value": saved.kills}, {"key": "best_score", "value": saved.bestScore}]
		for index in range(KEYS.size()):
			var matching := definitions.filter(func(d: Dictionary) -> bool: return d.get("key") == KEYS[index])
			if matching.size() != 1 or matching[0].get("mode") != ("max" if index == 2 else "sum") or matching[0].get("reset") != "none":
				return {}
			var bound: Variant = matching[0].get("maxPerUpdate")
			if bound != null and (not _safe(bound) or bound <= 0 or updates[index].value > bound):
				return {}
		saved.pending = {"userId": user_id, "operationId": operation_id, "updates": updates}
		if not _valid_pending(saved.pending):
			return {}
		saved.rounds = 0
		saved.kills = 0
		saved.bestScore = 0
		return saved)

func confirm(operation_id: String) -> bool:
	return _mutate(func(saved: Dictionary) -> Dictionary:
		if saved.pending.is_empty() or saved.pending.operationId != operation_id:
			return {}
		saved.pending = {}
		return saved)

## Atomic mkdir serializes read-modify-write across processes. Never expire a stale lock:
## a crashed owner may have an uncertain command, so retain all files for reconciliation.
func _mutate(change: Callable) -> bool:
	var lock_path := ProjectSettings.globalize_path(path + ".lock")
	if DirAccess.make_dir_absolute(lock_path) != OK:
		return false
	var saved := read()
	var next: Dictionary = change.call(saved) if not saved.is_empty() else {}
	var success := not next.is_empty() and _save(next)
	DirAccess.remove_absolute(lock_path)
	return success

func _valid_pending(pending: Dictionary) -> bool:
	var pattern := RegEx.create_from_string("^[0-9]{13}:[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}\\z")
	if pending.get("userId") != user_id or not pending.get("operationId") is String or pattern.search(pending.operationId) == null or not pending.get("updates") is Array or pending.updates.size() != 3:
		return false
	for index in range(KEYS.size()):
		var update: Variant = pending.updates[index]
		if not update is Dictionary or update.get("key") != KEYS[index] or not _safe(update.get("value")) or update.value < 0:
			return false
	return pending.updates[0].value > 0

func _safe(value: Variant) -> bool:
	return typeof(value) == TYPE_INT and value >= -MAX_VALUE and value <= MAX_VALUE

func _save(saved: Dictionary) -> bool:
	var file := FileAccess.open(path + ".next", FileAccess.WRITE)
	if file == null:
		return false
	file.store_var(saved.duplicate(true), false)
	file.flush()
	var error := file.get_error()
	file.close()
	return error == OK and DirAccess.rename_absolute(ProjectSettings.globalize_path(path + ".next"), ProjectSettings.globalize_path(path)) == OK
