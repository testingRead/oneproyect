extends SceneTree

const LAB_SCENE := preload("res://scenes/local/local_lab.tscn")

var _failed := false


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	ProjectSettings.set_setting("oneproyect/session_minigame_path", "res://data/minigames/balon_eliminacion.tres")
	ProjectSettings.set_setting("oneproyect/session_auto_start", false)
	var lab := LAB_SCENE.instantiate() as LocalDevelopmentLab
	root.add_child(lab)
	await process_frame
	lab.round_controller.duration_multiplier = 0.1
	var baseline := get_node_count()
	_require(lab.start_reference_round(8801), "Elimination Ball must start")
	_require(await _wait_for_phase(lab, LocalRoundController.Phase.ACTIVE, 180), "Round must reach active")
	_require(lab.player.is_top_down_mode(), "Elimination Ball must reuse top-down aiming")
	_require(lab.look_pad.is_aim_mode(), "Right touch area must be an aim pad")
	_require(not lab.foot_button.visible and not lab.hand_button.visible, "Mode must not expose unrelated actions")
	var bot := lab.get_node_or_null("World/EliminationPracticeBot") as LocalBaseCharacter
	_require(is_instance_valid(bot), "Solo practice must create one opponent")
	if not is_instance_valid(bot):
		quit(1)
		return
	bot.set_physics_process(false)
	lab.player.global_position = Vector3(0.0, 0.02, -20.0)
	lab.elimination_ball_host.apply_authoritative_holder(lab.player)
	_require(lab.elimination_ball_host.is_holder(lab.player), "Player must collect the centre ball")
	bot.global_position = Vector3(0.0, 0.02, -26.0)
	lab.player.global_position = Vector3(0.0, 0.02, -22.0)
	lab.player.force_update_transform()
	bot.force_update_transform()
	for frame in 2:
		await physics_frame
	_require(lab.elimination_ball_host.request_throw(lab.player, Vector3(0.0, 0.0, -1.0)), "Carrier must throw while moving/aiming")
	var peak_speed := 0.0
	for frame in 90:
		var ball: RigidBody3D = lab.elimination_ball_host.get_ball() as RigidBody3D
		if is_instance_valid(ball):
			peak_speed = maxf(peak_speed, ball.linear_velocity.length())
		if not is_instance_valid(bot) or bot.get_local_health() <= 0:
			break
		await physics_frame
	_require(peak_speed > 5.5 and peak_speed < 8.5, "Throw must be fast but locally readable")
	_require(not is_instance_valid(bot) or bot.get_local_health() == 0, "A direct ball impact must eliminate")
	_require(lab.elimination_ball_host.is_complete(), "Eliminating the rival team must end the round")
	_require(await _wait_for_phase(lab, LocalRoundController.Phase.IDLE, 240), "Round must clean and return idle")
	_require(get_node_count() == baseline, "Practice bot, ball and map must leave no residue")
	print("ELIMINATION_BALL_OK peak_speed=%.2f baseline=%d" % [peak_speed, baseline])
	quit(1 if _failed else 0)


func _wait_for_phase(lab: LocalDevelopmentLab, wanted: int, limit: int) -> bool:
	for frame in limit:
		if lab.round_controller.phase == wanted:
			return true
		await physics_frame
	return false


func _require(condition: bool, message: String) -> void:
	if not condition:
		_failed = true
		push_error("ELIMINATION_BALL_FAIL: %s" % message)
