class_name LocalFootballHost
extends Node

signal score_changed(home_score: int, away_score: int, target: int)
signal goal_scored(scoring_side: StringName)
signal kickoff_ready
signal match_completed(home_score: int, away_score: int)
signal goalkeeper_zone_changed(active: bool, side: StringName)
signal goalkeeper_save(side: StringName, level: int)

@export_range(1, 10, 1) var target_score := 3

var score := 0
var opponent_score := 0
var _active := false
var _complete := false
var _goal_lock := false
var _generation := 0
var _time_scale := 1.0
var _ball: RigidBody3D
var _ball_spawn := Transform3D.IDENTITY
var _goalkeeper
var _goalkeeper_zone := &""
var _player_team: StringName = &"home"


func start_match(map_root: Node3D, time_scale := 1.0, goalkeeper_value = null) -> bool:
	stop_and_clean()
	_generation += 1
	_time_scale = maxf(0.05, time_scale)
	_ball = _find_descendant_in_group(map_root, &"football_ball") as RigidBody3D
	if _ball == null:
		return false
	_ball_spawn = _ball.global_transform
	_goalkeeper = goalkeeper_value
	_player_team = &"home"
	if is_instance_valid(_goalkeeper) and _goalkeeper.has_meta(&"football_team"):
		_player_team = StringName(_goalkeeper.get_meta(&"football_team"))
	_goalkeeper_zone = &""
	for goal in get_tree().get_nodes_in_group(&"football_goal"):
		if map_root.is_ancestor_of(goal) and goal is Area3D:
			var area := goal as Area3D
			area.body_entered.connect(_on_goal_body_entered.bind(area))
	for zone in get_tree().get_nodes_in_group(&"goalkeeper_zone"):
		if map_root.is_ancestor_of(zone) and zone is Area3D:
			var goalkeeper_area := zone as Area3D
			goalkeeper_area.body_entered.connect(
				_on_goalkeeper_entered.bind(goalkeeper_area)
			)
			goalkeeper_area.body_exited.connect(
				_on_goalkeeper_exited.bind(goalkeeper_area)
			)
	score = 0
	opponent_score = 0
	_complete = false
	_goal_lock = false
	_active = true
	score_changed.emit(score, opponent_score, target_score)
	return true


func stop_and_clean() -> void:
	_generation += 1
	_active = false
	_complete = false
	_goal_lock = false
	_ball = null
	_goalkeeper = null
	_goalkeeper_zone = &""
	_player_team = &"home"


func finish_match() -> void:
	_active = false
	if is_instance_valid(_ball):
		_ball.freeze = true
		_ball.linear_velocity = Vector3.ZERO
		_ball.angular_velocity = Vector3.ZERO


func is_complete() -> bool:
	return _complete


func get_ball() -> RigidBody3D:
	return _ball


func is_ball_ready() -> bool:
	return _active and not _goal_lock and is_instance_valid(_ball)


func is_goalkeeper_in_zone() -> bool:
	return _active and _goalkeeper_zone != &""


func get_goalkeeper_zone_side() -> StringName:
	return _goalkeeper_zone


func get_player_team() -> StringName:
	return _player_team


func get_player_goal_side() -> StringName:
	# Home attacks north and defends south; away attacks south and defends north.
	return &"away" if _player_team == &"home" else &"home"


func set_player_team(team: StringName) -> void:
	_player_team = &"away" if team == &"away" else &"home"
	if _goalkeeper_zone != &"" and _goalkeeper_zone != get_player_goal_side():
		_goalkeeper_zone = &""
		goalkeeper_zone_changed.emit(false, team)


func get_winner() -> int:
	if score > opponent_score:
		return 1
	if opponent_score > score:
		return -1
	return 0


func _on_goal_body_entered(body: Node3D, goal: Area3D) -> void:
	if not _active or _goal_lock or body != _ball:
		return
	if _try_goalkeeper_save(goal):
		return
	_goal_lock = true
	var scoring_side: StringName = goal.get_meta(&"scores_for", &"home")
	if scoring_side == &"home":
		score += 1
	else:
		opponent_score += 1
	score_changed.emit(score, opponent_score, target_score)
	goal_scored.emit(scoring_side)
	if score >= target_score or opponent_score >= target_score:
		_complete = true
		_active = false
		_ball.freeze = true
		match_completed.emit(score, opponent_score)
		return
	_reset_kickoff_after_delay(_generation)


func _try_goalkeeper_save(goal: Area3D) -> bool:
	if _goalkeeper == null or not is_instance_valid(_goalkeeper):
		return false
	var goal_side: StringName = goal.get_meta(&"scores_for", &"home")
	if _goalkeeper_zone != goal_side or not _goalkeeper.is_goalkeeper_diving():
		return false
	var target_side := 0
	if _ball.global_position.x < -0.7:
		target_side = -1
	elif _ball.global_position.x > 0.7:
		target_side = 1
	var dive_side: int = _goalkeeper.get_goalkeeper_side()
	var target_level := 0
	if _ball.global_position.y >= 1.65:
		target_level = 2
	elif _ball.global_position.y >= 0.8:
		target_level = 1
	if target_side != 0 and target_side != dive_side:
		return false
	if target_level != _goalkeeper.get_goalkeeper_level():
		return false
	_goal_lock = true
	var away := Vector3(0.0, 0.0, 1.0 if goal_side == &"home" else -1.0)
	_ball.freeze = false
	_ball.sleeping = false
	_ball.global_position += away * 0.75
	_ball.apply_central_impulse(away * 4.8 + Vector3.UP * 1.1)
	goalkeeper_save.emit(goal_side, target_level)
	_unlock_after_save(_generation)
	return true


func _on_goalkeeper_entered(body: Node3D, zone: Area3D) -> void:
	if body != _goalkeeper:
		return
	var side: StringName = zone.get_meta(&"goal_side", &"")
	if side != get_player_goal_side():
		# Players may cross the opponent's goal area, but never receive
		# goalkeeper controls there.
		return
	_goalkeeper_zone = side
	goalkeeper_zone_changed.emit(true, _goalkeeper_zone)


func _on_goalkeeper_exited(body: Node3D, zone: Area3D) -> void:
	if body != _goalkeeper:
		return
	var side: StringName = zone.get_meta(&"goal_side", &"")
	if _goalkeeper_zone != side:
		return
	_goalkeeper_zone = &""
	goalkeeper_zone_changed.emit(false, side)


func _unlock_after_save(generation: int) -> void:
	await get_tree().physics_frame
	if generation == _generation and _active:
		_goal_lock = false


func _reset_kickoff_after_delay(generation: int) -> void:
	_ball.freeze = true
	_ball.linear_velocity = Vector3.ZERO
	_ball.angular_velocity = Vector3.ZERO
	await get_tree().create_timer(0.7 * _time_scale).timeout
	if generation != _generation or not is_instance_valid(_ball):
		return
	_ball.global_transform = _ball_spawn
	_ball.freeze = false
	_ball.sleeping = false
	await get_tree().physics_frame
	if generation != _generation or not is_instance_valid(_ball):
		return
	_goal_lock = false
	kickoff_ready.emit()


func _find_descendant_in_group(root: Node, group: StringName) -> Node:
	if root == null:
		return null
	if root.is_in_group(group):
		return root
	for child in root.get_children():
		var found := _find_descendant_in_group(child, group)
		if found != null:
			return found
	return null
