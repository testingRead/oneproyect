class_name LocalMovingPlatform
extends AnimatableBody3D

@export var travel := Vector3(0.0, 0.0, 5.0)
@export var cycle_seconds := 4.0

var _origin := Vector3.ZERO
var _elapsed := 0.0


func _ready() -> void:
	_origin = position


func _physics_process(delta: float) -> void:
	_elapsed = fmod(_elapsed + delta, maxf(0.5, cycle_seconds))
	var phase := _elapsed / maxf(0.5, cycle_seconds)
	var weight := (sin(phase * TAU - PI * 0.5) + 1.0) * 0.5
	position = _origin + travel * weight


func reset_platform() -> void:
	_elapsed = 0.0
	position = _origin
