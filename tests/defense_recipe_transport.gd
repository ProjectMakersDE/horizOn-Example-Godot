extends SceneTree
var failures: Array[String] = []
func check(value: bool, message: String) -> void:
	if not value: failures.append(message); push_error(message)
func _initialize() -> void:
	call_deferred("_run")
	call_deferred("_watchdog")
func _watchdog() -> void:
	await create_timer(45).timeout
	push_error("Defense transport fixture timeout"); quit(1)
func button(panel: Node, prefix: String) -> Button:
	for node: Node in panel.get_children():
		if node is Button and node.text.begins_with(prefix): return node
	return null
func _run() -> void:
	await process_frame
	var url: String = OS.get_environment("SEAGULL_DEFENSE_URL")
	check(url.begins_with("http://127.0.0.1:") and not url.begins_with("http://127.0.0.1:3170"), "Isolated ephemeral loopback only")
	if not failures.is_empty(): quit(1); return
	var h: Node = root.get_node("Horizon")
	h._http.activeHost = url; h._http.apiKey = "defense-synthetic-project"; h._http.maxRetryAttempts = 0
	h._isConnected = true; h._http._status = HorizonHttpClient.ConnectionStatus.CONNECTED
	h._config = HorizonConfig.new(); h._config.api_key = h._http.apiKey
	check(await h.auth.signInEmail("defense@example.invalid", "synthetic-password"), "Actual SDK existing-session transport")
	root.get_node("GameManager").enter_online()
	var panel: Node = preload("res://scripts/ui/defense_recipe_panel.gd").new(); root.add_child(panel)
	await process_frame
	var recipe: Node = panel._recipe
	check((await recipe.review_usage()).success, "Actual original owner usage read")
	check((await recipe.publish_defense(15, 3, 10, 10)).success, "Actual durable sample conditional defense create")
	check((await recipe.read_map()).success, "Actual world-map rectangle query")
	check((await recipe.find_opponents()).success, "Actual bounded opponent sample")
	panel._challenge.text = OS.get_environment("SEAGULL_DEFENSE_CHALLENGE")
	button(panel, "Save this reviewed trusted challenge").pressed.emit()
	check(recipe.inspect().get("data", {}).get("phase") == "prepared", "Actual UI saves trusted public challenge without account credentials")
	var second: Node = preload("res://scripts/ui/defense_recipe_panel.gd").new(); root.add_child(second); await process_frame
	button(panel, "Read original defense and start").pressed.emit()
	button(second, "Read original defense and start").pressed.emit()
	var deadline: int = Time.get_ticks_msec() + 10000
	while recipe.inspect().get("data", {}).get("phase") != "playing" and Time.get_ticks_msec() < deadline: await create_timer(0.01).timeout
	check(recipe.inspect().get("data", {}).get("phase") == "playing", "Actual UI reads original object and starts real SDK run")
	await create_timer(0.25).timeout
	check(recipe.inspect().get("data", {}).get("run", {}).get("runId") != null and second._output.text.contains("ORIGINAL_CHANGED_OR_STORAGE_ERROR"), "Late second-panel GET cannot overwrite first original run binding")
	second.queue_free()
	button(panel, "Attack").pressed.emit()
	check(recipe.inspect().get("data", {}).get("preview", {}).get("score") == 1201, "Actual one-turn UI gameplay has independent score")
	button(panel, "Submit the finished").pressed.emit()
	deadline = Time.get_ticks_msec() + 10000
	while recipe.inspect().get("data", {}).get("phase") != "evidence-confirmed-awaiting-trusted-verification" and Time.get_ticks_msec() < deadline: await create_timer(0.01).timeout
	check(recipe.inspect().get("data", {}).get("phase") == "evidence-confirmed-awaiting-trusted-verification", "Actual UI SDK submit and evidence upload accept; trusted notice not client-issued")
	var stored: Dictionary = recipe.inspect().data
	check(not stored.has("moves") and not stored.run.has("ticket"), "Definite acceptance drops unnecessary raw log/ticket copies")
	check(not recipe.import_challenge(panel._challenge.text).success, "A second panel cannot silently replace the existing run binding")
	panel.queue_free(); await process_frame
	panel = preload("res://scripts/ui/defense_recipe_panel.gd").new(); root.add_child(panel); await process_frame
	check(panel._recipe.inspect().data.run == stored.run, "Recreated actual UI retains original run binding")
	button(panel, "Acknowledge confirmed local evidence").pressed.emit()
	check(panel._recipe.inspect().data.is_empty(), "Explicit confirmed local ACK keeps no permanent completed-run archive")
	if failures.is_empty(): print("DEFENSE_RECIPE_NATIVE_HTTP_PASS")
	quit(0 if failures.is_empty() else 1)
