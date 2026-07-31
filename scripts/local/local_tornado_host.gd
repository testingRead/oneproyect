class_name LocalTornadoHost
extends Node

signal timer_changed(remaining: float)
signal health_changed(current: int, maximum: int)
signal player_captured
signal match_completed(survived: bool)

const DAMAGE_INTERVAL := 0.85
const CAPTURE_RADIUS := 2.15
const INFLUENCE_RADIUS := 8.2

var _active := false
var _complete := false
var _remaining := 48.0
var _tornado: Node3D
var _player: LocalBaseCharacter
var _object_parent: Node3D
var _damage_cooldown := 0.0
var _path_time := 0.0


func start_match(map_root: Node3D, player: LocalBaseCharacter) -> bool:
	stop_and_clean()
	_tornado = _find_descendant(map_root, &"tornado_hazard") as Node3D
	if _tornado == null or player == null:
		return false
	_player = player
	_object_parent = map_root
	_player.reset_local_health()
	_active = true
	_complete = false
	_remaining = 48.0
	health_changed.emit(_player.get_local_health(), 100)
	return true


func _physics_process(delta: float) -> void:
	if not _active or not is_instance_valid(_tornado) or not is_instance_valid(_player):
		return
	_remaining = maxf(0.0, _remaining - delta)
	_path_time += delta
	_move_tornado(delta)
	_affect_loose_objects()
	_affect_characters(delta)
	timer_changed.emit(_remaining)
	if _player.get_local_health() <= 0 or _remaining <= 0.0:
		_complete = true
		_active = false
		match_completed.emit(_player.get_local_health() > 0)


func is_complete() -> bool:
	return _complete


func get_winner() -> int:
	return 1 if is_instance_valid(_player) and _player.get_local_health() > 0 else -1


func get_remaining() -> float:
	return _remaining


func finish_match() -> void:
	if not _active:
		return
	_active = false
	match_completed.emit(_player.get_local_health() > 0)


func stop_and_clean() -> void:
	_active = false
	_complete = false
	_tornado = null
	_player = null
	_object_parent = null
	_damage_cooldown = 0.0


func _move_tornado(delta: float) -> void:
	var centre := Vector3(sin(_path_time * 0.42) * 8.5, 0.0, -20.0 + cos(_path_time * 0.31) * 8.5)
	_tornado.global_position = _tornado.global_position.lerp(centre, minf(1.0, delta * 1.3))
	_tornado.rotate_y(delta * 4.4)


func _affect_loose_objects() -> void:
	for object in get_tree().get_nodes_in_group(&"tornado_loose_object"):
		if not object is RigidBody3D or not _object_parent.is_ancestor_of(object):
			continue
		var body := object as RigidBody3D
		var offset := _tornado.global_position - body.global_position
		var distance := offset.length()
		if distance > INFLUENCE_RADIUS or distance < 0.05:
			continue
		var pull := offset.normalized() * (1.0 - distance / INFLUENCE_RADIUS) * 17.0
		var tangent := Vector3(-offset.z, 0.0, offset.x).normalized() * 9.5
		body.apply_central_force(pull + tangent + Vector3.UP * 7.0)


func _affect_characters(delta: float) -> void:
	_damage_cooldown = maxf(0.0, _damage_cooldown - delta)
	for character in get_tree().get_nodes_in_group(&"local_base_character"):
		if not character is LocalBaseCharacter:
			continue
		var target := character as LocalBaseCharacter
		var offset := _tornado.global_position - target.global_position
		var distance := offset.length()
		if distance > INFLUENCE_RADIUS or distance < 0.05:
			continue
		var closeness := 1.0 - distance / INFLUENCE_RADIUS
		var tangent := Vector3(-offset.z, 0.0, offset.x).normalized()
		var launch := (offset.normalized() * 0.7 + tangent * 0.72 + Vector3.UP * 0.36).normalized()
		target.apply_external_push(launch, lerpf(1.5, 9.2, closeness))
		if target == _player and distance < CAPTURE_RADIUS and _damage_cooldown <= 0.0:
			_damage_cooldown = DAMAGE_INTERVAL
			target.apply_local_damage(12)
			health_changed.emit(target.get_local_health(), 100)
			player_captured.emit()


func _find_descendant(root: Node, group: StringName) -> Node:
	if root == null:
		return null
	if root.is_in_group(group):
		return root
	for child in root.get_children():
		var found := _find_descendant(child, group)
		if found != null:
			return found
	return null
