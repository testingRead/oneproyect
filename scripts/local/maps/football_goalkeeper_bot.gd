class_name FootballGoalkeeperBot
extends Node3D

var _base_position := Vector3.ZERO
var _remaining := 0.0
var _side := 0.0
var _level := 1


func _ready() -> void:
	_base_position = position


func trigger_save(target_x: float, level: int) -> void:
	_side = signf(target_x)
	if is_zero_approx(_side):
		_side = 1.0
	_level = clampi(level, 0, 2)
	_remaining = 0.72


func _process(delta: float) -> void:
	if _remaining <= 0.0:
		position = position.lerp(_base_position, minf(1.0, delta * 10.0))
		rotation.z = lerpf(rotation.z, 0.0, minf(1.0, delta * 10.0))
		return
	_remaining = maxf(0.0, _remaining - delta)
	var progress := 1.0 - _remaining / 0.72
	var weight := sin(progress * PI)
	position = _base_position + Vector3(
		_side * (0.82 + float(_level) * 0.12) * weight,
		(0.2 + float(_level) * 0.16) * weight,
		0.0
	)
	rotation.z = -_side * (0.5 + float(_level) * 0.08) * weight
