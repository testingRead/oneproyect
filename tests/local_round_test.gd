extends SceneTree

const LAB_SCENE := preload("res://scenes/local/local_lab.tscn")
const LAB_MAP: MinigameMapDefinition = preload("res://data/maps/isla_laboratorio.tres")

var _failed := false


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_require(not root.has_node("Network"), "Local rounds must not create Network")
	_require(
		LAB_MAP.supports_disaster(&"meteorito")
		and LAB_MAP.supports_minigame(&"laboratorio_local"),
		"MapDefinition must declare compatible disasters and minigames"
	)
	_require(
		LAB_MAP.available_objects == PackedStringArray(
			["caja_ligera", "caja_pesada", "puerta"]
		),
		"MapDefinition must declare its available objects"
	)
	var repeated_signature := LAB_MAP.variation_signature(4242)
	_require(
		repeated_signature == LAB_MAP.variation_signature(4242),
		"One seed must always produce the same modular layout"
	)

	var lab := LAB_SCENE.instantiate() as LocalDevelopmentLab
	root.add_child(lab)
	await process_frame
	for frame in 20:
		await physics_frame
	lab.round_controller.duration_multiplier = 0.12
	_require(
		LAB_MAP.boundary_policy
		== MinigameMapDefinition.BoundaryPolicy.ISLAND_SHORE
		and not lab.playable_area.are_physical_walls_enabled(),
		"Island rounds must use logical event bounds without inner physical walls"
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
	var saw_distinct_layout := false
	var first_signature := PackedByteArray()
	for round_index in 8:
		var phases := PackedInt32Array()
		var collect_phase := func(
			phase: LocalRoundController.Phase,
			_label: String,
			_seconds: float
		) -> void:
			phases.append(phase)
		lab.round_controller.phase_changed.connect(collect_phase)
		var seed := 1000 + round_index * 37
		_require(lab.start_reference_round(seed), "Idle lab must accept a round")
		var completed := false
		var elapsed_frames := 0
		while elapsed_frames < 240:
			await physics_frame
			elapsed_frames += 1
			if lab.round_controller.phase == LocalRoundController.Phase.IDLE:
				completed = true
				break
		lab.round_controller.phase_changed.disconnect(collect_phase)
		_require(completed, "Local round must complete within its bounded duration")
		_require(phases == expected_phases, "Round phases must follow the official order")
		_require(
			lab.event_host.get_impact_count() > 0,
			"Reference meteor must spawn, move and impact the island"
		)
		_require(
			lab.map_host.get_mounted_node_count() == 0
			and lab.event_host.get_active_count() == 0
			and get_nodes_in_group(&"local_round_object").is_empty(),
			"Round cleanup must remove its map, objects and active event"
		)
		await process_frame
		_require(
			get_node_count() == baseline_nodes,
			"Repeated rounds must return to the exact baseline node count"
		)
		var signature := LAB_MAP.variation_signature(seed)
		if round_index == 0:
			first_signature = signature
		elif signature != first_signature:
			saw_distinct_layout = true
	_require(saw_distinct_layout, "Different seeds must vary at least one modular slot")

	# A manual reset must invalidate all pending timers from the interrupted run.
	_require(lab.start_reference_round(9001), "Cancellation probe must start")
	while lab.round_controller.phase != LocalRoundController.Phase.ACTIVE:
		await physics_frame
	lab.reset_lab()
	for frame in 90:
		await physics_frame
	_require(
		lab.round_controller.phase == LocalRoundController.Phase.IDLE
		and lab.map_host.get_mounted_node_count() == 0
		and lab.event_host.get_active_count() == 0
		and get_node_count() == baseline_nodes,
		"Interrupted round must remain clean after old timers expire"
	)
	print(
		"LOCAL_ROUND_OK repeats=8 pool=%d baseline_nodes=%d phases=%d"
		% [lab.event_host.get_pool_size(), baseline_nodes, expected_phases.size()]
	)
	quit(1 if _failed else 0)


func _require(condition: bool, message: String) -> void:
	if condition:
		return
	_failed = true
	push_error("LOCAL_ROUND_FAIL: " + message)
