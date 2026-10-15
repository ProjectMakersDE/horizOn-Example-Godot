## Shared full-canvas cutout parts, posed around the accepted mockup pivots.
extends Node2D

signal animation_finished

const ASSET_ROOT := "res://assets/shared/cutout/"
const ATTACK_DURATION := 0.58
const HURT_DURATION := 0.32
const DEATH_DURATION := 0.25
static var _rig_data: Dictionary = {}

var parts: Dictionary = {}
var motion_state: String = "idle"
var facing: int = 1
var elapsed: float = 0.0
var _character: String
var _moving := false
var _action_elapsed := 0.0
var _action_remaining := 0.0
var _dead := false
var _pose: Node2D
var _mirror: Node2D
var _origins: Dictionary = {}
var _base_facing := 1
var _shadow: Sprite2D
var _pose_origin: Vector2


func setup(character: String, display_width: float) -> void:
	_character = character
	if _rig_data.is_empty():
		_rig_data = JSON.parse_string(FileAccess.get_file_as_string(ASSET_ROOT + "rig.json"))
	var definition: Dictionary = _rig_data["characters"][character]
	var canvas := _point(definition["canvas"])
	var origin := _point(definition["actorOrigin"])
	var pivot := _point(definition["rootPivot"])
	_base_facing = int(definition["baseFacing"])
	scale = Vector2.ONE * (display_width / canvas.x)
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	texture_repeat = CanvasItem.TEXTURE_REPEAT_DISABLED
	# The contact shadow stays at the original actor anchor while the pose hops.
	_shadow = Sprite2D.new()
	_shadow.texture = load(ASSET_ROOT + str(_rig_data["shadow"]["file"]))
	_shadow.position = _point(definition["feetAnchor"]) - origin
	_shadow.scale = Vector2(1.15, 0.88) if character == "gull" else Vector2(1.11, 0.63)
	add_child(_shadow)
	_mirror = Node2D.new()
	_mirror.scale.x = _base_facing
	add_child(_mirror)
	_pose = Node2D.new()
	_pose_origin = pivot - origin
	_pose.position = _pose_origin
	_mirror.add_child(_pose)
	for part_definition: Dictionary in definition["parts"]:
		var part_name: String = part_definition["name"]
		var part_pivot := _point(part_definition["pivot"])
		var joint := Node2D.new()
		joint.name = part_name
		joint.position = part_pivot - pivot
		# The manifest is in draw order. Shared z0 keeps each actor's parts
		# together when two actors overlap instead of interleaving their limbs.
		_pose.add_child(joint)
		var sprite := Sprite2D.new()
		sprite.texture = load(ASSET_ROOT + str(part_definition["file"]))
		sprite.centered = false
		sprite.position = -part_pivot
		joint.add_child(sprite)
		parts[part_name] = joint
		_origins[part_name] = joint.position
	_apply_pose()


func set_locomotion(moving: bool, direction_x: float) -> void:
	_moving = moving
	if not is_zero_approx(direction_x):
		facing = -1 if direction_x < 0 else 1
		_mirror.scale.x = float(facing * _base_facing)
	if _action_remaining <= 0.0 and not _dead:
		motion_state = "walk" if moving else "idle"


func trigger_attack() -> void:
	if _dead or motion_state == "hurt":
		return
	_start_action("attack", ATTACK_DURATION)


func trigger_hurt() -> void:
	if not _dead:
		_start_action("hurt", HURT_DURATION)


func die() -> void:
	if _dead:
		return
	_dead = true
	_start_action("death", DEATH_DURATION)


func _start_action(state: String, duration: float) -> void:
	motion_state = state
	_action_elapsed = 0.0
	_action_remaining = duration


func _process(delta: float) -> void:
	if _pose == null:
		return
	elapsed += delta
	if _action_remaining > 0.0:
		_action_elapsed += delta
		_action_remaining = maxf(_action_remaining - delta, 0.0)
		if _action_remaining <= 0.0:
			if _dead:
				set_process(false)
				animation_finished.emit()
				return
			motion_state = "walk" if _moving else "idle"
	_apply_pose()


func _apply_pose() -> void:
	# Weapons fire while the actor moves. Keep the gait clock running under
	# their upper-body action so repeated attacks cannot freeze the feet.
	var walking := _moving and motion_state in ["walk", "attack"]
	var attacking := motion_state == "attack"
	var hurting := motion_state == "hurt"
	var phase := _action_elapsed if attacking or hurting else elapsed
	var pulse := pow(maxf(0.0, sin(phase * 5.0)), 2.0) if attacking else 0.0
	var step := sin(elapsed * (8.0 if _character == "gull" else 10.0)) if walking else 0.0
	for part_name: String in parts:
		parts[part_name].rotation = 0.0
		parts[part_name].position = _origins[part_name]
	_pose.position = _pose_origin
	_pose.position.y += -absf(step) * (7.0 if _character == "gull" else 4.0) if walking else sin(phase * 2.0) * (1.6 if _character == "gull" else 1.8)
	modulate = Color(1.0, 0.65, 0.55) if hurting else Color.WHITE
	if _character == "gull":
		_pose.rotation = sin(phase * 19.0) * 0.085 if hurting else step * 0.018
		var rear := -0.53 * pulse if attacking else sin(phase * 8.0 + 0.4) * 0.15 if walking else sin(phase * 2.0) * 0.035
		parts["tail"].rotation = -rear * 0.35
		parts["backWing"].rotation = rear
		parts["leftFoot"].rotation = step * 0.16
		parts["leftFoot"].position += Vector2(-step * 5.0, -maxf(step, 0.0) * 4.0)
		parts["rightFoot"].rotation = -step * 0.16
		parts["rightFoot"].position += Vector2(step * 5.0, -maxf(-step, 0.0) * 4.0)
		parts["frontWing"].rotation = 0.57 * pulse if attacking else -sin(phase * 8.0 + 0.4) * 0.16 if walking else sin(phase * 2.0 + 1.0) * 0.025
		parts["head"].rotation = -0.10 if hurting else -step * 0.018 if walking else sin(phase * 2.0) * 0.014
		parts["head"].position += Vector2(pulse * 3.0, -pulse * 4.0)
	else:
		_pose.rotation = sin(phase * 21.0) * 0.09 if hurting else step * 0.015
		var legs := ["leftBack", "rightBack", "leftMiddle", "rightMiddle", "leftFront", "rightFront"]
		for index in legs.size():
			parts[legs[index]].rotation = step * (1.0 if index % 2 else -1.0) * (0.09 + float(index % 3) * 0.035)
		parts["backClaw"].rotation = -0.35 * pulse if attacking else sin(phase * 2.0) * 0.05
		parts["frontClaw"].rotation = 0.33 * pulse if attacking else sin(phase * 2.0 + 1.0) * 0.04
		parts["frontClaw"].position += Vector2(-pulse * 6.0, -pulse * 4.0)
	if _dead:
		_pose.rotation = 0.32 * (_action_elapsed / DEATH_DURATION)
		modulate.a = 1.0 - _action_elapsed / DEATH_DURATION


func _point(value: Array) -> Vector2:
	return Vector2(float(value[0]), float(value[1]))
