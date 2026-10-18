extends SceneTree
func _initialize() -> void:
	call_deferred("_run")
func _run() -> void:
	for name: String in ["groups", "items", "matches", "shared_objects"]:
		var script: Script = load("res://examples/public_feature_guides/" + name + ".gd")
		if script == null or not script.can_instantiate():
			push_error("Complete public guide failed native compilation: " + name)
			quit(1); return
		var node: Node = script.new()
		node.free()
	root.get_node("AudioManager").shutdown()
	await process_frame
	print("PUBLIC_FEATURE_GUIDES_PASS: four unchanged complete Groups/Items/Matches/Shared source files compiled without invoking network actions")
	quit(0)
