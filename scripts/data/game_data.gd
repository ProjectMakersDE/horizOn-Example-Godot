## Persistent save data (synced with cloud save)
class_name GameData
extends RefCounted

var coins: int = 0
var highscore: int = 0
var upgrades: Dictionary = {"speed": 0, "damage": 0, "hp": 0, "magnet": 0}
var totalRuns: int = 0
var giftCodesRedeemed: Array = []


func to_dict() -> Dictionary:
	return {
		"coins": coins,
		"highscore": highscore,
		"upgrades": upgrades.duplicate(),
		"totalRuns": totalRuns,
		"giftCodesRedeemed": giftCodesRedeemed.duplicate()
	}


static func from_dict(data: Dictionary) -> GameData:
	var d := GameData.new()
	d.coins = int(data.get("coins", 0))
	d.highscore = int(data.get("highscore", 0))
	var u = data.get("upgrades", {})
	if u is Dictionary:
		for key in u:
			d.upgrades[key] = int(u[key])
	d.totalRuns = int(data.get("totalRuns", 0))
	var codes = data.get("giftCodesRedeemed", [])
	if codes is Array:
		d.giftCodesRedeemed = codes.duplicate()
	return d
