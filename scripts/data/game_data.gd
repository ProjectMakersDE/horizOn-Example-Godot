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
	d.coins = maxi(int(data.get("coins", 0)), 0)
	d.highscore = int(data.get("highscore", 0))
	var u = data.get("upgrades", {})
	if u is Dictionary:
		for key in d.upgrades:
			d.upgrades[key] = clampi(int(u.get(key, 0)), 0, 5)
	d.totalRuns = int(data.get("totalRuns", 0))
	var codes = data.get("giftCodesRedeemed", [])
	if codes is Array:
		d.giftCodesRedeemed = codes.duplicate()
	return d
