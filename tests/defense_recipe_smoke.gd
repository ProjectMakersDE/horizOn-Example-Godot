extends SceneTree
const Recipe = preload("res://scripts/recipes/defense_recipe.gd")
var failures: int = 0
func check(condition: bool, message: String) -> void:
	if not condition: failures += 1; push_error(message)
func _initialize() -> void:
	call_deferred("_run")
func _run() -> void:
	var won: Dictionary = Recipe.simulate(7, {"version": 1, "hp": 1, "power": 3}, [0])
	check(won.attackerWon and won.score == 1201, "Independent Python/native one-turn win golden")
	var lost: Dictionary = Recipe.simulate(0, {"version": 1, "hp": 1000, "power": 1000}, [0])
	check(not lost.attackerWon and lost.score == 5, "Independent Python/native one-turn loss golden")
	check(Recipe.simulate(7, {"version": 1, "hp": 1, "power": 3}, [0, 0]).is_empty(), "No input after game end")
	check(Recipe.simulate(7, {"version": 1, "hp": 15, "power": 3}, []).is_empty(), "No fabricated empty win")
	check(not Recipe.game_parameters({"version": 1, "hp": 15, "power": 3, "win": true}), "Client winner field rejected")
	var recipe: Node = Recipe.new(); root.add_child(recipe)
	await process_frame
	check((await recipe.start_reviewed_defense()).get("errorCode") == "SESSION_REQUIRED", "No startup session or run")
	check((await recipe.submit_finished_defense()).get("errorCode") == "SESSION_REQUIRED", "No client-authoritative submit")
	var panel: Node = preload("res://scripts/ui/defense_recipe_panel.gd").new(); root.add_child(panel)
	await process_frame
	check(panel.get_child_count() > 10, "Actual explicit Worldmap/PvP UI constructs offline")
	panel.queue_free(); recipe.queue_free()
	if failures == 0: print("DEFENSE_RECIPE_OFFLINE_PASS")
	quit(0 if failures == 0 else 1)
