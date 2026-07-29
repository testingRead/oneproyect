class_name FloodHazard
extends Node3D

const START_HEIGHT := -0.38
const END_HEIGHT := 1.58

var _active := false
var _damage_cooldown := 0.0


func _ready() -> void:
	visible = false
	position.y = START_HEIGHT


func _physics_process(delta: float) -> void:
	if not _active:
		return
	_damage_cooldown = maxf(0.0, _damage_cooldown - delta)
	if _damage_cooldown > 0.0:
		return
	for node in get_tree().get_nodes_in_group("players"):
		var player := node as GrayboxPlayer
		if player != null and player.global_position.y < global_position.y + 0.82:
			player.apply_hazard_damage(12, 3.2)
			_damage_cooldown = 0.9


func sync_active(time_left: float, duration: float) -> void:
	_active = true
	visible = true
	var progress := 1.0 - clampf(time_left / duration, 0.0, 1.0)
	position.y = lerpf(START_HEIGHT, END_HEIGHT, pow(progress, 1.15))


func stop() -> void:
	_active = false
	visible = false
	_damage_cooldown = 0.0
	position.y = START_HEIGHT


func is_active() -> bool:
	return _active
