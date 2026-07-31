class_name BaseCharacterVisual
extends Node3D

@onready var torso: Node3D = $Model/Torso
@onready var pelvis: Node3D = $Model/Pelvis
@onready var head: Node3D = $Model/Head
@onready var left_arm: Node3D = $Model/LeftArmPivot
@onready var right_arm: Node3D = $Model/RightArmPivot
@onready var left_leg: Node3D = $Model/LeftLegPivot
@onready var right_leg: Node3D = $Model/RightLegPivot
@onready var left_foot: Node3D = $Model/LeftLegPivot/Foot
@onready var right_foot: Node3D = $Model/RightLegPivot/Foot

var _phase := 0.0
var _movement_ratio := 0.0
var _stature := 1.0
var _left_ground_offset := 0.0
var _right_ground_offset := 0.0
var _left_ground_roll := 0.0
var _right_ground_roll := 0.0
var _push_remaining := 0.0
var _kick_remaining := 0.0
var _take_remaining := 0.0
var _throw_remaining := 0.0
var _goalkeeper_remaining := 0.0
var _goalkeeper_side := 0
var _goalkeeper_level := 1


func set_stature(stature: float) -> void:
	_stature = clampf(stature, 0.8, 1.2)
	$Model.scale = Vector3(1.0, _stature, 1.0)


func update_motion(
	delta: float,
	horizontal_speed: float,
	maximum_speed: float,
	on_floor: bool
) -> void:
	_movement_ratio = clampf(
		horizontal_speed / maxf(0.01, maximum_speed),
		0.0,
		1.0
	)
	if on_floor and _movement_ratio > 0.02:
		_phase = fmod(
			_phase + delta * lerpf(5.2, 10.2, _movement_ratio),
			TAU
		)
	var grounded_weight := 1.0 if on_floor else 0.0
	var swing := sin(_phase) * lerpf(0.18, 0.72, _movement_ratio)
	var lift := maxf(0.0, sin(_phase)) * _movement_ratio
	left_arm.rotation.x = lerpf(left_arm.rotation.x, swing, delta * 14.0)
	right_arm.rotation.x = lerpf(right_arm.rotation.x, -swing, delta * 14.0)
	left_leg.rotation.x = lerpf(
		left_leg.rotation.x,
		-swing * grounded_weight,
		delta * 14.0
	)
	right_leg.rotation.x = lerpf(
		right_leg.rotation.x,
		swing * grounded_weight,
		delta * 14.0
	)
	left_foot.rotation.x = PI * 0.5 - left_leg.rotation.x * 0.42
	right_foot.rotation.x = PI * 0.5 - right_leg.rotation.x * 0.42
	left_foot.rotation.z = lerpf(
		left_foot.rotation.z,
		_left_ground_roll if on_floor else 0.0,
		delta * 12.0
	)
	right_foot.rotation.z = lerpf(
		right_foot.rotation.z,
		_right_ground_roll if on_floor else 0.0,
		delta * 12.0
	)
	var body_bob := absf(sin(_phase * 2.0)) * 0.025 * _movement_ratio
	torso.position.y = 1.17 + body_bob
	pelvis.position.y = 0.79 + body_bob * 0.55
	head.position.y = 1.59 + body_bob
	torso.rotation.z = lerpf(
		torso.rotation.z,
		-sin(_phase) * 0.035 * _movement_ratio,
		delta * 12.0
	)
	pelvis.rotation.z = lerpf(
		pelvis.rotation.z,
		sin(_phase) * 0.055 * _movement_ratio,
		delta * 12.0
	)
	if not on_floor:
		left_arm.rotation.x = lerpf(left_arm.rotation.x, -0.32, delta * 9.0)
		right_arm.rotation.x = lerpf(right_arm.rotation.x, -0.32, delta * 9.0)
		left_leg.rotation.x = lerpf(left_leg.rotation.x, 0.16, delta * 9.0)
		right_leg.rotation.x = lerpf(right_leg.rotation.x, -0.12, delta * 9.0)
	if _push_remaining > 0.0:
		_push_remaining = maxf(0.0, _push_remaining - delta)
		var push_weight := sin((_push_remaining / 0.42) * PI)
		left_arm.rotation.x = lerpf(left_arm.rotation.x, -1.28, push_weight)
		right_arm.rotation.x = lerpf(right_arm.rotation.x, -1.28, push_weight)
		torso.rotation.x = lerpf(torso.rotation.x, 0.16, push_weight)
	else:
		torso.rotation.x = lerpf(torso.rotation.x, 0.0, delta * 12.0)
	if _kick_remaining > 0.0:
		_kick_remaining = maxf(0.0, _kick_remaining - delta)
		var kick_progress := 1.0 - _kick_remaining / 0.5
		var kick_weight := sin(kick_progress * PI)
		right_leg.rotation.x = lerpf(right_leg.rotation.x, -1.05, kick_weight)
		right_foot.rotation.x = lerpf(
			right_foot.rotation.x,
			0.2,
			kick_weight
		)
		left_arm.rotation.x = lerpf(left_arm.rotation.x, 0.38, kick_weight)
		right_arm.rotation.x = lerpf(right_arm.rotation.x, -0.52, kick_weight)
		torso.rotation.x = lerpf(torso.rotation.x, 0.12, kick_weight)
	if _take_remaining > 0.0:
		_take_remaining = maxf(0.0, _take_remaining - delta)
		var take_progress := 1.0 - _take_remaining / 0.62
		var take_weight := sin(take_progress * PI)
		right_arm.rotation.x = lerpf(right_arm.rotation.x, -0.78, take_weight)
		left_arm.rotation.x = lerpf(left_arm.rotation.x, 0.22, take_weight)
		torso.rotation.x = lerpf(torso.rotation.x, 0.34, take_weight)
		torso.position.y = lerpf(torso.position.y, 1.05, take_weight)
		pelvis.position.y = lerpf(pelvis.position.y, 0.67, take_weight)
		head.position.y = lerpf(head.position.y, 1.48, take_weight)
	if _throw_remaining > 0.0:
		_throw_remaining = maxf(0.0, _throw_remaining - delta)
		var throw_progress := 1.0 - _throw_remaining / 0.62
		var throw_weight := sin(throw_progress * PI)
		var throw_angle := lerpf(
			0.72,
			-1.3,
			smoothstep(0.12, 0.78, throw_progress)
		)
		right_arm.rotation.x = lerpf(
			right_arm.rotation.x,
			throw_angle,
			throw_weight
		)
		left_arm.rotation.x = lerpf(left_arm.rotation.x, 0.5, throw_weight)
		torso.rotation.x = lerpf(torso.rotation.x, 0.18, throw_weight)
		torso.rotation.z = lerpf(torso.rotation.z, -0.12, throw_weight)
	if _goalkeeper_remaining > 0.0:
		_goalkeeper_remaining = maxf(0.0, _goalkeeper_remaining - delta)
		var dive_weight := sin((_goalkeeper_remaining / 0.72) * PI)
		left_arm.rotation.x = lerpf(left_arm.rotation.x, -1.42, dive_weight)
		right_arm.rotation.x = lerpf(right_arm.rotation.x, -1.42, dive_weight)
		left_arm.rotation.z = lerpf(
			left_arm.rotation.z,
			float(_goalkeeper_side) * -0.62,
			dive_weight
		)
		right_arm.rotation.z = lerpf(
			right_arm.rotation.z,
			float(_goalkeeper_side) * -0.62,
			dive_weight
		)
		torso.rotation.z = lerpf(
			torso.rotation.z,
			float(_goalkeeper_side) * 0.22,
			dive_weight
		)
		torso.rotation.x = lerpf(
			torso.rotation.x,
			0.28 + float(_goalkeeper_level) * 0.05,
			dive_weight
		)
	$Model/LeftLegPivot.position.y = (
		0.72
		+ _left_ground_offset * grounded_weight
		+ lift * 0.025 * grounded_weight
	)
	$Model/RightLegPivot.position.y = (
		0.72
		+ _right_ground_offset * grounded_weight
		+ maxf(0.0, -sin(_phase)) * 0.025 * _movement_ratio * grounded_weight
	)


func set_foot_contacts(
	left_height: float,
	right_height: float,
	left_normal: Vector3,
	right_normal: Vector3
) -> void:
	_left_ground_offset = clampf(left_height, -0.16, 0.16)
	_right_ground_offset = clampf(right_height, -0.16, 0.16)
	_left_ground_roll = atan2(-left_normal.x, maxf(0.01, left_normal.y))
	_right_ground_roll = atan2(-right_normal.x, maxf(0.01, right_normal.y))


func clear_foot_contacts() -> void:
	_left_ground_offset = 0.0
	_right_ground_offset = 0.0
	_left_ground_roll = 0.0
	_right_ground_roll = 0.0


func trigger_push() -> void:
	_push_remaining = 0.42


func trigger_kick() -> void:
	_kick_remaining = 0.5


func trigger_take() -> void:
	_take_remaining = 0.62


func trigger_throw() -> void:
	_throw_remaining = 0.62


func trigger_goalkeeper_dive(side: int, level: int) -> void:
	_goalkeeper_side = clampi(side, -1, 1)
	_goalkeeper_level = clampi(level, 0, 2)
	_goalkeeper_remaining = 0.72


func get_movement_ratio() -> float:
	return _movement_ratio


func get_visual_foot_height() -> float:
	return minf(
		($Model/LeftLegPivot/Foot/Sole as Marker3D).global_position.y,
		($Model/RightLegPivot/Foot/Sole as Marker3D).global_position.y
	)
