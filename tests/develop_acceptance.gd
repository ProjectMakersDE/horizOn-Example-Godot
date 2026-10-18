extends SceneTree
## Explicit native Develop QA; never loaded by a normal game or exported release.
const HOST: String = "http://127.0.0.1:3170"
const Lab = preload("res://scripts/ui/feature_lab.gd")
var _manifest: Dictionary
var _lab: Node

static func validate_manifest(value: Dictionary) -> bool:
	return value.get("stage") == "develop" and value.get("rootApproved") == true and value.get("baseUrl") == HOST and HorizonItemModels.uuid(value.get("projectId")) and HorizonItemModels.uuid(value.get("runId")) and value.get("appApiKey") is String and not value.appApiKey.is_empty() and value.get("controlDirectory") is String and value.controlDirectory.is_absolute_path() and _commit(value.get("serverCommit")) and _commit(value.get("dashboardCommit"))
static func _commit(value: Variant) -> bool:
	if not value is String or value.length() != 40: return false
	for code: int in value.to_utf8_buffer():
		if not (code >= 48 and code <= 57 or code >= 97 and code <= 102): return false
	return true
static func claim_started(path: String) -> bool:
	# A permanent per-command marker, not a reclaimable send lease.
	return DirAccess.make_dir_absolute(path + ".started") == OK
static func check_file_gates() -> bool:
	var manifest: Dictionary = {"stage": "develop", "rootApproved": true, "baseUrl": HOST, "projectId": "10000000-0000-4000-8000-000000001016", "runId": "20000000-0000-4000-8000-000000001016", "appApiKey": "synthetic-not-a-server-key", "controlDirectory": OS.get_user_data_dir(), "serverCommit": "a".repeat(40), "dashboardCommit": "b".repeat(40)}
	if not validate_manifest(manifest): return false
	manifest.baseUrl = "http://127.0.0.1:3171"
	if validate_manifest(manifest): return false
	manifest.baseUrl = HOST; manifest.rootApproved = false
	if validate_manifest(manifest): return false
	var path: String = ProjectSettings.globalize_path("user://develop-started-" + str(Time.get_ticks_usec()))
	if not claim_started(path): return false
	var retained: bool = not claim_started(path)
	DirAccess.remove_absolute(path + ".started")
	return retained

func _initialize() -> void:
	call_deferred("_run")
func _run() -> void:
	if "--develop-acceptance-self-test" in OS.get_cmdline_user_args():
		var passed: bool = check_file_gates()
		root.get_node("AudioManager").shutdown(); await process_frame
		if passed: print("DEVELOP_ACCEPTANCE_FILE_GATES_PASS: exact3170/Root approval/immutable started marker; no SDK action or HTTP")
		quit(0 if passed else 1); return
	var path: String = ""
	for option: String in OS.get_cmdline_user_args():
		if option.begins_with("--develop-acceptance="): path = option.trim_prefix("--develop-acceptance=")
	if path.is_empty(): _stop("PRIVATE_MANIFEST_REQUIRED"); return
	_manifest = HorizonItemModels.parseTransport(FileAccess.get_file_as_string(path))
	if not validate_manifest(_manifest) or not DirAccess.dir_exists_absolute(_manifest.controlDirectory): _stop("APPROVED_EXACT_DEVELOP_MANIFEST_REQUIRED"); return
	# The native launcher prepares this owned profile before autoload initialization.
	if not str(ProjectSettings.get_setting("application/config/custom_user_dir_name", "")).begins_with("horizon-task1016-develop-"): _stop("OWNED_NATIVE_PROFILE_REQUIRED"); return
	var h: Node = root.get_node("Horizon")
	h.setLogLevel(HorizonLogger.LogLevel.NONE)
	h._config = HorizonConfig.new(); h._config.api_key = _manifest.appApiKey; h._config.hosts = PackedStringArray([HOST])
	h._apiKey = _manifest.appApiKey; h._hosts = PackedStringArray([HOST]); h._isInitialized = true; h._applyConfig()
	if not await h.connect_to_server(): _stop("DEVELOP_CONNECTION_FAILED"); return
	var hello: Node = load("res://examples/hello_features/hello_features.tscn").instantiate()
	root.add_child(hello); current_scene = hello
	_lab = Lab.new(); root.add_child(_lab); _lab._project.text = _manifest.projectId
	var results: String = _manifest.controlDirectory.path_join("results")
	DirAccess.make_dir_recursive_absolute(results)
	print("[DEVELOP ACCEPTANCE] READY: private commands only; no identity or business action inferred")
	while true:
		var files: PackedStringArray = DirAccess.get_files_at(_manifest.controlDirectory); files.sort()
		for name: String in files:
			if not name.ends_with(".json"): continue
			var id: String = name.trim_suffix(".json")
			if not HorizonItemModels.uuid(id) or id != id.to_lower(): continue
			var destination: String = results.path_join(name)
			if FileAccess.file_exists(destination): continue
			var input: String = _manifest.controlDirectory.path_join(name)
			var command: Dictionary = HorizonItemModels.parseTransport(FileAccess.get_file_as_string(input))
			if command.get("id") != id or not command.get("action") is String: _stop("COMMAND_IDENTITY_MISMATCH"); return
			var output: Dictionary = {"id": id, "action": command.action, "startedAtUtc": Time.get_datetime_string_from_system(true) + "Z"}
			if not claim_started(input): output.error = "UNKNOWN_OUTCOME_ORIGINAL_RETAINED"
			else: output.merge(await _execute(command), true)
			if h.auth.isSignedIn(): output.userId = h.auth.getCurrentUser().userId
			output.completedAtUtc = Time.get_datetime_string_from_system(true) + "Z"
			if not _write_result(destination, output): _stop("RESULT_STORAGE_ERROR_ORIGINAL_RETAINED"); return
			if command.action == "quit":
				root.get_node("AudioManager").shutdown(); await process_frame; quit(0); return
		await create_timer(0.15).timeout # Private local files only; never an API poll.

func _execute(command: Dictionary) -> Dictionary:
	var action: String = command.action
	var read: bool = action in ["loadJson", "loadBinary", "guide", "capture", "quit", "restoreSaved"]
	if not read and (_manifest.get("allowWrites") != true or command.get("confirm") != true): return {"error": "EXPLICIT_DEVELOP_CONFIRMATION_REQUIRED"}
	var h: Node = root.get_node("Horizon")
	var manager: Node = root.get_node("GameManager")
	if action == "createGuest":
		if h.auth.isSignedIn() or not manager._stored_guest_identity().is_empty(): return {"error": "EXISTING_IDENTITY_REQUIRES_RESTORE"}
		var success: bool = await manager.authenticate("guest", "", "", str(command.get("displayName", "DevelopQA")))
		return {"success": success, "userId": h.auth.getCurrentUser().userId if success else "", "privateAnonymousToken": h.auth.getCurrentUser().anonymousToken if success else ""}
	if action == "restoreGuest":
		if h.auth.isSignedIn() or not manager._stored_guest_identity().is_empty(): return {"error": "EXISTING_IDENTITY_REQUIRES_RESTORE"}
		var token: PackedByteArray = Marshalls.base64_to_raw(str(command.get("dataBase64", "")))
		if token.is_empty() or token.get_string_from_utf8().to_utf8_buffer() != token: return {"error": "ORIGINAL_GUEST_CREDENTIAL_REQUIRED"}
		var success: bool = await h.auth.signInAnonymous(token.get_string_from_utf8())
		if success: manager.enter_online()
		return {"success": success, "userId": h.auth.getCurrentUser().userId if success else ""}
	if action == "restoreSaved":
		var success: bool = await manager.authenticate("restore")
		return {"success": success, "userId": h.auth.getCurrentUser().userId if success else ""}
	if action == "quit": return {"success": true}
	if not manager.online_available() or not h.auth.isSignedIn(): return {"error": "SESSION_REQUIRED"}
	if action == "feature":
		var parsed: Dictionary = HorizonItemModels.parseTransport(str(command.get("argumentsJson", "{}")))
		if not parsed.get("args") is Array: return {"error": "INVALID_ARGUMENTS"}
		var result: Dictionary = await _lab.execute(str(command.get("feature", "")), str(command.get("operation", "")), parsed.args)
		_lab._show(result)
		return {"invoked": true, "success": result.get("success", false), "output": _lab._output.text, "error": result.get("errorCode", "")}
	if action in ["loadJson", "loadBinary"]:
		var snapshot: Dictionary = await h.cloudSave.loadSnapshot() if action == "loadJson" else await h.cloudSave.loadBytesSnapshot()
		var data: Variant = snapshot.get("data")
		return {"success": snapshot.success, "found": snapshot.found, "revision": str(snapshot.revision) if snapshot.revision >= 0 else "", "statusCode": snapshot.statusCode, "dataBase64": Marshalls.raw_to_base64(data.to_utf8_buffer() if data is String else data) if data != null else ""}
	if action in ["saveJson", "saveBinary"]:
		var revision: Variant = command.get("expectedRevision")
		if not revision is String or not revision.is_valid_int() or str(int(revision)) != revision or int(revision) < 0: return {"error": "ORIGINAL_REVISION_REQUIRED"}
		var encoded: String = str(command.get("dataBase64", "")); var data: PackedByteArray = Marshalls.base64_to_raw(encoded)
		if Marshalls.raw_to_base64(data) != encoded or (action == "saveJson" and data.get_string_from_utf8().to_utf8_buffer() != data): return {"error": "ORIGINAL_BYTES_REQUIRED"}
		var written: Dictionary = await h.cloudSave.saveDataAtRevision(data.get_string_from_utf8(), int(revision)) if action == "saveJson" else await h.cloudSave.saveBytesAtRevision(data, int(revision))
		return {"success": written.success, "conflict": written.conflict, "revision": str(written.revision) if written.revision >= 0 else "", "statusCode": written.statusCode}
	if action == "guide": return await _guide(str(command.get("feature", "")))
	if action == "capture":
		await process_frame
		var file: String = _manifest.controlDirectory.path_join("results").path_join(command.id + ".png")
		return {"success": root.get_texture().get_image().save_png(file) == OK}
	return {"error": "UNKNOWN_ACTION"}

func _guide(feature: String) -> Dictionary:
	var methods: Dictionary = {"groups": ["groups", "read_my_groups", "/groups"], "items": ["items", "read_inventory", "/items"], "matches": ["matches", "read_my_matches", "/matches"], "shared-objects": ["shared_objects", "read_world_map", "/shared-objects/"]}
	if not methods.has(feature): return {"error": "UNKNOWN_GUIDE"}
	var observed: Dictionary = {}
	var began: int = Time.get_ticks_usec()
	var callback: Callable = func(url: String, response: HorizonNetworkResponse) -> void:
		if observed.is_empty() and url.begins_with(HOST + "/api/v1/app" + methods[feature][2]): observed.merge({"statusCode": response.statusCode, "secondsToHttpResponse": float(Time.get_ticks_usec() - began) / 1000000.0})
	var h: Node = root.get_node("Horizon"); h._http.request_completed.connect(callback)
	var guide: Node = load("res://examples/public_feature_guides/" + methods[feature][0] + ".gd").new(); root.add_child(guide)
	await guide.call(methods[feature][1]); guide.queue_free(); h._http.request_completed.disconnect(callback)
	if observed.is_empty(): return {"error": "NO_ACTUAL_HTTP_RESPONSE"}
	observed.success = observed.statusCode >= 200 and observed.statusCode < 300 and observed.secondsToHttpResponse < 300
	observed.output = "Complete guide in an existing native session. HTTP timing is separate from DTO/business acceptance."
	return observed

static func _write_result(path: String, value: Dictionary) -> bool:
	if FileAccess.file_exists(path) or FileAccess.file_exists(path + ".next"): return false
	var file: FileAccess = FileAccess.open(path + ".next", FileAccess.WRITE)
	if file == null: return false
	file.store_string(JSON.stringify(value, "  ")); file.flush()
	var stored: bool = file.get_error() == OK
	file.close()
	if not stored: return false # Preserve the partial .next and permanent started marker.
	return DirAccess.rename_absolute(path + ".next", path) == OK
func _stop(code: String) -> void:
	push_error("[DEVELOP ACCEPTANCE] STOP: " + code + "; private originals preserved")
	root.get_node("AudioManager").shutdown()
	quit(1)
