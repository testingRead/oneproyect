class_name LocalTornadoHost
extends Node

signal timer_changed(remaining: float)
signal health_changed(current: int, maximum: int)
signal player_captured
signal match_completed(survived: bool)
signal character_health_authorized(peer_id: int, health: int, impulse: Vector3, captured: bool)
signal round_completed_authorized(remaining_msec: int)

const DAMAGE_INTERVAL := 0.85
const CAPTURE_RADIUS := 2.15
const INFLUENCE_RADIUS := 8.2

var _active := false
var _complete := false
var _remaining := 48.0
var _tornado: Node3D
var _player: LocalBaseCharacter
var _object_parent: Node3D
var _path_time := 0.0
var _impact_cooldowns := {}
var _session_authority := true


func start_match(map_root: Node3D, player: LocalBaseCharacter) -> bool:
	stop_and_clean()
	_tornado = _find_descendant(map_root, &"tornado_hazard") as Node3D
	if _tornado == null or player == null:
		return false
	_player = player
	_object_parent = map_root
	if _session_authority:
		for character in get_tree().get_nodes_in_group(&"local_base_character"):
			if character is LocalBaseCharacter:
				(character as LocalBaseCharacter).reset_local_health()
	else:
		_player.reset_local_health()
	_active = true
	_complete = false
	_remaining = 48.0
	health_changed.emit(_player.get_local_health(), 100)
	return true


func _physics_process(delta: float) -> void:
	if not _active or not is_instance_valid(_tornado) or not is_instance_valid(_player):
		return
	if not _session_authority:
		_affect_local_motion(delta)
		timer_changed.emit(_remaining)
		return
	_remaining = maxf(0.0, _remaining - delta)
	_path_time += delta
	_move_tornado(delta)
	_affect_loose_objects()
	_affect_characters(delta)
	timer_changed.emit(_remaining)
	if _remaining <= 0.0 or _all_characters_eliminated():
		_complete = true
		_active = false
		match_completed.emit(_player.get_local_health() > 0)
		round_completed_authorized.emit(roundi(_remaining * 1000.0))


func is_complete() -> bool:
	return _complete


func is_active() -> bool:
	return _active and is_instance_valid(_tornado)


func get_winner() -> int:
	return 1 if is_instance_valid(_player) and _player.get_local_health() > 0 else -1


func get_remaining() -> float:
	return _remaining


func finish_match() -> void:
	if not _active:
		return
	_active = false
	match_completed.emit(_player.get_local_health() > 0)
	if _session_authority:
		_complete = true
		round_completed_authorized.emit(roundi(_remaining * 1000.0))


func stop_and_clean() -> void:
	_active = false
	_complete = false
	_tornado = null
	_player = null
	_object_parent = null
	_impact_cooldowns.clear()


func set_session_authority(enabled: bool) -> void:
	_session_authority = enabled


func get_hazard_position() -> Vector3:
	return _tornado.global_position if is_instance_valid(_tornado) else Vector3.ZERO


func apply_authoritative_state(position_value: Vector3, remaining: float) -> void:
	if not is_instance_valid(_tornado):
		return
	_tornado.global_position = _tornado.global_position.lerp(position_value, 0.72)
	_remaining = maxf(0.0, remaining)


func apply_authoritative_completion(remaining_msec: int) -> void:
	_remaining = maxf(0.0, float(remaining_msec) / 1000.0)
	_active = false
	_complete = true
	match_completed.emit(is_instance_valid(_player) and _player.get_local_health() > 0)


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
		_apply_object_impact_damage(body)


func _affect_characters(delta: float) -> void:
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
		# Tornado suction is a continuous force, not a new full impulse every
		# physics frame. The horizontal cap prevents velocity from accumulating
		# against a wall and leaving the player apparently stunned afterwards.
		target.apply_external_force(
			launch,
			lerpf(7.0, 24.0, closeness),
			delta,
			5.2,
			2.8
		)
		if distance < CAPTURE_RADIUS and _can_damage(
			"tornado:%d" % target.get_instance_id(),
			roundi(DAMAGE_INTERVAL * 1000.0)
		):
			target.apply_local_damage(12)
			_emit_authoritative_damage(target, launch * lerpf(1.5, 9.2, closeness), true)
		_apply_character_impact_damage(target)


func _affect_local_motion(delta: float) -> void:
	var offset := _tornado.global_position - _player.global_position
	var distance := offset.length()
	if distance > INFLUENCE_RADIUS or distance < 0.05:
		return
	var closeness := 1.0 - distance / INFLUENCE_RADIUS
	var tangent := Vector3(-offset.z, 0.0, offset.x).normalized()
	var launch := (
		offset.normalized() * 0.7 + tangent * 0.72 + Vector3.UP * 0.36
	).normalized()
	_player.apply_external_force(
		launch,
		lerpf(7.0, 24.0, closeness),
		delta,
		5.2,
		2.8
	)


func _apply_object_impact_damage(body: RigidBody3D) -> void:
	var speed := body.linear_velocity.length()
	if speed < 4.0:
		return
	for character in get_tree().get_nodes_in_group(&"local_base_character"):
		if not character is LocalBaseCharacter:
			continue
		var target := character as LocalBaseCharacter
		if body.global_position.distance_to(target.global_position) > 1.0:
			continue
		var key := "object:%d:%d" % [body.get_instance_id(), target.get_instance_id()]
		if not _can_damage(key):
			continue
		var damage := clampi(roundi(speed * 0.9), 5, 18)
		target.apply_local_damage(damage)
		target.apply_external_push(body.linear_velocity.normalized() + Vector3.UP * 0.16, minf(8.0, speed))
		_emit_authoritative_damage(
			target,
			body.linear_velocity.normalized() * minf(8.0, speed),
			false
		)


func _apply_character_impact_damage(source: LocalBaseCharacter) -> void:
	var speed := source.velocity.length()
	if speed < 5.5:
		return
	for character in get_tree().get_nodes_in_group(&"local_base_character"):
		if character == source or not character is LocalBaseCharacter:
			continue
		var target := character as LocalBaseCharacter
		if source.global_position.distance_to(target.global_position) > 1.05:
			continue
		var key := "player:%d:%d" % [source.get_instance_id(), target.get_instance_id()]
		if not _can_damage(key):
			continue
		var damage := clampi(roundi(speed * 0.7), 4, 14)
		target.apply_local_damage(damage)
		target.apply_external_push(source.velocity.normalized() + Vector3.UP * 0.12, speed * 0.55)
		_emit_authoritative_damage(
			target,
			(source.velocity.normalized() + Vector3.UP * 0.12).normalized() * speed * 0.55,
			false
		)


func _can_damage(key: String, cooldown_msec := 600) -> bool:
	var now := Time.get_ticks_msec()
	var next_allowed := int(_impact_cooldowns.get(key, 0))
	if now < next_allowed:
		return false
	_impact_cooldowns[key] = now + cooldown_msec
	return true


func _emit_authoritative_damage(
	target: LocalBaseCharacter,
	impulse: Vector3,
	captured: bool
) -> void:
	if target == _player:
		health_changed.emit(target.get_local_health(), 100)
		if captured:
			player_captured.emit()
	character_health_authorized.emit(
		int(target.get_meta(&"lan_peer_id", 1)),
		target.get_local_health(),
		impulse,
		captured
	)


func _all_characters_eliminated() -> bool:
	var found := false
	for character in get_tree().get_nodes_in_group(&"local_base_character"):
		if character is LocalBaseCharacter:
			found = true
			if (character as LocalBaseCharacter).get_local_health() > 0:
				return false
	return found


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
