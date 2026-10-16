extends RefCounted

static func run(tree: SceneTree, check: Callable) -> void:
	var store := StatisticsRunStore.new("qa-project", "qa-player", "safety")
	check.call(store.queue_run(4294967296, 9007199254740990), "Statistics persist int64 run counters before transport")
	var restored := StatisticsRunStore.new("qa-project", "qa-player", "safety")
	check.call(restored.read().kills == 4294967296, "Restart preserves exact integers")
	check.call(StatisticsRunStore.new("another-project", "qa-player", "safety").path != store.path, "Project isolates statistics owner")
	check.call(StatisticsRunStore.new("qa-project", "another-player", "safety").path != store.path, "Player isolates statistics owner")
	check.call(StatisticsRunStore.new("qa-project", "qa-player", "hello").path != store.path, "Hello queue stays separate from game")
	var definitions: Array = [{"key": "rounds", "mode": "sum", "resetRule": "none"}, {"key": "kills", "mode": "sum", "resetRule": "none"}, {"key": "best_score", "mode": "max", "resetRule": "none"}]
	var operation := "1760000000000:11111111-1111-4111-8111-111111111111"
	var lock_path := ProjectSettings.globalize_path(store.path + ".lock")
	check.call(DirAccess.make_dir_absolute(lock_path) == OK, "Competing process owns queue lock")
	check.call(not store.reserve(operation, definitions) and not store.queue_run(1, 1), "Concurrent owner prevents replacing an unknown read-modify-write")
	DirAccess.remove_absolute(lock_path)
	check.call(store.reserve(operation, definitions), "Reserve moves aggregate to one immutable original batch")
	check.call(store.queue_run(2, 50) and not store.reserve(operation + "x", definitions), "New runs wait behind uncertain original intent")
	var pending: Dictionary = store.read().pending
	pending.updates[0].value = 999
	check.call(store.read().pending.updates[0].value == 1, "Local mutations cannot change persisted original batch")
	check.call(not store.confirm("other-id"), "Wrong completion cannot release pending batch")
	check.call(store.confirm(operation) and store.read().rounds == 1 and store.read().kills == 2, "Confirm preserves later aggregate")
	definitions[0].mode = "last"
	check.call(not store.reserve(operation, definitions), "Unexpected Dashboard mode refuses new intent")
	var file := FileAccess.open(store.path, FileAccess.WRITE)
	file.store_var({"damaged": true}, false)
	file.close()
	check.call(store.read().is_empty() and not store.queue_run(1, 2), "Corrupt queue is retained and cannot be replaced")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(store.path))
	file = FileAccess.open(store.path + ".next", FileAccess.WRITE)
	file.store_var({"interrupted": true}, false)
	file.close()
	check.call(store.read().is_empty() and not store.queue_run(1, 2), "Interrupted write remains blocked for reconciliation")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(store.path + ".next"))
	var panel := preload("res://scripts/ui/statistics_demo.gd").new()
	tree.root.add_child(panel)
	await tree.process_frame
	check.call(not await panel._load() and not panel._busy, "Practice statistics panel never starts transport")
	panel.queue_free()
	await tree.process_frame
	var hello = load("res://examples/hello_statistics/hello_statistics.tscn").instantiate()
	tree.root.add_child(hello)
	await tree.process_frame
	hello._complete()
	check.call(hello._status.text.contains("No request"), "Standalone Hello stays offline until explicit connect")
	hello.queue_free()
	await tree.process_frame
