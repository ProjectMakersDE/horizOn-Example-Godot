class_name PlayerValueIntentStore
extends RefCounted
## One immutable, project/player-bound command survives a lost response or restart.
var path: String
var _http: HorizonHttpClient
var _endpoint := ""
var _requests := 0
var _first_attempt := false

func _init(scope: String) -> void:
	path = "user://seagull_values_pending_" + scope.sha256_text() + ".bin"

func exists() -> bool:
	return FileAccess.file_exists(path)

func read() -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var saved: Variant = file.get_var(false)
	var error := file.get_error()
	file.close()
	if error != OK or not saved is Dictionary or not saved.get("userId") is String or saved.userId.is_empty() or not saved.get("operationId") is String or saved.operationId.is_empty():
		return {}
	if saved.has("attempts") and (typeof(saved.attempts) != TYPE_INT or saved.attempts < 0 or saved.attempts > 1024):
		return {}
	if saved.get("kind") == "purchase" and saved.get("offerKey") is String and not saved.offerKey.is_empty():
		return saved
	if saved.get("kind") == "adjust" and saved.get("key") is String and not saved.key.is_empty() and typeof(saved.get("amount")) == TYPE_INT and saved.amount == 1 and saved.get("reason") == "Seagull Storm example +1":
		return saved
	return {}

func reserve(intent: Dictionary) -> bool:
	if exists():
		return false
	var saved := intent.duplicate(true)
	saved.attempts = 0
	return _save(saved)

func _save(intent: Dictionary) -> bool:
	var file := FileAccess.open(path + ".next", FileAccess.WRITE)
	if file == null:
		return false
	file.store_var(intent.duplicate(true), false)
	file.flush()
	var error := file.get_error()
	file.close()
	return error == OK and DirAccess.rename_absolute(ProjectSettings.globalize_path(path + ".next"), ProjectSettings.globalize_path(path)) == OK

## Persist uncertainty before transport; a restart cannot forget an earlier send.
func begin_attempt(http: HorizonHttpClient, endpoint: String) -> bool:
	var saved := read()
	if saved.is_empty():
		return false
	var attempts := int(saved.get("attempts", 1))
	if attempts >= 1024:
		return false
	saved.attempts = attempts + 1
	if not _save(saved):
		return false
	_first_attempt = attempts == 0
	_http = http
	_endpoint = endpoint
	_requests = 0
	_http.request_started.connect(_request_started)
	return true

func _request_started(url: String, method: String) -> void:
	if method == "POST" and url.ends_with(_endpoint):
		_requests += 1

## An internal retry is also uncertain, even when its final response is a refusal.
func finish_attempt() -> bool:
	if _http != null and _http.request_started.is_connected(_request_started):
		_http.request_started.disconnect(_request_started)
	return _first_attempt and _requests == 1

func confirm(operation_id: String) -> bool:
	if read().get("operationId") != operation_id:
		return false
	return DirAccess.remove_absolute(ProjectSettings.globalize_path(path)) == OK
