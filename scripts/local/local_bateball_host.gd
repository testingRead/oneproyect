class_name LocalBateballHost
extends Node

signal score_changed(home_score: int, away_score: int, target: int)
signal ball_holder_changed(holder_name: String)
signal goal_scored(scoring_side: StringName)
signal match_completed(home_score: int, away_score: int)
signal ball_holder_peer_changed(peer_id: int)
signal character_health_authorized(peer_id: int, health: int, respawned: bool, position: Vector3)

const TARGET_SCORE := 2
const BALL_MIN := Vector3(-14.35, 0.2, -39.35)
const BALL_MAX := Vector3(14.35, 4.8, -0.65)

var score := 0
var opponent_score := 0
var _active := false
var _complete := false
var _ball: RigidBody3D
var _ball_parent: Node
var _ball_spawn := Transform3D.IDENTITY
var _holder: LocalBaseCharacter
var _map_root: Node3D
var _generation := 0
var _connected_bat_characters: Dictionary = {}
var _pickup_cooldown := 0.0
var _local_team: StringName = &"home"
var _session_authority := true
var _local_player: LocalBaseCharacter


func start_match(map_root: Node3D, player: LocalBaseCharacter) -> bool:
	stop_and_clean()
	_ball = _find_descendant(map_root, &"bateball_ball") as RigidBody3D
	if _ball == null or player == null:
		return false
	_generation += 1
	_map_root = map_root
	_local_player = player
	_ball_parent = _ball.get_parent()
	_ball_spawn = _ball.global_transform
	_connect_bat_character(player)
	_local_team = StringName(player.get_meta(&"bateball_team", &"home"))
	for goal in get_tree().get_nodes_in_group(&"bateball_goal"):
		if map_root.is_ancestor_of(goal) and goal is Area3D:
			(goal as Area3D).body_entered.connect(_on_goal_entered.bind(goal))
	score = 0
	opponent_score = 0
	_complete = false
	_active = true
	_pickup_cooldown = 0.0
	score_changed.emit(score, opponent_score, TARGET_SCORE)
	ball_holder_changed.emit("NADIE")
	return true


func _physics_process(delta: float) -> void:
	if not _active or not is_instance_valid(_ball):
		return
	_pickup_cooldown = maxf(0.0, _pickup_cooldown - delta)
	for candidate in get_tree().get_nodes_in_group(&"local_base_character"):
		if candidate is LocalBaseCharacter:
			_connect_bat_character(candidate as LocalBaseCharacter)
	if is_instance_valid(_holder):
		_follow_holder()
		return
	if not _session_authority:
		return
	if not _is_ball_inside_arena():
		_reset_ball(_generation)
		return
	if _pickup_cooldown > 0.0:
		return
	for candidate in get_tree().get_nodes_in_group(&"local_base_character"):
		if candidate is LocalBaseCharacter:
			var character := candidate as LocalBaseCharacter
			if character.global_position.distance_to(_ball.global_position) < 0.82:
				_assign_holder(character)
				return


func request_ball_shot(shooter: LocalBaseCharacter, aim_direction := Vector3.ZERO) -> bool:
	if not _active or shooter != _holder or not is_instance_valid(_ball):
		return false
	var direction := Vector3(aim_direction.x, 0.0, aim_direction.z)
	if direction.length_squared() < 0.01:
		direction = shooter.get_facing_direction()
	direction = direction.normalized()
	shooter.set_facing_direction(direction)
	shooter.visual_root.trigger_ball_shot()
	_release_ball(direction * 9.8 + Vector3.UP * 0.72, direction)
	return true


func is_holder(character: LocalBaseCharacter) -> bool:
	return is_instance_valid(character) and character == _holder


func set_session_authority(enabled: bool) -> void:
	_session_authority = enabled


func apply_authoritative_holder(character: LocalBaseCharacter) -> void:
	if is_instance_valid(character):
		_assign_holder(character, false)
	else:
		_clear_holder_without_impulse(false)


func apply_authoritative_score(home_score: int, away_score: int, complete: bool) -> void:
	score = maxi(0, home_score)
	opponent_score = maxi(0, away_score)
	_complete = complete
	score_changed.emit(score, opponent_score, TARGET_SCORE)


func finish_match() -> void:
	if not _active:
		return
	_active = false
	match_completed.emit(score, opponent_score)


func stop_and_clean() -> void:
	_generation += 1
	_active = false
	_complete = false
	for character: Variant in _connected_bat_characters.values():
		if is_instance_valid(character):
			(character as LocalBaseCharacter).set_bat_enabled(false)
	if is_instance_valid(_ball) and is_instance_valid(_ball_parent):
		_ball.reparent(_ball_parent, true)
		_ball.freeze = false
		_ball.collision_layer = 1
		_ball.collision_mask = 1
	_holder = null
	_ball = null
	_ball_parent = null
	_map_root = null
	_local_player = null
	_connected_bat_characters.clear()


func is_complete() -> bool:
	return _complete


func get_winner() -> int:
	var local_score := get_local_score()
	var rival_score := get_rival_score()
	if local_score > rival_score:
		return 1
	if rival_score > local_score:
		return -1
	return 0


func get_local_score() -> int:
	return opponent_score if _local_team == &"away" else score


func get_rival_score() -> int:
	return score if _local_team == &"away" else opponent_score


func get_local_team() -> StringName:
	return _local_team


func get_holder_name() -> String:
	if not is_instance_valid(_holder):
		return "NADIE"
	var display_name := str(_holder.get_meta(&"display_name", "")).strip_edges()
	return display_name if not display_name.is_empty() else "JUGADOR"


func get_ball() -> RigidBody3D:
	return _ball


func _assign_holder(next_holder: LocalBaseCharacter, announce := true) -> void:
	if next_holder == _holder or not is_instance_valid(_ball):
		return
	_holder = next_holder
	_ball.freeze = true
	_ball.linear_velocity = Vector3.ZERO
	_ball.angular_velocity = Vector3.ZERO
	_ball.collision_layer = 0
	_ball.collision_mask = 0
	# Keep the physics body under the map. Its frozen transform follows a safe
	# point in front of the carrier instead of a non-rotating character anchor.
	if _ball.get_parent() != _ball_parent:
		_ball.reparent(_ball_parent, true)
	_follow_holder()
	ball_holder_changed.emit(get_holder_name())
	if announce:
		ball_holder_peer_changed.emit(int(next_holder.get_meta(&"lan_peer_id", 1)))


func _release_ball(impulse: Vector3, release_direction := Vector3.ZERO) -> void:
	if not is_instance_valid(_ball) or not is_instance_valid(_ball_parent):
		return
	var release_position := _ball.global_position
	if is_instance_valid(_holder):
		var direction := Vector3(release_direction.x, 0.0, release_direction.z)
		if direction.length_squared() < 0.01:
			direction = _holder.get_facing_direction()
		release_position = _holder.global_position + direction.normalized() * 0.92 + Vector3.UP * 0.3
	_ball.global_position = _clamp_ball_position(release_position)
	_ball.freeze = false
	_ball.collision_layer = 1
	_ball.collision_mask = 1
	_ball.sleeping = false
	_ball.apply_central_impulse(impulse)
	_holder = null
	_pickup_cooldown = 0.32
	ball_holder_changed.emit("NADIE")
	ball_holder_peer_changed.emit(0)


func _clear_holder_without_impulse(announce := true) -> void:
	if not is_instance_valid(_ball):
		return
	_ball.freeze = false
	_ball.collision_layer = 1
	_ball.collision_mask = 1
	_holder = null
	_pickup_cooldown = 0.32
	ball_holder_changed.emit("NADIE")
	if announce:
		ball_holder_peer_changed.emit(0)


func _on_bat_hit(target: Node3D, charged: bool, attacker: LocalBaseCharacter) -> void:
	if charged and target == _holder:
		var direction := attacker.get_facing_direction()
		_release_ball(direction.normalized() * 4.0 + Vector3.UP * 0.35, direction)
	if _session_authority and target is LocalBaseCharacter:
		var character := target as LocalBaseCharacter
		_emit_character_health(character, false)
		if character.get_local_health() <= 0:
			_respawn_character(character, _generation)


func _connect_bat_character(character: LocalBaseCharacter) -> void:
	var key := character.get_instance_id()
	if _connected_bat_characters.has(key):
		return
	character.set_bat_enabled(true)
	character.reset_local_health()
	_configure_character(character)
	character.bat_hit.connect(_on_bat_hit.bind(character))
	_connected_bat_characters[key] = character


func _respawn_character(character: LocalBaseCharacter, generation: int) -> void:
	character.controls_enabled = false
	await get_tree().create_timer(2.0).timeout
	if generation != _generation or not _active or not is_instance_valid(character):
		return
	character.reset_local_health()
	_configure_character(character)
	character.controls_enabled = character == _local_player
	_emit_character_health(character, true)


func _emit_character_health(character: LocalBaseCharacter, respawned: bool) -> void:
	character_health_authorized.emit(
		int(character.get_meta(&"lan_peer_id", 1)),
		character.get_local_health(),
		respawned,
		character.global_position
	)


func _configure_character(character: LocalBaseCharacter) -> void:
	var slot := int(character.get_meta(&"lan_slot", 0))
	var team: StringName = &"home" if posmod(slot, 2) == 0 else &"away"
	var spawn := character.global_transform
	if is_instance_valid(_map_root) and _map_root.has_method("get_team_for_slot"):
		team = StringName(_map_root.call("get_team_for_slot", slot))
	if is_instance_valid(_map_root) and _map_root.has_method("get_spawn_for_slot"):
		spawn = _map_root.call("get_spawn_for_slot", slot)
	character.set_bateball_team(team)
	character.set_spawn_transform(spawn)
	character.set_facing_direction(
		Vector3(0.0, 0.0, -1.0) if team == &"home" else Vector3(0.0, 0.0, 1.0)
	)


func _on_goal_entered(body: Node3D, goal: Area3D) -> void:
	if not _active or not _session_authority or body != _ball:
		return
	var scoring_side: StringName = goal.get_meta(&"scores_for", &"home")
	if scoring_side == &"home":
		score += 1
	else:
		opponent_score += 1
	_complete = score >= TARGET_SCORE or opponent_score >= TARGET_SCORE
	score_changed.emit(score, opponent_score, TARGET_SCORE)
	goal_scored.emit(scoring_side)
	if _complete:
		finish_match()
		return
	_reset_ball(_generation)


func _reset_ball(generation: int) -> void:
	if is_instance_valid(_holder):
		_holder = null
	if not is_instance_valid(_ball) or not is_instance_valid(_ball_parent):
		return
	_ball.reparent(_ball_parent, true)
	_ball.freeze = true
	_ball.global_transform = _ball_spawn
	_ball.linear_velocity = Vector3.ZERO
	_ball.angular_velocity = Vector3.ZERO
	_pickup_cooldown = 0.8
	ball_holder_changed.emit("NADIE")
	await get_tree().create_timer(0.8).timeout
	if generation == _generation and is_instance_valid(_ball):
		_ball.freeze = false


func _follow_holder() -> void:
	if not is_instance_valid(_holder) or not is_instance_valid(_ball):
		return
	var forward := _holder.get_facing_direction()
	var wanted := _holder.global_position + forward * 0.68 + Vector3.UP * 0.3
	_ball.global_position = _clamp_ball_position(wanted)
	_ball.global_rotation = Vector3.ZERO


func _clamp_ball_position(value: Vector3) -> Vector3:
	return Vector3(
		clampf(value.x, BALL_MIN.x, BALL_MAX.x),
		clampf(value.y, BALL_MIN.y, BALL_MAX.y),
		clampf(value.z, BALL_MIN.z, BALL_MAX.z)
	)


func _is_ball_inside_arena() -> bool:
	return (
		_ball.global_position.x >= BALL_MIN.x - 0.8
		and _ball.global_position.x <= BALL_MAX.x + 0.8
		and _ball.global_position.z >= BALL_MIN.z - 0.8
		and _ball.global_position.z <= BALL_MAX.z + 0.8
		and _ball.global_position.y >= -0.8
		and _ball.global_position.y <= BALL_MAX.y + 2.0
	)


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
