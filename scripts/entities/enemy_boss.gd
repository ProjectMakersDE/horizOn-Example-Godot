## Enemy Boss - Large, high HP, spawns at final wave
## Has faster attack cooldown and periodic charge attacks.
extends EnemyBase

var _base_speed: float = 0.0
var _charge_speed_mult: float = 2.5
var _is_charging: bool = false
var _charge_timer: float = 0.0
var _charge_duration: float = 0.4
var _charge_cooldown: float = 2.0
var _charge_cd_timer: float = 0.0


func _ready() -> void:
	# Boss attacks faster than normal enemies
	_attack_cooldown = 0.5


func _get_enemy_type() -> String:
	return "boss"


func _on_special_behavior(delta: float) -> void:
	if _base_speed == 0.0:
		_base_speed = speed

	if _is_charging:
		_charge_timer += delta
		speed = _base_speed * _charge_speed_mult
		if _charge_timer >= _charge_duration:
			_is_charging = false
			speed = _base_speed
			_charge_cd_timer = 0.0
	else:
		_charge_cd_timer += delta
		if _charge_cd_timer >= _charge_cooldown:
			_is_charging = true
			_charge_timer = 0.0
