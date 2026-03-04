## Upgrade Pool - Weighted random selection for levelup choices
extends Node


func get_choices(owned_weapons: Array, count: int) -> Array:
	var pool := ConfigCache.get_levelup_pool()
	if pool.is_empty():
		pool = _get_default_pool()

	# Filter out already-owned weapon_new choices
	var available: Array = []
	for item in pool:
		if item.get("type", "") == "weapon_new":
			var weapon_id: String = item.get("weapon_id", "")
			if weapon_id in owned_weapons:
				continue
		available.append(item)

	return _weighted_random_select(available, count)


func apply_choice(choice: Dictionary, run_state: RunState) -> void:
	var type: String = choice.get("type", "")
	match type:
		"weapon_upgrade":
			pass  # Handled by caller
		"weapon_new":
			var weapon_id: String = choice.get("weapon_id", "")
			if not weapon_id.is_empty():
				run_state.activeWeapons.append(weapon_id)
		"stat_boost":
			pass  # Handled by caller


func _weighted_random_select(pool: Array, count: int) -> Array:
	var result: Array = []
	var remaining := pool.duplicate(true)
	for i in mini(count, remaining.size()):
		var total_weight: float = 0.0
		for item in remaining:
			total_weight += float(item.get("weight", 1))
		if total_weight <= 0:
			break
		var roll := randf() * total_weight
		var cumulative: float = 0.0
		for j in remaining.size():
			cumulative += float(remaining[j].get("weight", 1))
			if roll <= cumulative:
				result.append(remaining[j])
				remaining.remove_at(j)
				break
	return result


func _get_default_pool() -> Array:
	return [
		{"id": "feather_dmg", "type": "weapon_upgrade", "weight": 3},
		{"id": "screech_new", "type": "weapon_new", "weapon_id": "seagull_screech", "weight": 2},
		{"id": "dive_new", "type": "weapon_new", "weapon_id": "dive_bomb", "weight": 2},
		{"id": "gust_new", "type": "weapon_new", "weapon_id": "wind_gust", "weight": 2},
		{"id": "move_speed", "type": "stat_boost", "weight": 2},
		{"id": "max_hp", "type": "stat_boost", "weight": 2},
		{"id": "xp_magnet", "type": "stat_boost", "weight": 1},
	]
