extends SceneTree

const LAB_SCENE := preload("res://scenes/local/local_lab.tscn")
const LAB_MAP: MinigameMapDefinition = preload("res://data/maps/campo_futbol_local.tres")

var _failed := false


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_require(not root.has_node("Network"), "Local rounds must not create Network")
	_require(
		LAB_MAP.supports_minigame(&"futbol_rebote")
		and LAB_MAP.supports_minigame(&"futbol_local")
		and LAB_MAP.compatible_disasters.is_empty(),
		"Football map must declare only its local match modes"
	)
	_require(
		LAB_MAP.map_scene != null
		and LAB_MAP.footprint == Vector2(26.0, 40.0)
		and LAB_MAP.spawn_points.size() == 8,
		"Football map must package one scene and eight spawn points (4v4)"
	)
	_require(
		LAB_MAP.has_team_layout()
		and LAB_MAP.get_team_for_slot(0) == &"home"
		and LAB_MAP.get_team_for_slot(1) == &"away"
		and LAB_MAP.get_team_for_slot(2) == &"home"
		and LAB_MAP.get_team_for_slot(3) == &"away",
		"Team slots must alternate and remain balanced"
	)
	_require(
		LAB_MAP.get_spawn_for_slot(0).z > -20.0
		and LAB_MAP.get_spawn_for_slot(1).z < -20.0
		and LAB_MAP.get_spawn_for_slot(2).distance_to(LAB_MAP.get_spawn_for_slot(0)) > 1.0
		and LAB_MAP.get_spawn_for_slot(3).distance_to(LAB_MAP.get_spawn_for_slot(1)) > 1.0,
		"First two friends must spawn on opposite halves and teammates must not overlap"
	)
	_require(
		LAB_MAP.available_objects == PackedStringArray(
			["balon_futbol", "dos_porterias", "muros_rebote"]
		),
		"Football definition must declare two goals and rebound walls"
	)

	var lab := LAB_SCENE.instantiate() as LocalDevelopmentLab
	root.add_child(lab)
	await process_frame
	for frame in 20:
		await physics_frame
	lab.round_controller.duration_multiplier = 0.08
	var baseline_nodes := get_node_count()
	var expected_phases := PackedInt32Array([
		LocalRoundController.Phase.PREPARE,
		LocalRoundController.Phase.RULES,
		LocalRoundController.Phase.COUNTDOWN,
		LocalRoundController.Phase.ACTIVE,
		LocalRoundController.Phase.RESULT,
		LocalRoundController.Phase.CLEANUP,
		LocalRoundController.Phase.IDLE,
	])

	for round_index in 8:
		var phases := PackedInt32Array()
		var countdown_steps := PackedInt32Array()
		var countdown_titles := PackedStringArray()
		var collect_phase := func(
			next_phase: LocalRoundController.Phase,
			_label: String,
			_seconds: float
		) -> void:
			phases.append(next_phase)
		var collect_time := func(
			current_phase: LocalRoundController.Phase,
			remaining: float
		) -> void:
			if current_phase != LocalRoundController.Phase.COUNTDOWN:
				return
			var step := maxi(1, ceili(remaining))
			if countdown_steps.is_empty() or countdown_steps[-1] != step:
				countdown_steps.append(step)
				countdown_titles.append(lab.banner_title.text)
		lab.round_controller.phase_changed.connect(collect_phase)
		lab.round_controller.phase_time_changed.connect(collect_time)
		_require(
			lab.start_reference_round(1000 + round_index * 37),
			"Idle lab must accept a football match"
		)
		await physics_frame
		var mounted := lab.map_host.get_node_or_null("MountedMap")
		_require(
			mounted is Node3D
			and mounted.has_node("Pitch")
			and mounted.has_node("Football")
			and mounted.has_node("NorthGoalArea")
			and mounted.has_node("SouthGoalArea")
			and mounted.has_node("LeftReboundWall")
			and mounted.has_node("RightReboundWall")
			and lab.map_host.get_mounted_node_count() > 45,
			"Match must mount the pitch, two goals, ball and rebound walls"
		)
		_require(
			await _wait_for_phase(lab, LocalRoundController.Phase.ACTIVE, 180),
			"Football must reach its active phase"
		)
		_require(
			lab.player.is_first_person()
			and lab.player.visual_root.visible
			and not lab.player.visual_root.head.visible
			and lab.player.visual_root.torso.visible,
			"First person must retain a visible body while hiding only the local head"
		)
		_require(
			not lab.foot_button.visible,
			"PATEAR must stay hidden when the ball is out of reach"
		)
		lab.player.add_touch_look(Vector2(70.0, 85.0))
		for frame in 3:
			await physics_frame
		var view_forward := -lab.player.camera_pivot.global_basis.z
		view_forward.y = 0.0
		_require(
			lab.player.get_facing_direction().dot(view_forward.normalized()) > 0.99
			and lab.player.visual_root.head.rotation.x > 0.05,
			"First-person yaw must rotate the body and pitch must pose the head"
		)
		var ball: RigidBody3D = lab.football_host.get_ball() as RigidBody3D
		_require(
			is_instance_valid(ball)
			and is_equal_approx(ball.mass, 0.43)
			and ball.is_in_group(&"kickable_ball"),
			"Football must use one native rigid body"
		)
		if round_index == 0:
			# Home attacks north, therefore its own goal is the south goal.
			lab.player.global_position = Vector3(0.0, 0.02, -2.0)
			for frame in 4:
				await physics_frame
			_require(
				get_nodes_in_group(&"football_goalkeeper_bot").size() == 2,
				"Both goals must contain a goalkeeper bot"
			)
			ball.freeze = true
			ball.global_position = Vector3(0.0, 1.1, -1.55)
			ball.freeze = false
			ball.sleeping = false
			_require(
				lab.player.request_goalkeeper_dive(-1, 1),
				"Goalkeeper dive must start with extended arms"
			)
			for frame in 18:
				await physics_frame
			_require(
				lab.football_host.score == 0
				and lab.football_host.opponent_score == 0,
				"A correctly timed goalkeeper dive must stop the goal"
			)
			lab.player.global_position = Vector3(0.0, 0.02, -38.0)
			for frame in 8:
				await physics_frame
			_require(
				not lab.football_host.is_goalkeeper_in_zone(),
				"Goalkeeper input must remain disabled without player controls"
			)
			lab.player.global_position = Vector3(0.0, 0.02, -12.0)
			for frame in 8:
				await physics_frame

		if round_index == 0:
			# First-person view, body, interaction cast and kick share one heading.
			ball.freeze = true
			ball.global_position = Vector3(0.0, 0.23, -20.0)
			ball.freeze = false
			ball.sleeping = false
			lab.player.global_position = Vector3(0.0, 0.02, -19.0)
			lab.player.velocity = Vector3.ZERO
			lab.player.set_facing_direction(Vector3(0.0, 0.0, -1.0))
			lab.player.set_view_direction(Vector3(0.0, 0.0, -1.0))
			for frame in 4:
				await physics_frame
			_require(
				lab.foot_button.visible,
				"PATEAR must appear only when a ball is truly reachable"
			)
			var kick_origin: Vector3 = ball.global_position
			_require(lab.player.request_foot_action(), "Foot action must start")
			_require(
				lab.player.visual_root.is_kicking(),
				"Local first-person body must play the kick animation"
			)
			for frame in 22:
				await physics_frame
			_require(
				ball.global_position.z < kick_origin.z - 0.12
				and absf(ball.global_position.x - kick_origin.x) < 0.35,
				"Kick must follow body orientation instead of camera yaw"
			)

			# Verify that the side wall returns the ball to the field.
			ball.freeze = true
			ball.global_position = Vector3(11.25, 0.23, -20.0)
			ball.freeze = false
			ball.sleeping = false
			ball.linear_velocity = Vector3(8.0, 0.0, 0.0)
			for frame in 35:
				await physics_frame
			_require(
				ball.linear_velocity.x < 0.0 or ball.global_position.x < 9.1,
				"Rebound wall must keep the ball inside the pitch"
			)

		_require(
			await _force_goal(lab, &"away", 0, 1),
			"South goal must count for the rival"
		)
		_require(
			await _wait_for_ball_reset(lab),
			"After a goal the ball must fall again from the centre"
		)
		_require(
			lab.player.global_position.distance_to(
				Vector3(0.0, 0.02, -12.0)
			) < 0.08,
			"After a goal the player must return to the kickoff spawn"
		)
		for target_score in range(1, 4):
			_require(
				await _force_goal(lab, &"home", target_score, 1),
				"North goal must count for the local player"
			)

		var completed := await _wait_for_phase(
			lab,
			LocalRoundController.Phase.IDLE,
			180
		)
		lab.round_controller.phase_changed.disconnect(collect_phase)
		lab.round_controller.phase_time_changed.disconnect(collect_time)
		_require(completed, "Match must finish after three local goals")
		_require(phases == expected_phases, "Round phases must follow the official order")
		_require(
			countdown_steps == PackedInt32Array([3, 2, 1]),
			"Countdown must visibly advance through 3, 2 and 1"
		)
		_require(
			countdown_titles.size() == 3
			and countdown_titles[0].ends_with("3")
			and countdown_titles[1].ends_with("2")
			and countdown_titles[2].ends_with("1"),
			"Countdown HUD title must render each live step"
		)
		_require(
			lab.football_host.score == 3
			and lab.football_host.opponent_score == 1
			and lab.football_host.get_winner() == 1,
			"Result must retain local 3-1 classification through cleanup"
		)
		_require(
			not lab.player.is_first_person()
			and lab.map_host.get_mounted_node_count() == 0
			and get_nodes_in_group(&"local_round_object").is_empty(),
			"Cleanup must restore third person and remove the complete pitch"
		)
		await process_frame
		_require(
			get_node_count() == baseline_nodes,
			"Repeated matches must return to the exact island baseline"
		)

	_require(lab.start_reference_round(9001), "Cancellation probe must start")
	_require(
		await _wait_for_phase(lab, LocalRoundController.Phase.ACTIVE, 180),
		"Cancellation probe must reach active football"
	)
	lab.reset_lab()
	for frame in 90:
		await physics_frame
	_require(
		lab.round_controller.phase == LocalRoundController.Phase.IDLE
		and not lab.player.is_first_person()
		and lab.map_host.get_mounted_node_count() == 0
		and get_node_count() == baseline_nodes,
		"Interrupted match must stay clean after old timers expire"
	)
	print(
		"LOCAL_FOOTBALL_OK repeats=8 score=3-1 baseline_nodes=%d phases=%d"
		% [baseline_nodes, expected_phases.size()]
	)
	quit(1 if _failed else 0)


func _force_goal(
	lab: LocalDevelopmentLab,
	scoring_side: StringName,
	expected_home: int,
	expected_away: int
) -> bool:
	var ready_frames := 0
	while not lab.football_host.is_ball_ready() and ready_frames < 90:
		await physics_frame
		ready_frames += 1
	var ball: RigidBody3D = lab.football_host.get_ball() as RigidBody3D
	if not is_instance_valid(ball):
		return false
	ball.freeze = true
	ball.global_position = Vector3(
		0.0,
		1.0,
				-38.45 if scoring_side == &"home" else -1.55
	)
	ball.linear_velocity = Vector3.ZERO
	ball.angular_velocity = Vector3.ZERO
	ball.freeze = false
	ball.sleeping = false
	for frame in 60:
		await physics_frame
		if (
			lab.football_host.score >= expected_home
			and lab.football_host.opponent_score >= expected_away
		):
			return true
	return false


func _wait_for_ball_reset(lab: LocalDevelopmentLab) -> bool:
	var ball: RigidBody3D = lab.football_host.get_ball() as RigidBody3D
	for frame in 90:
		await physics_frame
		if (
			lab.football_host.is_ball_ready()
			and is_instance_valid(ball)
			and ball.global_position.distance_to(
				Vector3(0.0, ball.global_position.y, -20.0)
			) < 0.08
		):
			return true
	return false


func _wait_for_phase(
	lab: LocalDevelopmentLab,
	target: LocalRoundController.Phase,
	max_frames: int
) -> bool:
	for frame in max_frames:
		if lab.round_controller.phase == target:
			return true
		await physics_frame
	return lab.round_controller.phase == target


func _require(condition: bool, message: String) -> void:
	if condition:
		return
	_failed = true
	push_error("LOCAL_FOOTBALL_FAIL: " + message)
