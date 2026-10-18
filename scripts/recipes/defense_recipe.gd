extends Node
## One opt-in game recipe. The client never delivers a notice or decides a trusted result.
const Shared = preload("res://addons/horizon_sdk/examples/features/shared_objects_example.gd")
const Storage = preload("res://addons/horizon_sdk/examples/features/pending_statistics.gd")
const VERSION: String = "seagull-defense-v1"
var shared: Node
var _busy: bool = false
var _uploaded_run: String = ""

func _ready() -> void:
	shared = Shared.new()
	add_child(shared)
	var h: Node = get_node_or_null("/root/Horizon")
	if h != null: h.validatedActions.evidence_uploaded.connect(_evidence_uploaded)

static func game_parameters(value: Variant) -> bool:
	return value is Dictionary and value.size() == 3 and typeof(value.get("version")) == TYPE_INT and value.version == 1 and typeof(value.get("hp")) == TYPE_INT and value.hp >= 1 and value.hp <= 1000 and typeof(value.get("power")) == TYPE_INT and value.power >= 1 and value.power <= 1000

static func simulate(seed_value: int, params: Dictionary, moves: Array, require_terminal: bool = true) -> Dictionary:
	if not game_parameters(params) or moves.size() > 6: return {}
	var rng: int = seed_value & 0xffffffff
	var player: int = 20
	var defender: int = params.hp
	for move: Variant in moves:
		if typeof(move) != TYPE_INT or move not in [0, 1] or player <= 0 or defender <= 0: return {}
		rng = (rng * 1664525 + 1013904223) & 0xffffffff
		var damage: int = 2 + ((rng >> 8) % 4) if move == 0 else 1
		defender = maxi(0, defender - damage)
		if defender > 0: player = maxi(0, player - maxi(0, params.power + ((rng >> 16) % 2) - (3 if move == 1 else 0)))
	var terminal: bool = player == 0 or defender == 0 or moves.size() == 6
	if require_terminal and (moves.is_empty() or not terminal): return {}
	var won: bool = defender == 0 and player > 0
	return {"attackerWon": won, "score": (1000 if won else 0) + player * 10 + params.hp - defender, "playerHp": player, "defenseHp": defender, "terminal": terminal}

static func valid_challenge(value: Variant) -> bool:
	if not value is Dictionary or value.size() != 12 or value.get("version") != VERSION: return false
	for key: String in ["challengeId", "apiKeyId", "objectId", "defenderId", "attackerId"]:
		if not HorizonSharedObjectModels.uuid(value.get(key)) or value[key] != value[key].to_lower(): return false
	return HorizonSharedObjectModels.key(value.get("collection")) and HorizonSharedObjectModels.integer(value.get("revision"), 1) and value.get("digest") is String and RegEx.create_from_string("^[0-9a-f]{64}$").search(value.digest) != null and game_parameters(value.get("parameters")) and value.get("leaderboardKey") is String and not value.leaderboardKey.is_empty() and HorizonSharedObjectModels.time(value.get("createdAt")) and value.defenderId != value.attackerId

func import_challenge(text: String) -> Dictionary:
	var h: Node = _authorized()
	if h == null: return _fail("SESSION_REQUIRED")
	if _busy: return _fail("BUSY")
	var value: Dictionary = HorizonSharedObjectModels.parse(text)
	if not valid_challenge(value) or value.attackerId != h.auth.getCurrentUser().userId: return _fail("INVALID_TRUSTED_CHALLENGE")
	var loaded: Dictionary = _load(h)
	if not loaded.success: return loaded
	if not loaded.data.is_empty(): return _fail("PENDING_DEFENSE_REQUIRES_RECONCILIATION")
	var record: Dictionary = {"scope": _scope(h), "phase": "prepared", "challenge": value.duplicate(true), "run": {}, "moves": []}
	return _save(h, record, {}) if not _busy else _fail("BUSY")

func read_map(collection: String = "defenses") -> Dictionary:
	return await shared.query_rectangle(collection, 0, 100, 0, 100)

func find_opponents(collection: String = "defenses") -> Dictionary:
	return await shared.sample_opponents(collection, 1, 1000)

func review_usage(collection: String = "defenses") -> Dictionary:
	return await shared.read_usage(collection)

func publish_defense(hp: int, power: int, x: int, y: int) -> Dictionary:
	var params: Dictionary = {"version": 1, "hp": hp, "power": power}
	if not game_parameters(params): return _fail("INVALID_GAME_PARAMETERS")
	return await shared.create_marker(JSON.stringify(params).to_utf8_buffer(), {"power": power}, {"x": x, "y": y})

func start_reviewed_defense() -> Dictionary:
	var h: Node = _authorized()
	if h == null: return _fail("SESSION_REQUIRED")
	if _busy: return _fail("BUSY")
	var loaded: Dictionary = _load(h)
	if not loaded.success: return loaded
	var original: Dictionary = loaded.data
	if original.is_empty() or original.phase != "prepared": return _fail("ORIGINAL_START_ALREADY_SENT_OR_MISSING")
	var expected: Dictionary = original.duplicate(true)
	var context: String = _context(h)
	_busy = true
	var c: Dictionary = original.challenge
	var object_result: Dictionary = await h.sharedObjects.getObject(c.attackerId, c.collection, c.objectId)
	if not _same(h, context): _busy = false; return _fail("STALE_RESPONSE")
	if not object_result.get("success", false): _busy = false; return object_result
	var row: Dictionary = object_result.data.object
	if row.ownerId != c.defenderId or row.revision != c.revision or HorizonValidatedActions.computeInputLogHash(row.data) != c.digest or HorizonSharedObjectModels.parse(row.data.get_string_from_utf8()) != c.parameters:
		_busy = false; return _fail("TRUSTED_DEFENSE_CHANGED")
	original.phase = "start-unconfirmed"
	if not _save(h, original, expected).success: _busy = false; return _fail("ORIGINAL_CHANGED_OR_STORAGE_ERROR")
	expected = original.duplicate(true)
	var result: Dictionary = await shared.begin_defense_run(row, c.leaderboardKey)
	_busy = false
	if not _same(h, context): return _fail("STALE_RESPONSE")
	if not result.get("success", false): return result # The pre-send original remains protected.
	original.run = result.data.run.duplicate(true)
	original.phase = "playing"
	return _save(h, original, expected)

func play(move: int) -> Dictionary:
	var h: Node = _authorized()
	if h == null: return _fail("SESSION_REQUIRED")
	if _busy or move not in [0, 1]: return _fail("INVALID_ACTION")
	var loaded: Dictionary = _load(h)
	if not loaded.success: return loaded
	var original: Dictionary = loaded.data
	if original.is_empty() or original.phase != "playing": return _fail("RUN_REVIEW_REQUIRED")
	if h.validatedActions.getCurrentRun().get("runId") != original.run.runId: return _fail("RESTART_REQUIRES_TRUSTED_RECONCILIATION")
	var before: Dictionary = simulate(original.run.seed, original.challenge.parameters, original.moves, false)
	if before.is_empty() or before.terminal: return _fail("GAME_FINISHED")
	var expected: Dictionary = original.duplicate(true)
	original.moves.append(move)
	return _save(h, original, expected)

func submit_finished_defense() -> Dictionary:
	var h: Node = _authorized()
	if h == null: return _fail("SESSION_REQUIRED")
	if _busy: return _fail("BUSY")
	var loaded: Dictionary = _load(h)
	if not loaded.success: return loaded
	var original: Dictionary = loaded.data
	if original.is_empty() or original.phase != "playing": return _fail("RUN_REVIEW_REQUIRED")
	if h.validatedActions.getCurrentRun().get("runId") != original.run.runId: return _fail("RESTART_REQUIRES_TRUSTED_RECONCILIATION")
	var outcome: Dictionary = simulate(original.run.seed, original.challenge.parameters, original.moves)
	if outcome.is_empty(): return _fail("GAME_NOT_FINISHED")
	var log: PackedByteArray = _input_log(original)
	var context: String = _context(h)
	var expected: Dictionary = original.duplicate(true)
	original.phase = "submit-unconfirmed"
	if not _save(h, original, expected).success: return _fail("ORIGINAL_CHANGED_OR_STORAGE_ERROR")
	expected = original.duplicate(true)
	_busy = true
	var result: Dictionary = await shared.submit_defense_run(outcome.score, log)
	_busy = false
	if not _same(h, context): return _fail("STALE_RESPONSE")
	if not result.get("success", false): return result
	original.phase = "accepted-evidence-pending"
	original.run = {"runId": original.run.runId, "seed": original.run.seed}
	original.logHash = HorizonValidatedActions.computeInputLogHash(log)
	original.score = outcome.score
	var saved: Dictionary = _save(h, original, expected)
	if _uploaded_run == original.run.runId: _evidence_uploaded(_uploaded_run)
	return inspect() if saved.success else saved

func upload_original_evidence() -> Dictionary:
	var h: Node = _authorized()
	if h == null: return _fail("SESSION_REQUIRED")
	if _busy: return _fail("BUSY")
	var loaded: Dictionary = _load(h)
	if not loaded.success: return loaded
	var original: Dictionary = loaded.data
	if original.is_empty() or original.phase != "accepted-evidence-pending" or not original.has("moves"): return _fail("ORIGINAL_EVIDENCE_REQUIRED")
	var log: PackedByteArray = _input_log(original)
	if HorizonValidatedActions.computeInputLogHash(log) != original.logHash: return _fail("ORIGINAL_EVIDENCE_HASH_MISMATCH")
	_busy = true
	var context: String = _context(h)
	var success: bool = await h.validatedActions.uploadEvidence(original.run.runId, log)
	_busy = false
	if not _same(h, context): return _fail("STALE_RESPONSE")
	return inspect() if success else _fail(h.validatedActions.getLastEvidenceErrorCode())

func _evidence_uploaded(run_id: String) -> void:
	_uploaded_run = run_id
	var h: Node = _authorized()
	if h == null: return
	var loaded: Dictionary = _load(h)
	if not loaded.success or loaded.data.is_empty(): return
	var original: Dictionary = loaded.data
	if original.phase != "accepted-evidence-pending" or original.run.get("runId") != run_id: return
	var expected: Dictionary = original.duplicate(true)
	original.phase = "evidence-confirmed-awaiting-trusted-verification"
	original.erase("moves")
	_save(h, original, expected) # A late callback cannot replace a newer local original.

func acknowledge_local_success() -> Dictionary:
	var h: Node = _authorized()
	if h == null: return _fail("SESSION_REQUIRED")
	if _busy: return _fail("BUSY")
	var loaded: Dictionary = _load(h)
	if not loaded.success: return loaded
	if loaded.data.get("phase") != "evidence-confirmed-awaiting-trusted-verification": return _fail("UNCONFIRMED_ORIGINAL_RETAINED")
	var file: String = _path(h)
	var original: Dictionary = loaded.data.duplicate(true)
	var removed: bool = Storage._locked(file, func() -> bool: return Storage._read(file) == original and DirAccess.remove_absolute(ProjectSettings.globalize_path(file)) == OK)
	return {"success": true, "data": {"acknowledgedLocalRun": original.run.runId}, "errorCode": ""} if removed else _fail("PENDING_STORAGE_ERROR")

func cancel_unsent_challenge() -> Dictionary:
	var h: Node = _authorized()
	if h == null: return _fail("SESSION_REQUIRED")
	if _busy: return _fail("BUSY")
	var loaded: Dictionary = _load(h)
	if not loaded.success: return loaded
	if loaded.data.get("phase") != "prepared": return _fail("SENT_OR_UNCONFIRMED_ORIGINAL_RETAINED")
	var original: Dictionary = loaded.data.duplicate(true)
	var file: String = _path(h)
	var removed: bool = Storage._locked(file, func() -> bool: return Storage._read(file) == original and DirAccess.remove_absolute(ProjectSettings.globalize_path(file)) == OK)
	return {"success": true, "data": {"cancelledNeverStartedChallenge": original.challenge.challengeId}, "errorCode": ""} if removed else _fail("PENDING_STORAGE_ERROR")

func _input_log(original: Dictionary) -> PackedByteArray:
	var c: Dictionary = original.challenge
	return JSON.stringify({"version": VERSION, "challengeId": c.challengeId, "objectId": c.objectId, "revision": c.revision, "digest": c.digest, "runId": original.run.runId, "seed": original.run.seed, "moves": original.moves}).to_utf8_buffer()

func read_inbox() -> Dictionary:
	var h: Node = _authorized()
	return await h.inbox.getInbox(h.auth.getCurrentUser().userId) if h != null else _fail("SESSION_REQUIRED")

func inspect() -> Dictionary:
	var h: Node = _authorized()
	return _public(_load(h)) if h != null else _fail("SESSION_REQUIRED")

func _save(h: Node, record: Dictionary, expected: Dictionary) -> Dictionary:
	var file: String = _path(h)
	var success: bool = Storage._locked(file, func() -> bool:
		if FileAccess.file_exists(file + ".next"): return false
		if expected.is_empty():
			if FileAccess.file_exists(file): return false
		elif not FileAccess.file_exists(file) or Storage._read(file) != expected: return false
		return Storage._write(file, record))
	if not success: return _fail("ORIGINAL_CHANGED_OR_STORAGE_ERROR")
	return _public({"success": true, "data": record})

func _load(h: Node) -> Dictionary:
	var file: String = _path(h)
	if FileAccess.file_exists(file + ".next"): return _fail("PENDING_STORAGE_ERROR")
	if not FileAccess.file_exists(file): return {"success": true, "data": {}}
	var record: Dictionary = Storage._read(file)
	if record.get("scope") != _scope(h) or not valid_challenge(record.get("challenge")) or not record.get("phase") is String or not record.get("run") is Dictionary: return _fail("PENDING_STORAGE_ERROR")
	return {"success": true, "data": record}

func _public(result: Dictionary) -> Dictionary:
	if not result.get("success", false) or result.get("data", {}).is_empty(): return result
	var value: Dictionary = result.data.duplicate(true)
	value.run.erase("ticket")
	if value.has("moves") and not value.run.is_empty(): value.preview = simulate(value.run.seed, value.challenge.parameters, value.moves, false)
	return {"success": true, "data": value, "errorCode": ""}

func _scope(h: Node) -> String: return JSON.stringify([h._http.apiKey, h.auth.getCurrentUser().userId]).sha256_text()
func _path(h: Node) -> String: return "user://seagull_defense_" + _scope(h) + ".bin"
func _context(h: Node) -> String: return JSON.stringify([h._http.getContextGeneration(), h._http.apiKey, h._http.sessionToken, h.auth.getCurrentUser().userId])
func _same(h: Node, context: String) -> bool: return _authorized() == h and _context(h) == context
func _authorized() -> Node:
	var h: Node = get_node_or_null("/root/Horizon")
	var game: Node = get_node_or_null("/root/GameManager")
	return h if h != null and game != null and game.online_available() and h.auth.isSignedIn() and not h._http.sessionToken.is_empty() and h.auth.getCurrentUser().accessToken == h._http.sessionToken else null
func _fail(code: String) -> Dictionary: return {"success": false, "data": {}, "errorCode": code}
