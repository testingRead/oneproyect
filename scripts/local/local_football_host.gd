class_name LocalFootballHost
extends Node

signal score_changed(home_score: int, away_score: int, target: int)
signal goal_scored(scoring_side: StringName)
signal kickoff_ready
signal match_completed(home_score: int, away_score: int)
signal goalkeeper_zone_changed(active: bool, side: StringName)
signal goalkeeper_save(side: StringName, level: int)
signal penalty_choice_requested(attempt: int, seconds: float)
signal penalty_cinematic(shot_direction: int, save_direction: int, scored: bool)
signal penalty_score_changed(home_score: int, away_score: int, attempt: int)

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
var _bot_cooldown := {&"home": 0.0, &"away": 0.0}
var _bots := {}
var _penalty_choice := 99
var _penalty_winner := 0


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
	_penalty_winner = 0
	_goal_lock = false
	_active = true
	_bot_cooldown = {&"home": 0.0, &"away": 0.0}
	_bots = {}
	for bot in get_tree().get_nodes_in_group(&"football_goalkeeper_bot"):
		if map_root.is_ancestor_of(bot):
			_bots[bot.get_meta(&"goal_side", &"")] = bot
	score_changed.emit(score, opponent_score, target_score)
	return true


func _physics_process(delta: float) -> void:
	if not _active or _goal_lock or not is_instance_valid(_ball):
		return
	for side in [&"home", &"away"]:
		_bot_cooldown[side] = maxf(0.0, float(_bot_cooldown[side]) - delta)
		_try_bot_save(side)


func _try_bot_save(side: StringName) -> bool:
	if float(_bot_cooldown[side]) > 0.0:
		return false
	var z_line := -1.8 if side == &"home" else -38.2
	var moving_toward_goal := _ball.linear_velocity.z > 0.05 if side == &"home" else _ball.linear_velocity.z < -0.05
	var close_to_line := absf(_ball.global_position.z - z_line) < 1.15
	if not moving_toward_goal or not close_to_line:
		return false
	if absf(_ball.global_position.x) > 3.25 or _ball.global_position.y > 2.75:
		return false
	_bot_cooldown[side] = 0.9
	_goal_lock = true
	var away := Vector3(0.0, 0.0, -1.0 if side == &"home" else 1.0)
	var lateral := clampf(-_ball.global_position.x * 0.22, -1.2, 1.2)
	var bot = _bots.get(side)
	if is_instance_valid(bot) and bot.has_method("trigger_save"):
		bot.trigger_save(_ball.global_position.x, 1 if _ball.global_position.y < 1.65 else 2)
	_ball.sleeping = false
	_ball.apply_central_impulse(away * 4.6 + Vector3(lateral, 1.4, 0.0))
	goalkeeper_save.emit(side, 1)
	_unlock_after_save(_generation)
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


func is_tied() -> bool:
	return score == opponent_score


func submit_penalty_choice(direction: int) -> void:
	if _penalty_choice == 99:
		_penalty_choice = clampi(direction, -1, 1)


func run_penalty_shootout() -> void:
	if not is_instance_valid(_ball):
		return
	_penalty_winner = 0
	var home_penalties := 0
	var away_penalties := 0
	for attempt in 5:
		_penalty_choice = 99
		penalty_choice_requested.emit(attempt + 1, 3.0)
		var deadline := Time.get_ticks_msec() + 3000
		while _penalty_choice == 99 and Time.get_ticks_msec() < deadline:
			await get_tree().physics_frame
		if _penalty_choice == 99:
			_penalty_choice = 0
		var keeper_choice: int = [-1, 0, 1][posmod(attempt * 5 + score + opponent_score, 3)]
		var scored: bool = _penalty_choice != keeper_choice
		await _play_penalty_cinematic(_penalty_choice, keeper_choice, scored)
		if scored:
			home_penalties += 1
		# The rival also takes one simple bot-controlled shot per round.
		if posmod(attempt * 7 + keeper_choice + score, 3) != 0:
			away_penalties += 1
		penalty_score_changed.emit(home_penalties, away_penalties, attempt + 1)
	# Sudden death stays simple and deterministic for the local prototype.
	if home_penalties == away_penalties:
		_penalty_winner = 1 if score >= opponent_score else -1
	else:
		_penalty_winner = 1 if home_penalties > away_penalties else -1


func _play_penalty_cinematic(shot_direction: int, save_direction: int, scored: bool) -> void:
	_ball.freeze = true
	_ball.global_position = Vector3(0.0, 0.24, -9.5)
	var penalty_bot = _bots.get(&"away")
	if is_instance_valid(penalty_bot) and penalty_bot.has_method("trigger_save"):
		penalty_bot.trigger_save(float(save_direction), 1)
	var target := Vector3(float(shot_direction) * 2.15, 1.25, -37.9)
	penalty_cinematic.emit(shot_direction, save_direction, scored)
	var tween := create_tween()
	tween.tween_property(_ball, "global_position", target, 0.62)
	await tween.finished
	_ball.global_transform = _ball_spawn



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


func get_local_score() -> int:
	return opponent_score if _player_team == &"away" else score


func get_rival_score() -> int:
	return score if _player_team == &"away" else opponent_score


func get_player_goal_side() -> StringName:
	# Home attacks north and defends south; away attacks south and defends north.
	return &"away" if _player_team == &"home" else &"home"


func set_player_team(team: StringName) -> void:
	_player_team = &"away" if team == &"away" else &"home"
	if _goalkeeper_zone != &"" and _goalkeeper_zone != get_player_goal_side():
		_goalkeeper_zone = &""
		goalkeeper_zone_changed.emit(false, team)


func get_winner() -> int:
	if _penalty_winner != 0:
		return _penalty_winner
	if get_local_score() > get_rival_score():
		return 1
	if get_rival_score() > get_local_score():
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
