class_name LocalBateballHost
extends Node

signal score_changed(home_score: int, away_score: int, target: int)
signal ball_holder_changed(holder_name: String)
signal goal_scored(scoring_side: StringName)
signal match_completed(home_score: int, away_score: int)

const TARGET_SCORE := 2

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


func start_match(map_root: Node3D, player: LocalBaseCharacter) -> bool:
	stop_and_clean()
	_ball = _find_descendant(map_root, &"bateball_ball") as RigidBody3D
	if _ball == null or player == null:
		return false
	_generation += 1
	_map_root = map_root
	_ball_parent = _ball.get_parent()
	_ball_spawn = _ball.global_transform
	player.set_bat_enabled(true)
	_connect_bat_character(player)
	for goal in get_tree().get_nodes_in_group(&"bateball_goal"):
		if map_root.is_ancestor_of(goal) and goal is Area3D:
			(goal as Area3D).body_entered.connect(_on_goal_entered.bind(goal))
	score = 0
	opponent_score = 0
	_complete = false
	_active = true
	score_changed.emit(score, opponent_score, TARGET_SCORE)
	ball_holder_changed.emit("NADIE")
	return true


func _physics_process(_delta: float) -> void:
	if not _active or not is_instance_valid(_ball):
		return
	for candidate in get_tree().get_nodes_in_group(&"local_base_character"):
		if candidate is LocalBaseCharacter:
			_connect_bat_character(candidate as LocalBaseCharacter)
	if is_instance_valid(_holder):
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
	_release_ball(direction * 9.8 + Vector3.UP * 0.72)
	return true


func is_holder(character: LocalBaseCharacter) -> bool:
	return is_instance_valid(character) and character == _holder


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
	_connected_bat_characters.clear()


func is_complete() -> bool:
	return _complete


func get_winner() -> int:
	if score > opponent_score:
		return 1
	if opponent_score > score:
		return -1
	return 0


func get_holder_name() -> String:
	return str(_holder.get_meta(&"display_name", _holder.name)) if is_instance_valid(_holder) else "NADIE"


func get_ball() -> RigidBody3D:
	return _ball


func _assign_holder(next_holder: LocalBaseCharacter) -> void:
	if next_holder == _holder or not is_instance_valid(_ball):
		return
	_holder = next_holder
	_ball.freeze = true
	_ball.linear_velocity = Vector3.ZERO
	_ball.angular_velocity = Vector3.ZERO
	_ball.collision_layer = 0
	_ball.collision_mask = 0
	var anchor := next_holder.get_node_or_null("AnchorPoints/HeldItem") as Node3D
	if anchor != null:
		_ball.reparent(anchor, false)
		_ball.position = Vector3(0.0, -0.36, -0.52)
		_ball.rotation = Vector3.ZERO
	ball_holder_changed.emit(get_holder_name())


func _release_ball(impulse: Vector3) -> void:
	if not is_instance_valid(_ball) or not is_instance_valid(_ball_parent):
		return
	var release_position := _ball.global_position
	_ball.reparent(_ball_parent, true)
	_ball.global_position = release_position
	_ball.freeze = false
	_ball.collision_layer = 1
	_ball.collision_mask = 1
	_ball.sleeping = false
	_ball.apply_central_impulse(impulse)
	_holder = null
	ball_holder_changed.emit("NADIE")


func _on_bat_hit(target: Node3D, charged: bool, attacker: LocalBaseCharacter) -> void:
	if not charged or target != _holder:
		return
	var direction := attacker.get_facing_direction()
	_release_ball(direction.normalized() * 4.0 + Vector3.UP * 0.35)


func _connect_bat_character(character: LocalBaseCharacter) -> void:
	var key := character.get_instance_id()
	if _connected_bat_characters.has(key):
		return
	character.set_bat_enabled(true)
	character.bat_hit.connect(_on_bat_hit.bind(character))
	_connected_bat_characters[key] = character


func _on_goal_entered(body: Node3D, goal: Area3D) -> void:
	if not _active or body != _ball:
		return
	var scoring_side: StringName = goal.get_meta(&"scores_for", &"home")
	if scoring_side == &"home":
		score += 1
	else:
		opponent_score += 1
	score_changed.emit(score, opponent_score, TARGET_SCORE)
	goal_scored.emit(scoring_side)
	if score >= TARGET_SCORE or opponent_score >= TARGET_SCORE:
		_complete = true
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
	ball_holder_changed.emit("NADIE")
	await get_tree().create_timer(0.8).timeout
	if generation == _generation and is_instance_valid(_ball):
		_ball.freeze = false


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
