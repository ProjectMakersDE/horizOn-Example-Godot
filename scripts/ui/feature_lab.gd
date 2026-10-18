extends VBoxContainer
## Explicit integration workbench shared by the game and Hello. No startup network work.
const Pending = preload("res://addons/horizon_sdk/examples/features/pending_match.gd")
const FEATURES: Dictionary = {
	"Achievements": [preload("res://addons/horizon_sdk/examples/features/achievements_example.gd"), [
		["Read achievements", "refresh_achievements", []], ["Unlock selected manual key", "unlock_selected", ["manual_hidden"]],
		["Reconcile selected legacy rewards", "deliver_selected_pending", [["manual_hidden"]]]]],
	"Friends": [preload("res://addons/horizon_sdk/examples/features/friends_example.gd"), [
		["Read friends and original requests", "refresh_friends", []], ["Find exact UUID / friend code", "find_exact", [""]],
		["Confirm relationship action", "change_relationship", ["request", "", 0, ""]]]],
	"Groups": [preload("res://addons/horizon_sdk/examples/features/groups_example.gd"), [
		["Read own groups", "refresh_groups", []], ["Read exact group", "inspect_group", [""]],
		["Read one configured member page", "load_member_page", ["", "", null]], ["Read original pending requests", "load_pending", [""]],
		["Confirm create at original player revision", "create_group", [0, "Seagulls", "open", "{}"]],
		["Confirm metadata at original group revision", "update_group", ["", 0, "Seagulls", "", "open", "{}"]],
		["Confirm group action", "confirm_action", ["join", "", 0, "", "", ""]]]],
	"Inbox": [preload("res://addons/horizon_sdk/examples/features/inbox_example.gd"), [
		["Read current Inbox", "refresh_inbox", []], ["Claim / retry the same original entry", "claim_selected_entry", [""]]]],
	"Items": [preload("res://addons/horizon_sdk/examples/features/items_example.gd"), [
		["Read authoritative inventory", "refresh_inventory", []], ["Read one catalog page", "load_catalog_page", ["", null]],
		["Review configured item offer", "review_offer", [""]], ["Confirm reviewed offer", "purchase_reviewed_offer", []],
		["Retry the original purchase", "retry_pending_purchase", []], ["Confirm equip state", "equip_item", ["", 0, true]],
		["Confirm property deltas", "adjust_item", ["", 0, [{"key": "durability", "amount": -1}]]],
		["Confirm permanent discard", "discard_item", ["", 0]], ["Acknowledge action after reading current inventory", "acknowledge_action_reconciliation", []]]],
	"Marketplace": [preload("res://addons/horizon_sdk/examples/features/marketplace_example.gd"), [
		["Read limits and current config", "read_limits", []], ["Read one rules page", "read_rules_page", ["", null]],
		["Read own Marketplace state", "read_marketplace", []], ["Read one public listings page", "read_listings", ["", 0, 9007199254740991, ""]],
		["Read exact listing", "read_listing", [""]], ["Read authoritative inventory", "read_inventory", []],
		["Review create from loaded rules/inventory", "review_create", ["", 10, 3600]], ["Review current buy", "review_buy", [""]],
		["Review current cancellation", "review_cancel", [""]], ["Confirm the reviewed trade", "confirm_reviewed_trade", []],
		["Retry saved original", "retry_pending", []], ["Look up saved original (read only)", "recover_original_operation", []],
		["Retry protected return delivery", "retry_return_delivery", [""]], ["Claim the same return Inbox entry", "claim_return", [""]]]],
	"Matches": [preload("res://addons/horizon_sdk/examples/features/matches_example.gd"), [
		["Read own matches", "read_matches", []], ["Read exact match", "read_match", [""]], ["Find one open page", "find_open", [2, 8, ""]],
		["Confirm create from reviewed ledger", "create_reviewed", [{"name": "Seagull match", "capacity": 2, "visibility": "private", "strength": 1, "turnSeconds": 60, "timeoutPolicy": "skip", "ranked": false, "dataBase64": "", "inviteeIds": []}]],
		["Confirm reviewed move / lifecycle action", "perform_reviewed", ["join", {}]],
		["Recover original pending ranked source", "recover_pending_ranked_result", [""]], ["Inspect pending outcome (read only)", "inspect_pending", []], ["Retry original final report / ranked start", "retry_original_report_or_run", []],
		["Acknowledge explicitly reviewed reconciliation", "acknowledge_reconciliation", []]]],
	"Shared Objects": [preload("res://addons/horizon_sdk/examples/features/shared_objects_example.gd"), [
		["Read one collection page", "load_collections", ["", null]], ["Read owner usage", "read_usage", ["bases"]],
		["Read exact opaque object", "read_marker", ["bases", ""]], ["Confirm create with reviewed usage", "create_marker", ["", {}, null, ""]],
		["Confirm update of reviewed object", "update_reviewed_marker", ["", {}, null]], ["Confirm deletion of reviewed object", "delete_reviewed_marker", []],
		["Read one rectangle page", "query_rectangle", ["bases", 0, 100, 0, 100, "", ""]], ["Read numeric opponent sample", "sample_opponents", ["defenses", 1, 100]],
		["Inspect original outcome (read only)", "inspect_pending", [""]], ["Acknowledge explicitly reviewed reconciliation", "acknowledge_reconciliation", []]]]
}
const SOCIAL_WRITES: Array[String] = ["change_relationship", "create_group", "update_group", "confirm_action"]
var feature: String = "Achievements"
var _feature: OptionButton
var _action: OptionButton
var _arguments: TextEdit
var _project: LineEdit
var _status: Label
var _output: TextEdit
var _recipes: Dictionary = {}
var _group_reads: Dictionary = {}
var _busy: bool = false
var _chat_screen: Node

func _ready() -> void:
	StormUI.label(self, "Current SDK feature lab", 23)
	StormUI.label(self, "Explicit actions for the existing signed-in player. Configure the server first; empty catalogs and unsupported capabilities stay visible. Never paste an Account Key.", 15, StormUI.MUTED)
	_project = StormUI.input(self, "Stable project UUID (Marketplace only; saved once per project key)")
	_feature = OptionButton.new()
	for name: String in FEATURES: _feature.add_item(name)
	add_child(_feature)
	_feature.item_selected.connect(_select_feature)
	_action = OptionButton.new(); add_child(_action)
	_action.item_selected.connect(_select_action)
	_arguments = TextEdit.new(); _arguments.custom_minimum_size.y = 120; add_child(_arguments)
	StormUI.label(self, "Arguments follow the SDK sample's named action. Keep the original revision/request IDs after uncertainty. For opaque Shared bytes, the first argument is canonical Base64. No automatic pages, moves or retries.", 14, StormUI.MUTED)
	StormUI.button(self, "Run the selected explicit action", _run_selected)
	StormUI.button(self, "Inspect saved Friends/Groups original (local only)", func(): _show(inspect_social_original(feature)))
	StormUI.button(self, "Acknowledge social original after a newer authoritative read", func(): _show(acknowledge_social_original(feature)))
	StormUI.button(self, "Open Chat: explicit subscription, plain text and device history", _chat)
	StormUI.button(self, "Open world map / trusted defense recipe", _defense)
	_status = StormUI.label(self, "No network action has run.", 15, StormUI.TEAL)
	_output = TextEdit.new(); _output.editable = false; _output.custom_minimum_size.y = 220; add_child(_output)
	var index: int = FEATURES.keys().find(feature)
	_feature.select(maxi(index, 0)); _select_feature(_feature.selected)

func _defense() -> void:
	var window := Window.new()
	window.title = "World map / asynchronous defense recipe"
	window.size = Vector2i(700, 780)
	var scroll := ScrollContainer.new()
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	window.add_child(scroll)
	var panel := preload("res://scripts/ui/defense_recipe_panel.gd").new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(panel)
	add_child(window)
	window.close_requested.connect(window.queue_free)
	window.popup_centered()

func _select_feature(index: int) -> void:
	feature = _feature.get_item_text(index)
	_action.clear()
	for action: Array in FEATURES[feature][1]: _action.add_item(action[0])
	_select_action(0)
func _select_action(index: int) -> void:
	_arguments.text = JSON.stringify({"args": FEATURES[feature][1][index][2]}, "  ")
func _run_selected() -> void:
	_show(await execute_input(feature, FEATURES[feature][1][_action.selected][1], _arguments.text))

## Group data is an original JSON string inside the argument envelope. Its own
## lossless Groups codec permits finite decimals/depth independently of counters.
func execute_input(selected: String, method: String, json: String) -> Dictionary:
	var parsed: Dictionary = HorizonItemModels.parseTransport(json)
	if not parsed.get("args") is Array: return _failure("INVALID_ARGUMENTS")
	return await execute(selected, method, parsed.args)

## Public boundary also exercised by the native consumer fixture, with the same SDK recipes.
func execute(selected: String, method: String, arguments: Array) -> Dictionary:
	var h: Node = _authorized()
	if h == null: return _failure("SESSION_REQUIRED")
	if _busy: return _failure("BUSY")
	if not _known(selected, method, arguments): return _failure("INVALID_ARGUMENTS")
	var recipe: Node = _recipe(selected, h)
	if recipe == null: return _failure("PROJECT_BINDING_REQUIRED")
	var args: Array = arguments.duplicate(true)
	if selected == "Groups" and method in ["create_group", "update_group"] and args[-1] is String:
		args[-1] = HorizonGroupJsonData.fromJson(args[-1])
		if args[-1] == null: return _failure("INVALID_ARGUMENTS")
	if selected == "Shared Objects" and method in ["create_marker", "update_reviewed_marker"]:
		var bytes: Variant = HorizonSharedObjectModels.decodeBytes(args[0])
		if not bytes is PackedByteArray: return _failure("INVALID_ARGUMENTS")
		args[0] = bytes
	var context: String = _context(h)
	var original: Dictionary = {}
	if method in SOCIAL_WRITES:
		if not _social_request_valid(selected, method, arguments, h): return _failure("INVALID_ARGUMENTS")
		original = {"project": h._http.apiKey.sha256_text(), "user": h.auth.getCurrentUser().userId, "feature": selected, "method": method, "args": arguments.duplicate(true)}
		if not Pending.store(_social_path(h, selected), original): return _failure("PENDING_SOCIAL_ACTION")
	_busy = true
	var result: Dictionary = await recipe.callv(method, args)
	_busy = false
	if _authorized() != h or context != _context(h): return _failure("STALE_RESPONSE")
	if selected == "Groups" and method == "inspect_group" and result.get("success", false):
		_group_reads[args[0]] = {"result": result.duplicate(true), "context": context}
	if not original.is_empty() and result.get("success", false) and not Pending.confirm(_social_path(h, selected), original): return _failure("PENDING_STORAGE_ERROR")
	return result

func _known(selected: String, method: String, args: Array) -> bool:
	if not FEATURES.has(selected): return false
	for action: Array in FEATURES[selected][1]:
		if action[1] != method: continue
		if args.size() != action[2].size(): return false
		for index: int in args.size():
			if selected == "Groups" and method in ["create_group", "update_group"] and index == args.size() - 1:
				if args[index] is String:
					if HorizonGroupJsonData.fromJson(args[index]) == null: return false
				elif not args[index] is Dictionary or HorizonGroupJsonData.fromDictionary(args[index]) == null: return false
				continue
			var expected: int = typeof(action[2][index])
			if expected == TYPE_NIL:
				if args[index] != null and not HorizonItemModels.integer(args[index]): return false
			elif typeof(args[index]) != expected: return false
		if method == "perform_reviewed" and args[0] in ["result", "ranked-run"] and not HorizonItemModels.integer(args[1].get("finalStateRevision"), 1): return false
		return true
	return false

func _social_request_valid(selected: String, method: String, args: Array, h: Node) -> bool:
	if selected == "Friends":
		if args[0] not in ["request", "accept", "decline", "cancel", "remove", "block", "unblock"] or not HorizonItemModels.uuid(args[1]) or args[1].to_lower() == h.auth.getCurrentUser().userId.to_lower() or not HorizonItemModels.integer(args[2]): return false
		return HorizonItemModels.uuid(args[3]) if args[0] in ["accept", "decline", "cancel"] else args[3].is_empty()
	if method == "create_group": return HorizonItemModels.integer(args[0]) and not args[1].strip_edges().is_empty() and args[2] in ["open", "request", "invite"]
	if method == "update_group": return HorizonItemModels.uuid(args[0]) and HorizonItemModels.integer(args[1]) and not args[2].strip_edges().is_empty() and args[4] in ["open", "request", "invite"]
	if args[0] not in ["join", "request", "invite", "accept-invite", "decline-invite", "cancel-invite", "accept-request", "decline-request", "cancel-request", "leave", "remove", "role", "transfer", "delete"] or not HorizonItemModels.uuid(args[1]) or not HorizonItemModels.integer(args[2]): return false
	if args[0] in ["invite", "cancel-invite", "accept-request", "decline-request", "remove", "role", "transfer"] and not HorizonItemModels.uuid(args[3]): return false
	if args[0] in ["accept-invite", "decline-invite", "cancel-invite", "accept-request", "decline-request", "cancel-request"] and not HorizonItemModels.uuid(args[4]): return false
	return args[0] != "role" or args[5] in ["officer", "member"]

func _recipe(selected: String, h: Node) -> Node:
	if selected == "Marketplace":
		var binding: Dictionary = _project_binding(h)
		if not binding.success: return null
		if not _recipes.has(selected): _recipes[selected] = FEATURES[selected][0].new(); add_child(_recipes[selected])
		_recipes[selected].project_id = binding.projectId
	elif not _recipes.has(selected):
		_recipes[selected] = FEATURES[selected][0].new(); add_child(_recipes[selected])
	return _recipes[selected]

func _project_binding(h: Node) -> Dictionary:
	var path: String = "user://seagull_project_binding_" + h._http.apiKey.sha256_text() + ".bin"
	var saved: Dictionary = Pending.load_pending(path)
	if not saved.success: return _failure("PENDING_STORAGE_ERROR")
	if not saved.pending.is_empty():
		if saved.pending.keys().size() != 1 or not HorizonMarketplaceModels.uuid(saved.pending.get("projectId")): return _failure("PROJECT_BINDING_REQUIRED")
		if not _project.text.is_empty() and _project.text != saved.pending.projectId: return _failure("PROJECT_BINDING_MISMATCH")
		_project.text = saved.pending.projectId
		return {"success": true, "projectId": saved.pending.projectId}
	if not HorizonMarketplaceModels.uuid(_project.text): return _failure("PROJECT_BINDING_REQUIRED")
	if not Pending.store(path, {"projectId": _project.text}): return _failure("PENDING_STORAGE_ERROR")
	return {"success": true, "projectId": _project.text}

func inspect_social_original(selected: String) -> Dictionary:
	var h: Node = _authorized()
	if h == null: return _failure("SESSION_REQUIRED")
	if selected not in ["Friends", "Groups"]: return _failure("SELECT_FRIENDS_OR_GROUPS")
	var saved: Dictionary = Pending.load_pending(_social_path(h, selected))
	if not saved.success: return _failure("PENDING_STORAGE_ERROR")
	var value: Dictionary = saved.pending
	if value.is_empty(): return _failure("NO_PENDING_ACTION")
	if value.get("project") != h._http.apiKey.sha256_text() or value.get("user") != h.auth.getCurrentUser().userId or value.get("feature") != selected or not value.get("args") is Array or not _known(selected, str(value.get("method")), value.args) or value.method not in SOCIAL_WRITES: return _failure("PENDING_STORAGE_ERROR")
	return {"success": true, "data": value.duplicate(true), "errorCode": ""}

func acknowledge_social_original(selected: String) -> Dictionary:
	if _busy: return _failure("BUSY")
	var h: Node = _authorized()
	if h == null: return _failure("SESSION_REQUIRED")
	var saved: Dictionary = inspect_social_original(selected)
	if not saved.success: return saved
	var value: Dictionary = saved.data
	var revision: Variant = null
	var original_revision: Variant = value.args[2] if selected == "Friends" or value.method == "confirm_action" else value.args[0 if value.method == "create_group" else 1]
	if selected == "Friends": revision = h.friends.getCurrentFriends().get("revision")
	elif value.method == "create_group": revision = h.groups.getCurrentGroups().get("revision")
	else:
		var id: String = value.args[1] if value.method == "confirm_action" else value.args[0]
		var read: Dictionary = _group_reads.get(id, {})
		if read.get("context") == _context(h): revision = read.result.get("data", {}).get("revision")
	# A permanently advanced CAS anchor proves that the old command cannot apply later.
	# Missing/hidden groups are not silently declared safe; studio reconciliation stays explicit.
	if not HorizonItemModels.integer(original_revision) or not HorizonItemModels.integer(revision) or revision <= original_revision: return _failure("NEWER_AUTHORITATIVE_READ_REQUIRED")
	if not Pending.confirm(_social_path(h, selected), value): return _failure("PENDING_STORAGE_ERROR")
	return {"success": true, "data": {"reconciledOriginal": value, "observedRevision": revision}, "errorCode": ""}

func _social_path(h: Node, selected: String) -> String:
	return "user://seagull_social_original_" + JSON.stringify([h._http.apiKey, h.auth.getCurrentUser().userId, selected]).sha256_text() + ".bin"
func _chat() -> void:
	if _authorized() == null: _show(_failure("SESSION_REQUIRED")); return
	if is_instance_valid(_chat_screen): return
	_chat_screen = preload("res://addons/horizon_sdk/examples/features/chat_demo.tscn").instantiate()
	add_child(_chat_screen) # Chat's ready creates UI only. Subscription/send are separate player actions.
func _show(result: Dictionary) -> void:
	if not is_inside_tree(): return
	_status.text = "Action completed; inspect the authoritative result." if result.get("success", false) else "Original retained / action refused: " + str(result.get("errorCode", "UNAVAILABLE"))
	_output.text = JSON.stringify(result, "  ")
func _authorized() -> Node:
	var h: Node = get_node_or_null("/root/Horizon")
	var manager: Node = get_node_or_null("/root/GameManager")
	return h if h != null and manager != null and manager.online_available() and not h._http.sessionToken.is_empty() and h.auth.getCurrentUser().accessToken == h._http.sessionToken else null
func _context(h: Node) -> String:
	return JSON.stringify([h._http.getContextGeneration(), h._http.apiKey, h._http.activeHost, h._http.sessionToken, h.auth.getCurrentUser().userId])
func _failure(code: String) -> Dictionary: return {"success": false, "data": {}, "errorCode": code}
