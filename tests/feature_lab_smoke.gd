extends SceneTree
const U: String = "abcdefab-cdef-4abc-8def-000000001016"
const V: String = "abcdefab-cdef-4abc-8def-000000001017"
const W: String = "abcdefab-cdef-4abc-8def-000000001018"
const I: String = "abcdefab-cdef-4abc-8def-000000004016"
const J: String = "abcdefab-cdef-4abc-8def-000000004017"
const L: String = "abcdefab-cdef-4abc-8def-000000005016"
const R: int = 4294967296
const Lab = preload("res://scripts/ui/feature_lab.gd")
var failures: Array[String] = []
func _initialize() -> void:
	call_deferred("_run")
	call_deferred("_watchdog")
func check(value: bool, message: String) -> void:
	if not value: failures.append(message); push_error(message)
func _run() -> void:
	await process_frame
	var h: Node = root.get_node("Horizon")
	var manager: Node = root.get_node("GameManager")
	var url: String = OS.get_environment("SEAGULL_LAB_URL")
	check(url.begins_with("http://127.0.0.1:"), "Only isolated loopback is permitted")
	if not failures.is_empty(): quit(1); return
	h._http.activeHost = url
	h._http.apiKey = "lab-project-key"
	h._http.maxRetryAttempts = 0
	h._isConnected = true
	h._http._status = HorizonHttpClient.ConnectionStatus.CONNECTED
	h._config = HorizonConfig.new(); h._config.api_key = "lab-project-key"
	# Construct the actual Hello and actual in-game SDK panel before authentication.
	# The fixture's first permitted request is the explicit sign-in below.
	var hello: Node = preload("res://examples/hello_features/hello_features.tscn").instantiate()
	root.add_child(hello); current_scene = hello
	var game_panel: Node = load("res://scripts/ui/sdk_panel.gd").new()
	root.add_child(game_panel)
	game_panel._feature_lab()
	var lab: Node = _find_script(hello, "res://scripts/ui/feature_lab.gd")
	check(lab != null, "Actual Hello exposes the shared feature lab")
	check((await lab.execute("Friends", "refresh_friends", [])).errorCode == "SESSION_REQUIRED", "Offline open never authenticates or creates a replacement guest")
	var signed_in: bool = await h.auth.signInEmail("lab@example.invalid", "synthetic-password")
	check(signed_in, "Existing account uses actual SDK transport")
	if not signed_in: quit(1); return
	manager.enter_online()
	var local_coins: int = manager.save_data.coins
	check((await lab.execute("Achievements", "refresh_achievements", [])).success, "Current achievement catalog is visible")
	check((await lab.execute("Friends", "refresh_friends", [])).success, "Friend code and complete relation snapshot load")
	check((await lab.execute("Friends", "change_relationship", ["request", "", R, ""])).errorCode == "INVALID_ARGUMENTS", "Invalid target never occupies a durable original")
	check(not (await lab.execute("Friends", "change_relationship", ["request", V, R, ""])).success, "Lost request response is uncertain")
	var original: Dictionary = lab.inspect_social_original("Friends")
	check(original.success and original.data.args[2] == R, "Original social revision is persisted exactly")
	lab.queue_free(); await process_frame
	lab = Lab.new(); root.add_child(lab)
	check(lab.inspect_social_original("Friends").data == original.data, "Recreated screen loads the same original")
	check((await lab.execute("Friends", "change_relationship", ["request", W, R+1, ""])).errorCode == "PENDING_SOCIAL_ACTION", "Uncertain request blocks replacement")
	check(lab.acknowledge_social_original("Friends").errorCode == "NEWER_AUTHORITATIVE_READ_REQUIRED", "ACK cannot guess an outcome")
	check((await lab.execute("Friends", "refresh_friends", [])).success, "Read after uncertainty sees current server state")
	check(lab.acknowledge_social_original("Friends").success, "Permanently advanced CAS anchor allows explicit reconciliation")
	check((await lab.execute("Friends", "change_relationship", ["request", W, R+1, ""])).success, "A separate confirmed action uses the reviewed current revision")
	check((await lab.execute("Groups", "refresh_groups", [])).success, "Current player group ledger loads")
	check(not (await lab.execute("Groups", "create_group", [R, "Seagulls", "open", {}])).success, "Lost group-create response stays protected")
	var group_original: Dictionary = lab.inspect_social_original("Groups")
	lab.queue_free(); await process_frame
	lab = Lab.new(); root.add_child(lab)
	check(lab.inspect_social_original("Groups").data == group_original.data, "Original group creation survives screen recreation")
	check((await lab.execute("Groups", "refresh_groups", [])).success, "Original creation is recovered by GET, never a second create")
	check(lab.acknowledge_social_original("Groups").success, "New player ledger revision safely fences the original create")
	check((await lab.execute("Inbox", "refresh_inbox", [])).success, "Protected original item-return entry is visible")
	check(not (await lab.execute("Inbox", "claim_selected_entry", ["message:"+I])).success, "Unknown claim retains its original entry ID")
	lab.queue_free(); await process_frame
	lab = Lab.new(); root.add_child(lab)
	check((await lab.execute("Inbox", "claim_selected_entry", ["message:"+J])).errorCode == "PENDING_CLAIM", "Restart cannot substitute another Inbox entry")
	check((await lab.execute("Inbox", "claim_selected_entry", ["message:"+I])).success, "Original Inbox claim returns current replay state")
	var inventory: Dictionary = await lab.execute("Items", "refresh_inventory", [])
	check(inventory.success and inventory.data.instances.is_empty(), "Current empty inventory stays empty after historical item-return replay")
	check((await lab.execute("Items", "load_catalog_page", ["", null])).success, "Current item catalog uses explicit bounded pages")
	check((await lab.execute("Shared Objects", "load_collections", ["", null])).success, "Opaque object collection catalog loads without fabricating content")
	check((await lab.execute("Matches", "read_matches", [])).success, "Match ledger loads explicitly")
	var options: Dictionary = Lab.FEATURES.Matches[1][3][2][0].duplicate(true)
	check((await lab.execute("Matches", "create_reviewed", [options])).success, "Explicit match create reuses the durable official recipe and original If-Match")
	lab._project.text = "10000000-0000-4000-8000-000000001016"
	check((await lab.execute("Marketplace", "read_limits", [])).success, "Marketplace config and quotas load")
	check((await lab.execute("Marketplace", "read_rules_page", ["", null])).success, "One rules page is explicit")
	check((await lab.execute("Marketplace", "read_marketplace", [])).success, "Own current Marketplace state loads")
	var guide: Node = preload("res://examples/public_marketplace/marketplace_demo.gd").new()
	guide.screen = lab._recipes.Marketplace; root.add_child(guide)
	check((await guide.read_listing(L)).success, "Unchanged public Guide read executes the actual Quickstart")
	check((await guide.confirm_purchase(L)).success, "Unchanged public Guide Buy delegates to the durable original and current refreshes")
	check(h.items.getCurrentInventory().instances.size() == 1 and h.items.getCurrentInventory().instances[0].instanceId == J, "Only the new authoritative inventory is rendered; discarded historical original is not recreated")
	check(h.playerValues.getCurrentState().values[0].balance == 37, "Marketplace uses current server balances")
	check(manager.save_data.coins == local_coins, "Server rewards, Inbox and Marketplace never alter local coins")
	lab._chat()
	check(is_instance_valid(lab._chat_screen), "Game reuses the existing plain-text Chat UI")
	await lab._chat_screen._open()
	check(lab._chat_screen._status.text.contains("NOT_SUPPORTED"), "Actual Chat open preserves PHP unsupported; no polling or fake hosted chat")
	game_panel.queue_free(); guide.queue_free(); lab.queue_free(); hello.queue_free()
	root.get_node("AudioManager").shutdown()
	await process_frame
	if failures.is_empty(): print("FEATURE_LAB_SMOKE_PASS: actual game/Hello + public Guide; explicit reads/writes and protected originals")
	quit(0 if failures.is_empty() else 1)
func _find_script(node: Node, path: String) -> Node:
	if node.get_script() != null and node.get_script().resource_path == path: return node
	for child: Node in node.get_children():
		var found: Node = _find_script(child, path)
		if found != null: return found
	return null
func _watchdog() -> void:
	await create_timer(35).timeout
	push_error("Feature lab native fixture exceeded watchdog")
	quit(1)
