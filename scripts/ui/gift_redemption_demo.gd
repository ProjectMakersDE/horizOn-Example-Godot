extends VBoxContainer
## V2 only. Original tuple belongs to the project/player, never to the regional host.
const Pending = preload("res://addons/horizon_sdk/examples/features/pending_gift_code.gd")
var _prepared: Dictionary = {}
var _prepared_context: String = ""
var _busy: bool = false
var _code: LineEdit
var _status: Label
var _output: Label

func _ready() -> void:
	StormUI.label(self, "Gift codes / V2", 23)
	StormUI.label(self, "Server values are already credited. Gift metadata never changes practice or Cloud Save coins.", 15, StormUI.MUTED)
	_code = StormUI.input(self, "Gift code")
	StormUI.button(self, "Prepare and review (read only)", func(): _show(await prepare(_code.text)))
	StormUI.button(self, "Confirm the reviewed redemption", func(): _show(await confirm_prepared()))
	StormUI.button(self, "Retry the same saved original", func(): _show(await retry_original()))
	_status = StormUI.label(self, "Use your existing signed-in player. No request runs when this panel opens.", 15, StormUI.TEAL)
	_output = StormUI.label(self, "No prepared original.", 15)

func prepare(code: String) -> Dictionary:
	var h: Node = _authorized()
	if h == null: return _failure("SESSION_REQUIRED")
	if _busy: return _failure("BUSY")
	var loaded: Dictionary = Pending.load_pending(h._http.apiKey, h.auth.getCurrentUser().userId)
	if not loaded.success: return _failure("PENDING_STORAGE_ERROR")
	if not loaded.pending.is_empty(): return _failure("PENDING_REDEMPTION")
	_prepared.clear()
	_prepared_context = _context(h)
	_busy = true
	var intent: Dictionary = await h.giftCodes.prepareRedemption(code)
	_busy = false
	if not _same(h, _prepared_context): return _failure("STALE_RESPONSE")
	if intent.is_empty(): return _failure(h.giftCodes.getLastErrorCode())
	_prepared = intent.duplicate(true)
	return {"success": true, "data": intent.duplicate(true), "errorCode": ""}

func confirm_prepared() -> Dictionary:
	var h: Node = _authorized()
	if h == null: return _failure("SESSION_REQUIRED")
	if _busy: return _failure("BUSY")
	if _prepared.is_empty() or not _same(h, _prepared_context): return _failure("REVIEW_REQUIRED")
	if not Pending.store(h._http.apiKey, _prepared): return _failure("PENDING_STORAGE_ERROR")
	_prepared.clear()
	return await retry_original()

func retry_original() -> Dictionary:
	var h: Node = _authorized()
	if h == null: return _failure("SESSION_REQUIRED")
	if _busy: return _failure("BUSY")
	var project: String = h._http.apiKey
	var user: String = h.auth.getCurrentUser().userId
	var loaded: Dictionary = Pending.load_pending(project, user)
	if not loaded.success: return _failure("PENDING_STORAGE_ERROR")
	if loaded.pending.is_empty(): return _failure("NO_PENDING_REDEMPTION")
	var context: String = _context(h)
	_busy = true
	var result: Dictionary = await h.giftCodes.redeemPrepared(loaded.pending)
	_busy = false
	if not _same(h, context): return _failure("STALE_RESPONSE")
	if result.get("success", false) and not Pending.confirm(project, loaded.pending): return _failure("PENDING_STORAGE_ERROR")
	return result # Every refusal/timeout retains the exact tuple. No automatic preparation.

func _show(result: Dictionary) -> void:
	if not is_inside_tree(): return
	_status.text = "Confirmed; current server state replaced." if result.get("success", false) and result.has("playerValues") else ("Original prepared; review its code, campaign, count and revision before confirming." if result.get("success", false) else "Original retained / no replacement: " + str(result.get("errorCode", "UNAVAILABLE")))
	_output.text = JSON.stringify(result, "  ")
	# Canonical decimal strings remain strings. No conversion to float/int for display.
	if result.get("errorCode") in ["UPGRADE_REQUIRED", "MIGRATION_REQUIRED", "V1_CLOSED"]:
		_status.text += " Studio migration/reconciliation is required."

func _authorized() -> Node:
	var h: Node = get_node_or_null("/root/Horizon")
	var manager: Node = get_node_or_null("/root/GameManager")
	return h if h != null and manager != null and manager.online_available() and not h._http.sessionToken.is_empty() and h.auth.getCurrentUser().accessToken == h._http.sessionToken else null
func _context(h: Node) -> String:
	return JSON.stringify([h._http.getContextGeneration(), h._http.apiKey, h._http.activeHost, h._http.sessionToken, h.auth.getCurrentUser().userId])
func _same(h: Node, context: String) -> bool: return _authorized() == h and _context(h) == context
func _failure(code: String) -> Dictionary: return {"success": false, "data": {}, "errorCode": code}
