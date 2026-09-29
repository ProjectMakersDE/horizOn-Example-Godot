## Validated Run Recorder - horizOn Validated Actions for one survival run
##
## Starts a server-checked run (ticket + seed), records a compact input log and
## submits the final score through Horizon.validatedActions. The server checks
## the ticket and the rules of the API key before it writes the leaderboard.
##
## Only active when the SDK ships Validated Actions (Horizon.validatedActions,
## horizOn SDK release with TASK-883) and Remote Config
## `validated_runs_enabled` is true. Otherwise the game uses the normal
## leaderboard submit.
##
## Input log format v1 (little endian, at most MAX_LOG_BYTES):
##   header: u8 format version, u32 run seed
##   events: u16 physics ticks since the previous event, u8 event code
##     0x00 to 0x0F  movement: bit 0 left, bit 1 right, bit 2 up, bit 3 down
##     0x10 to 0x1F  level-up choice, low 4 bits = button index
##     0xFF          run end
class_name ValidatedRunRecorder
extends RefCounted

const LOG_FORMAT_VERSION := 1
const MAX_LOG_BYTES := 32768
const EVENT_SIZE := 3
const EVENT_MOVE := 0x00
const EVENT_LEVELUP_CHOICE := 0x10
const EVENT_RUN_END := 0xFF
const MAX_TICK_GAP := 65535
const DEFAULT_BOARD := "default"

## Board the run is bound to (Remote Config `validated_runs_board`)
var board_key: String = DEFAULT_BOARD
## Result of the last validated submit ({} when none or rejected)
var last_result: Dictionary = {}
## Error code of the last start or submit failure ("" when none)
var last_error_code: String = ""
## Short text for the game over screen ("" when the run was not validated)
var last_message: String = ""

var _active: bool = false
var _log := PackedByteArray()
var _ticks_since_event: int = 0
var _last_move: int = -1
var _truncated: bool = false


## True when the bundled SDK ships Validated Actions.
static func sdk_available() -> bool:
	return Horizon.get("validatedActions") != null


## True when Validated Actions is available and switched on in Remote Config.
static func is_enabled() -> bool:
	return sdk_available() and ConfigCache.get_bool("validated_runs_enabled", false)


## True while a validated run waits for its submit.
func is_active() -> bool:
	return _active


## Start a validated run bound to the game's leaderboard and seed the random
## number generator with the server seed. Returns false (normal submit at game
## over) when the feature is off or the server refuses the run.
func begin() -> bool:
	_reset()
	if not is_enabled():
		randomize()
		return false

	board_key = ConfigCache.get_string("validated_runs_board", DEFAULT_BOARD).strip_edges()
	if board_key.is_empty():
		board_key = DEFAULT_BOARD

	var va = Horizon.get("validatedActions")
	# Upload the input log right away when the server asks for evidence.
	if "auto_upload_evidence" in va:
		va.auto_upload_evidence = true
	_connect_evidence_signals(va)

	var run: Dictionary = await va.startRun(board_key)
	if run.is_empty():
		last_error_code = va.getLastErrorCode()
		last_message = "Not validated: %s" % describe_error(last_error_code)
		Horizon.crashes.record_breadcrumb("validated_run", "start_failed_%s" % last_error_code)
		randomize()
		return false

	var run_seed := int(run.get("seed", 0))
	seed(run_seed)
	_log.append(LOG_FORMAT_VERSION)
	_append_u32(run_seed)
	_active = true
	Horizon.crashes.record_breadcrumb("validated_run", "started")
	return true


## Record the movement input of one physics tick. Writes an event only when
## the direction changes, so a whole run stays a few kilobytes.
func record_move(input: Vector2) -> void:
	if not _active:
		return
	var code := EVENT_MOVE
	if input.x < 0.0:
		code |= 1
	elif input.x > 0.0:
		code |= 2
	if input.y < 0.0:
		code |= 4
	elif input.y > 0.0:
		code |= 8

	_ticks_since_event += 1
	if code != _last_move or _ticks_since_event >= MAX_TICK_GAP:
		_last_move = code
		_write_event(code)


## Record which level-up button the player picked.
func record_levelup_choice(index: int) -> void:
	if _active:
		_write_event(EVENT_LEVELUP_CHOICE | (index & 0x0F))


## Submit the run. The SDK hashes the log, sends score and stage and uploads
## the log itself when the server asks for evidence (auto_upload_evidence).
## @param earned Array of {"key", "amount"}, only for values the rules define
## @return The submit result, {} when rejected (see last_error_code)
func finish(score: int, stage: String, earned: Array = []) -> Dictionary:
	if not _active:
		return {}
	_active = false
	# Room for the end marker is reserved by _write_event().
	_append_event(EVENT_RUN_END)

	var va = Horizon.get("validatedActions")
	var result: Dictionary = await va.submitValidated(score, _log, stage, board_key, earned)
	if result.is_empty():
		last_error_code = va.getLastErrorCode()
		last_message = "Score not accepted: %s" % describe_error(last_error_code)
		Horizon.crashes.record_breadcrumb("validated_run", "rejected_%s" % last_error_code)
		return {}

	last_result = result
	var rank := int(result.get("rank", 0))
	last_message = "Validated run" if rank <= 0 else "Validated run, rank #%d" % rank
	if _truncated:
		push_warning("Validated run: the input log reached %d bytes and was cut" % MAX_LOG_BYTES)
	Horizon.crashes.record_breadcrumb("validated_run", "accepted")
	return result


## Player friendly text for a Validated Actions error code.
static func describe_error(code: String) -> String:
	match code:
		"DURATION_TOO_SHORT":
			return "run was too short"
		"SCORE_ABOVE_MAX", "STAGE_SCORE_ABOVE_MAX":
			return "score above the allowed maximum"
		"SCORE_BELOW_MIN", "STAGE_SCORE_BELOW_MIN":
			return "score below the board minimum"
		"SCORE_RATE_TOO_HIGH":
			return "score rose too fast"
		"STAGE_REQUIRED", "STAGE_UNKNOWN":
			return "wave not allowed by the rules"
		"TICKET_EXPIRED":
			return "run ticket expired"
		"TICKET_INVALID", "TICKET_FOREIGN", "TICKET_CONSUMED":
			return "run ticket not valid"
		"LEADERBOARD_MISMATCH", "LEADERBOARD_NOT_FOUND":
			return "leaderboard not set up"
		"UNKNOWN_VALUE_KEY", "EARNED_ABOVE_MAX", "EARNED_BELOW_MIN", "INSUFFICIENT_BALANCE":
			return "coins not allowed by the rules"
		"SCORE_LIMIT_REACHED":
			return "leaderboard is full"
		"PLAYER_BANNED":
			return "you are banned from this board"
		"RUN_RATE_LIMITED", "RUN_CAPACITY_REACHED", "API_RATE_LIMITED":
			return "too many runs, try again later"
		"SESSION_REQUIRED":
			return "sign in first"
		"NOT_SUPPORTED", "VALIDATED_ACTIONS_UNAVAILABLE":
			return "validation not available"
		"NETWORK_ERROR":
			return "no connection"
	return "error %s" % code if not code.is_empty() else "unknown error"


func _reset() -> void:
	_active = false
	_log = PackedByteArray()
	_ticks_since_event = 0
	_last_move = -1
	_truncated = false
	last_result = {}
	last_error_code = ""
	last_message = ""


## Write one event; keeps EVENT_SIZE bytes free for the end marker.
func _write_event(code: int) -> void:
	if _log.size() + 2 * EVENT_SIZE > MAX_LOG_BYTES:
		_truncated = true
		return
	_append_event(code)


func _append_event(code: int) -> void:
	var ticks := mini(_ticks_since_event, MAX_TICK_GAP)
	_log.append(ticks & 0xFF)
	_log.append((ticks >> 8) & 0xFF)
	_log.append(code & 0xFF)
	_ticks_since_event = 0


func _append_u32(value: int) -> void:
	for shift in [0, 8, 16, 24]:
		_log.append((value >> shift) & 0xFF)


func _connect_evidence_signals(va: Object) -> void:
	if va.has_signal("evidence_uploaded") and not va.is_connected("evidence_uploaded", _on_evidence_uploaded):
		va.connect("evidence_uploaded", _on_evidence_uploaded)
	if va.has_signal("evidence_upload_failed") and not va.is_connected("evidence_upload_failed", _on_evidence_upload_failed):
		va.connect("evidence_upload_failed", _on_evidence_upload_failed)


func _on_evidence_uploaded(_run_id: String) -> void:
	Horizon.crashes.record_breadcrumb("validated_run", "evidence_uploaded")


func _on_evidence_upload_failed(_run_id: String, error: String, code: String) -> void:
	Horizon.crashes.record_breadcrumb("validated_run", "evidence_failed_%s" % code)
	push_warning("Validated run: evidence upload failed (%s): %s" % [code, error])
