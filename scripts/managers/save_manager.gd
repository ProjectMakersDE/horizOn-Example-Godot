## Save Manager - Handles cloud save load/save via horizOn SDK
extends Node


func save_game() -> bool:
	if not Horizon.isSignedIn():
		return false
	var data := GameManager.to_save_data()
	var json := JSON.stringify(data)
	return await Horizon.cloudSave.saveData(json)


func load_game() -> bool:
	if not Horizon.isSignedIn():
		return false
	var json := await Horizon.cloudSave.loadData()
	if json.is_empty():
		return false
	var parsed = JSON.parse_string(json)
	if parsed is Dictionary:
		GameManager.from_save_data(parsed)
		return true
	return false
