class_name LocalFootballHost
extends Node

signal score_changed(home_score: int, away_score: int, target: int)
signal goal_scored(scoring_side: StringName)
signal kickoff_ready
signal match_completed(home_score: int, away_score: int)

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


func start_match(map_root: Node3D, time_scale := 1.0) -> bool:
	stop_and_clean()
	_generation += 1
	_time_scale = maxf(0.05, time_scale)
	_ball = _find_descendant_in_group(map_root, &"football_ball") as RigidBody3D
	if _ball == null:
		return false
	_ball_spawn = _ball.global_transform
	for goal in get_tree().get_nodes_in_group(&"football_goal"):
		if map_root.is_ancestor_of(goal) and goal is Area3D:
			var area := goal as Area3D
			area.body_entered.connect(_on_goal_body_entered.bind(area))
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


func get_winner() -> int:
	if score > opponent_score:
		return 1
	if opponent_score > score:
		return -1
	return 0


func _on_goal_body_entered(body: Node3D, goal: Area3D) -> void:
	if not _active or _goal_lock or body != _ball:
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
