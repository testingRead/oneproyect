class_name LocalEliminationBallHost
extends Node

const CHARACTER_SCENE := preload("res://scenes/local/base_character.tscn")

signal ball_holder_changed(holder_name: String)
signal ball_holder_peer_changed(peer_id: int)
signal player_eliminated(peer_id: int, attacker_peer_id: int, position: Vector3)
signal classification_changed(home_alive: int, away_alive: int, complete: bool)
signal match_completed(home_alive: int, away_alive: int)

const THROW_SPEED := 7.4
const THROW_LIFT := 0.34
const PICKUP_COOLDOWN := 0.34
const THROWER_GRACE := 0.28
const HIT_SPEED := 3.0
const DEFAULT_BOUNDS := AABB(Vector3(-13.4, 0.15, -35.4), Vector3(26.8, 4.0, 30.8))

var _active := false
var _complete := false
var _session_authority := true
var _ball: RigidBody3D
var _ball_parent: Node
var _ball_spawn := Transform3D.IDENTITY
var _ball_bounds := DEFAULT_BOUNDS
var _holder: LocalBaseCharacter
var _local_player: LocalBaseCharacter
var _map_root: Node3D
var _participants: Array[LocalBaseCharacter] = []
var _eliminated: Dictionary = {}
var _pickup_cooldown := 0.0
var _thrower_peer_id := 0
var _thrower_grace := 0.0
var _practice_bot: LocalBaseCharacter
var _bot_throw_delay := 0.0


func start_match(map_root: Node3D, player: LocalBaseCharacter) -> bool:
	stop_and_clean()
	_ball = _find_descendant(map_root, &"elimination_ball") as RigidBody3D
	if _ball == null or player == null:
		return false
	_map_root = map_root
	_local_player = player
	_ball_parent = _ball.get_parent()
	_ball_spawn = _ball.global_transform
	_ball_bounds = map_root.call("get_ball_bounds") if map_root.has_method("get_ball_bounds") else DEFAULT_BOUNDS
	if get_tree().get_nodes_in_group(&"local_base_character").size() <= 1:
		_spawn_practice_bot()
	for candidate in get_tree().get_nodes_in_group(&"local_base_character"):
		if candidate is LocalBaseCharacter:
			var character := candidate as LocalBaseCharacter
			_configure_character(character)
			character.reset_local_health()
			_participants.append(character)
	_active = true
	_complete = false
	_pickup_cooldown = 0.4
	_thrower_peer_id = 0
	_thrower_grace = 0.0
	ball_holder_changed.emit("NADIE")
	_emit_classification()
	return true


func _physics_process(delta: float) -> void:
	if not _active or not is_instance_valid(_ball):
		return
	_pickup_cooldown = maxf(0.0, _pickup_cooldown - delta)
	_thrower_grace = maxf(0.0, _thrower_grace - delta)
	_update_practice_bot(delta)
	if is_instance_valid(_holder):
		_follow_holder()
		return
	if not _session_authority:
		return
	if not _inside_bounds():
		_reset_ball()
		return
	if _ball.linear_velocity.length() >= HIT_SPEED:
		for character in _participants:
			if _can_hit(character):
				_eliminate(character)
				return
	if _pickup_cooldown <= 0.0 and _ball.linear_velocity.length() < 2.2:
		for character in _participants:
			if _can_collect(character):
				_assign_holder(character)
				return


func request_throw(character: LocalBaseCharacter, aim_direction: Vector3) -> bool:
	if not _active or character != _holder or not is_instance_valid(_ball):
		return false
	var direction := Vector3(aim_direction.x, 0.0, aim_direction.z)
	if direction.length_squared() < 0.01:
		direction = character.get_facing_direction()
	direction = direction.normalized()
	character.set_facing_direction(direction)
	character.visual_root.trigger_ball_shot()
	_thrower_peer_id = _peer_id(character)
	_thrower_grace = THROWER_GRACE
	var target_velocity := direction * THROW_SPEED + Vector3.UP * THROW_LIFT
	_release_ball(target_velocity * _ball.mass, direction)
	return true


func set_session_authority(enabled: bool) -> void:
	_session_authority = enabled


func apply_authoritative_holder(character: LocalBaseCharacter) -> void:
	if is_instance_valid(character):
		_assign_holder(character, false)
	else:
		_clear_holder(false)


func apply_authoritative_elimination(peer_id: int, position_value: Vector3) -> void:
	var character := _character_for_peer(peer_id)
	if not is_instance_valid(character):
		return
	_eliminated[peer_id] = true
	character.set_authoritative_health(0)
	character.controls_enabled = false
	character.global_position = position_value
	if character == _holder:
		_clear_holder(false)
	if get_home_alive() == 0 or get_away_alive() == 0:
		_complete = true
		_active = false
	_emit_classification()


func finish_match() -> void:
	if not _active:
		return
	_active = false
	match_completed.emit(get_home_alive(), get_away_alive())


func stop_and_clean() -> void:
	_active = false
	_complete = false
	if is_instance_valid(_ball) and is_instance_valid(_ball_parent):
		_ball.reparent(_ball_parent, true)
		_ball.freeze = false
		_ball.collision_layer = 1
		_ball.collision_mask = 1
	for character in _participants:
		if is_instance_valid(character):
			character.controls_enabled = character == _local_player
			character.reset_local_health()
	if is_instance_valid(_practice_bot):
		_practice_bot.queue_free()
	_practice_bot = null
	_holder = null
	_ball = null
	_ball_parent = null
	_map_root = null
	_local_player = null
	_participants.clear()
	_eliminated.clear()


func is_complete() -> bool:
	return _complete


func is_active() -> bool:
	return _active and is_instance_valid(_ball)


func is_holder(character: LocalBaseCharacter) -> bool:
	return is_instance_valid(character) and character == _holder


func get_holder_name() -> String:
	if not is_instance_valid(_holder):
		return "NADIE"
	return str(_holder.get_meta(&"display_name", "JUGADOR"))


func get_home_alive() -> int:
	return _alive_for_team(&"home")


func get_away_alive() -> int:
	return _alive_for_team(&"away")


func get_winner() -> int:
	var local_team: StringName = StringName(_local_player.get_meta(&"bateball_team", &"home")) if is_instance_valid(_local_player) else &"home"
	var local_alive := get_home_alive() if local_team == &"home" else get_away_alive()
	var rival_alive := get_away_alive() if local_team == &"home" else get_home_alive()
	return 1 if local_alive > rival_alive else -1 if rival_alive > local_alive else 0


func get_ball() -> RigidBody3D:
	return _ball


func _assign_holder(character: LocalBaseCharacter, announce := true) -> void:
	if character == _holder or not is_instance_valid(_ball) or _is_eliminated(character):
		return
	_holder = character
	_ball.freeze = true
	_ball.linear_velocity = Vector3.ZERO
	_ball.angular_velocity = Vector3.ZERO
	_ball.collision_layer = 0
	_ball.collision_mask = 0
	_follow_holder()
	ball_holder_changed.emit(get_holder_name())
	if announce:
		ball_holder_peer_changed.emit(_peer_id(character))


func _release_ball(impulse: Vector3, direction: Vector3) -> void:
	var release_position := _ball.global_position
	if is_instance_valid(_holder):
		release_position = _holder.global_position + direction * 1.0 + Vector3.UP * 0.38
	_ball.global_position = _clamp_position(release_position)
	_ball.freeze = false
	_ball.collision_layer = 1
	_ball.collision_mask = 1
	_ball.sleeping = false
	_ball.apply_central_impulse(impulse)
	_holder = null
	_pickup_cooldown = PICKUP_COOLDOWN
	ball_holder_changed.emit("NADIE")
	ball_holder_peer_changed.emit(0)


func _clear_holder(announce := true) -> void:
	if not is_instance_valid(_ball):
		return
	_ball.freeze = false
	_ball.collision_layer = 1
	_ball.collision_mask = 1
	_holder = null
	_pickup_cooldown = PICKUP_COOLDOWN
	ball_holder_changed.emit("NADIE")
	if announce:
		ball_holder_peer_changed.emit(0)


func _eliminate(character: LocalBaseCharacter) -> void:
	var target_peer := _peer_id(character)
	_eliminated[target_peer] = true
	character.set_authoritative_health(0)
	character.controls_enabled = false
	var impact := _ball.linear_velocity.normalized()
	character.apply_external_push(impact + Vector3.UP * 0.12, minf(6.0, _ball.linear_velocity.length()))
	player_eliminated.emit(target_peer, _thrower_peer_id, character.global_position)
	_ball.linear_velocity *= 0.48
	_pickup_cooldown = 0.38
	_emit_classification()
	if get_home_alive() == 0 or get_away_alive() == 0:
		_complete = true
		_active = false
		match_completed.emit(get_home_alive(), get_away_alive())


func _emit_classification() -> void:
	classification_changed.emit(get_home_alive(), get_away_alive(), _complete)


func _alive_for_team(team: StringName) -> int:
	var count := 0
	for character in _participants:
		if is_instance_valid(character) and StringName(character.get_meta(&"bateball_team", &"home")) == team and not _is_eliminated(character):
			count += 1
	return count


func _is_eliminated(character: LocalBaseCharacter) -> bool:
	return bool(_eliminated.get(_peer_id(character), false))


func _can_hit(character: LocalBaseCharacter) -> bool:
	if _is_eliminated(character):
		return false
	var peer := _peer_id(character)
	if peer == _thrower_peer_id and _thrower_grace > 0.0:
		return false
	var thrower := _character_for_peer(_thrower_peer_id)
	if (
		is_instance_valid(thrower)
		and StringName(thrower.get_meta(&"bateball_team", &"home"))
		== StringName(character.get_meta(&"bateball_team", &"home"))
	):
		return false
	var offset := _ball.global_position - (character.global_position + Vector3.UP * 0.75)
	return absf(offset.y) < 1.2 and Vector2(offset.x, offset.z).length() < 0.72


func _can_collect(character: LocalBaseCharacter) -> bool:
	if _is_eliminated(character):
		return false
	var offset := _ball.global_position - character.global_position
	return absf(offset.y) < 1.1 and Vector2(offset.x, offset.z).length() < 0.86


func _configure_character(character: LocalBaseCharacter) -> void:
	var slot := int(character.get_meta(&"lan_slot", 0))
	var contract: Node = _map_root.get_parent() if is_instance_valid(_map_root) else null
	var team: StringName = &"home" if posmod(slot, 2) == 0 else &"away"
	var spawn := character.global_transform
	var facing := Vector3.FORWARD
	if is_instance_valid(contract):
		team = StringName(contract.call("get_team_for_slot", slot))
		spawn = contract.call("get_spawn_transform", slot)
		facing = contract.call("get_team_facing_for_slot", slot)
	character.set_bateball_team(team)
	character.set_spawn_transform(spawn)
	character.set_facing_direction(facing)


func _spawn_practice_bot() -> void:
	_practice_bot = CHARACTER_SCENE.instantiate() as LocalBaseCharacter
	_practice_bot.name = "EliminationPracticeBot"
	_practice_bot.emit_metrics = false
	_practice_bot.set_meta(&"display_name", "BOT ROJO")
	_practice_bot.set_meta(&"lan_slot", 1)
	_practice_bot.set_meta(&"lan_peer_id", 9001)
	var camera := _practice_bot.get_node("CameraPivot/SpringArm/Camera") as Camera3D
	camera.current = false
	_local_player.get_parent().add_child(_practice_bot)
	_bot_throw_delay = 0.8


func _update_practice_bot(delta: float) -> void:
	if not is_instance_valid(_practice_bot) or _is_eliminated(_practice_bot):
		return
	_bot_throw_delay = maxf(0.0, _bot_throw_delay - delta)
	if _holder == _practice_bot:
		var target_direction := _local_player.global_position - _practice_bot.global_position
		target_direction.y = 0.0
		_practice_bot.set_touch_move(Vector2.ZERO)
		if target_direction.length_squared() > 0.01:
			_practice_bot.set_facing_direction(target_direction.normalized())
		if _bot_throw_delay <= 0.0:
			request_throw(_practice_bot, target_direction)
			_bot_throw_delay = 1.15
		return
	var target_position := _ball.global_position if not is_instance_valid(_holder) else _holder.global_position
	var world_direction := target_position - _practice_bot.global_position
	world_direction.y = 0.0
	if _holder == _local_player and world_direction.length() < 7.0:
		world_direction = Vector3(-world_direction.z, 0.0, world_direction.x)
	if world_direction.length_squared() > 0.04:
		world_direction = world_direction.normalized()
		_practice_bot.set_facing_direction(world_direction)
		# Top-down movement input is interpreted in camera space; the arena camera
		# faces north, so screen X/Y map directly to world X/Z here.
		_practice_bot.set_touch_move(Vector2(world_direction.x, world_direction.z))
	else:
		_practice_bot.set_touch_move(Vector2.ZERO)


func _follow_holder() -> void:
	if not is_instance_valid(_holder) or not is_instance_valid(_ball):
		return
	var forward := _holder.get_facing_direction()
	_ball.global_position = _clamp_position(_holder.global_position + forward * 0.7 + Vector3.UP * 0.38)
	_ball.global_rotation = Vector3.ZERO


func _reset_ball() -> void:
	_clear_holder()
	_ball.freeze = true
	_ball.global_transform = _ball_spawn
	_ball.linear_velocity = Vector3.ZERO
	_ball.angular_velocity = Vector3.ZERO
	_pickup_cooldown = 0.7
	await get_tree().create_timer(0.7).timeout
	if _active and is_instance_valid(_ball):
		_ball.freeze = false


func _inside_bounds() -> bool:
	var end := _ball_bounds.end
	return _ball.global_position.x >= _ball_bounds.position.x - 0.8 and _ball.global_position.x <= end.x + 0.8 and _ball.global_position.z >= _ball_bounds.position.z - 0.8 and _ball.global_position.z <= end.z + 0.8


func _clamp_position(value: Vector3) -> Vector3:
	var end := _ball_bounds.end
	return Vector3(clampf(value.x, _ball_bounds.position.x, end.x), clampf(value.y, _ball_bounds.position.y, end.y), clampf(value.z, _ball_bounds.position.z, end.z))


func _peer_id(character: LocalBaseCharacter) -> int:
	return int(character.get_meta(&"lan_peer_id", 1))


func _character_for_peer(peer_id: int) -> LocalBaseCharacter:
	for character in _participants:
		if is_instance_valid(character) and _peer_id(character) == peer_id:
			return character
	return null


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
