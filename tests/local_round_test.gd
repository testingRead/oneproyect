extends SceneTree

const LAB_SCENE := preload("res://scenes/local/local_lab.tscn")
const LAB_MAP: MinigameMapDefinition = preload("res://data/maps/campo_futbol_local.tres")

var _failed := false


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_require(not root.has_node("Network"), "Local rounds must not create Network")
	_require(
		LAB_MAP.supports_minigame(&"futbol_practica")
		and LAB_MAP.supports_minigame(&"penales")
		and LAB_MAP.compatible_disasters.is_empty(),
		"Football map must declare only its compatible local game modes"
	)
	_require(
		LAB_MAP.map_scene != null
		and LAB_MAP.footprint == Vector2(22.0, 34.0)
		and LAB_MAP.spawn_points.size() == 5,
		"Football map must package one scene, footprint and five spawns"
	)
	_require(
		LAB_MAP.available_objects == PackedStringArray(
			["balon_futbol", "porteria", "vallas"]
		),
		"Football definition must declare its reusable physical objects"
	)
	_require(
		LAB_MAP.variation_signature(4242)
		== LAB_MAP.variation_signature(4242),
		"One seed must always produce the same football layout"
	)

	var lab := LAB_SCENE.instantiate() as LocalDevelopmentLab
	root.add_child(lab)
	await process_frame
	for frame in 20:
		await physics_frame
	lab.round_controller.duration_multiplier = 0.08
	_require(
		LAB_MAP.boundary_policy
		== MinigameMapDefinition.BoundaryPolicy.ISLAND_SHORE
		and not lab.playable_area.are_physical_walls_enabled(),
		"Football must use its visible fences without a second invisible wall"
	)
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
		var collect_phase := func(
			next_phase: LocalRoundController.Phase,
			_label: String,
			_seconds: float
		) -> void:
			phases.append(next_phase)
		lab.round_controller.phase_changed.connect(collect_phase)
		_require(
			lab.start_reference_round(1000 + round_index * 37),
			"Idle lab must accept a football round"
		)
		await physics_frame
		var mounted := lab.map_host.get_node_or_null("MountedMap")
		_require(
			mounted is Node3D
			and mounted.has_node("Pitch")
			and mounted.has_node("Football")
			and mounted.has_node("TargetGoal")
			and lab.map_host.get_mounted_node_count() > 30,
			"Round must mount the packaged pitch, physical ball and goal"
		)
		_require(
			lab.player.is_first_person()
			and not lab.playable_area.are_physical_walls_enabled(),
			"Football must enable first-person view without an inner area wall"
		)
		_require(
			await _wait_for_phase(
				lab,
				LocalRoundController.Phase.ACTIVE,
				180
			),
			"Football must reach its active phase"
		)
		var ball: RigidBody3D = (
			lab.football_host.get_ball() as RigidBody3D
		)
		_require(
			ball is RigidBody3D
			and is_equal_approx(ball.mass, 0.43)
			and ball.is_in_group(&"kickable_ball"),
			"Football must use one native rigid body with its declared mass"
		)
		if round_index == 0:
			lab.player.global_position = Vector3(0.0, 0.02, -12.0)
			lab.player.velocity = Vector3.ZERO
			var ball_origin: Vector3 = ball.global_position
			_require(
				lab.player.request_foot_action(),
				"Foot action must start independently in football"
			)
			for frame in 18:
				await physics_frame
			_require(
				ball.global_position.distance_to(ball_origin) > 0.12,
				"A real foot contact must move the native physics ball"
			)
		for target_score in range(1, 4):
			_require(
				await _force_goal(lab, target_score),
				"Goal area must count and reset the physical ball"
			)
		var completed := await _wait_for_phase(
			lab,
			LocalRoundController.Phase.IDLE,
			180
		)
		lab.round_controller.phase_changed.disconnect(collect_phase)
		_require(completed, "Football round must finish after its third goal")
		_require(phases == expected_phases, "Round phases must follow the official order")
		_require(
			lab.football_host.score == 3,
			"Football result must retain three goals through cleanup"
		)
		_require(
			not lab.player.is_first_person()
			and not lab.playable_area.are_physical_walls_enabled(),
			"Cleanup must restore third person and the open island laboratory"
		)
		_require(
			lab.map_host.get_mounted_node_count() == 0
			and lab.event_host.get_active_count() == 0
			and get_nodes_in_group(&"local_round_object").is_empty(),
			"Round cleanup must remove pitch, ball and active objects"
		)
		await process_frame
		_require(
			get_node_count() == baseline_nodes,
			"Repeated football rounds must return to the exact baseline node count"
		)

	# A manual reset must invalidate timers and restore the camera immediately.
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
		"Interrupted football must stay clean after old timers expire"
	)
	print(
		"LOCAL_FOOTBALL_OK repeats=8 score=3 baseline_nodes=%d phases=%d"
		% [baseline_nodes, expected_phases.size()]
	)
	quit(1 if _failed else 0)


func _force_goal(lab: LocalDevelopmentLab, expected_score: int) -> bool:
	var ready_frames := 0
	while not lab.football_host.is_ball_ready() and ready_frames < 90:
		await physics_frame
		ready_frames += 1
	var ball: RigidBody3D = lab.football_host.get_ball() as RigidBody3D
	if not is_instance_valid(ball):
		return false
	ball.freeze = true
	ball.global_position = Vector3(0.0, 1.0, -35.45)
	ball.linear_velocity = Vector3.ZERO
	ball.angular_velocity = Vector3.ZERO
	ball.freeze = false
	ball.sleeping = false
	for frame in 60:
		await physics_frame
		if lab.football_host.score >= expected_score:
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
