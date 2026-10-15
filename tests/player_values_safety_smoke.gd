extends RefCounted

static func run(tree: SceneTree, check: Callable) -> void:
	var store := PlayerValueIntentStore.new("task1004-qa-project|player-a")
	var other := PlayerValueIntentStore.new("task1004-qa-project-b|player-a")
	var intent := {"userId": "player-a", "kind": "purchase", "offerKey": "pack", "operationId": "1760000000000:11111111-1111-4111-8111-111111111111"}
	check.call(not store.exists() and store.reserve(intent), "Persist intent before transport")
	intent.offerKey = "changed-local-payload"
	var restored := PlayerValueIntentStore.new("task1004-qa-project|player-a")
	check.call(restored.read().offerKey == "pack" and restored.read().operationId == intent.operationId, "Restart retains immutable original payload and ID")
	check.call(not other.exists(), "Project scope isolates pending actions")
	check.call(not store.reserve(intent), "Existing action cannot be replaced")
	check.call(not store.confirm("another-id") and store.exists(), "Other completion cannot clear pending action")
	var file := FileAccess.open(store.path, FileAccess.WRITE)
	file.store_var({"damaged": true}, false)
	file.close()
	check.call(store.read().is_empty() and store.exists() and not store.reserve(intent), "Damaged intent remains blocked for reconciliation")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(store.path))
	check.call(store.reserve(intent) and store.confirm(intent.operationId) and not store.exists(), "Matching completion clears exact pending action")
	var panel := preload("res://scripts/ui/player_values_demo.gd").new()
	tree.root.add_child(panel)
	await tree.process_frame
	check.call(panel._status.text.contains("Offline practice"), "Offline values panel shows guarded state")
	await panel._load()
	check.call(not panel._busy, "Offline load never starts transport")
	panel.queue_free()
	await tree.process_frame
