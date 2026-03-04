## Per-run state (RAM only, not persisted)
class_name RunState
extends RefCounted

var currentScore: int = 0
var currentWave: int = 0
var currentLevel: int = 1
var timeRemaining: float = 180.0
var playerHP: int = 100
var playerMaxHP: int = 100
var activeWeapons: Array = ["feather_throw"]
var kills: int = 0
var xpCollected: int = 0
var duration: float = 0.0
var coinsEarned: int = 0
