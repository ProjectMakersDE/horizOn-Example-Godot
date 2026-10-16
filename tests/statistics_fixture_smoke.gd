extends RefCounted

static func run(tree: SceneTree, check: Callable) -> void:
	var horizon = tree.root.get_node("Horizon")
	var panel := preload("res://scripts/ui/statistics_demo.gd").new()
	tree.root.add_child(panel)
	await tree.process_frame
	var store := StatisticsRunStore.new(horizon.getConfig().api_key, horizon.getCurrentUser().userId)
	check.call(store.queue_run(4294967296, 9007199254740990) and store.queue_run(3, 250), "Completed sessions form one local aggregate")
	await panel._report()
	var saved := store.read()
	check.call(not saved.pending.is_empty(), "Booked but lost response keeps original batch")
	var operation: String = saved.pending.operationId
	check.call(store.queue_run(2, 100), "Later completed run remains queued while first batch is unknown")
	await panel._report()
	check.call(store.read().pending.operationId == operation, "New report never replaces an unknown batch")
	var original_host: String = horizon._http.activeHost
	horizon._http.activeHost = "http://regional-failover.example.invalid"
	check.call(panel._store().read().pending.operationId == operation, "Regional host change keeps original owner and ID")
	horizon._http.activeHost = original_host
	for attempt in range(3):
		if store.read().pending.is_empty(): break
		await panel._retry()
	check.call(store.read().pending.is_empty() and store.read().rounds == 1, "Replay confirms first batch while preserving queued run")
	check.call(panel._output.text.contains("4294967299") and panel._output.text.contains("9007199254740990"), "Snapshot displays exact safe int64 values")
	await panel._report()
	check.call(store.read().pending.is_empty() and store.read().rounds == 0 and panel._output.text.contains("rounds: 3"), "Second explicit batch reports only later queued run")
	panel.queue_free()
	await tree.process_frame
