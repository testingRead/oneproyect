extends SceneTree

const LAB_SCENE := preload("res://scenes/local/local_lab.tscn")
const TORNADO_MAP: MinigameMapDefinition = preload("res://data/maps/tornado_isla.tres")

var _failed := false


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	ProjectSettings.set_setting("oneproyect/session_minigame_path", "res://data/minigames/tornado_supervivencia.tres")
	ProjectSettings.set_setting("oneproyect/session_auto_start", false)
	_require(TORNADO_MAP.supports_minigame(&"tornado_supervivencia"), "Tornado map must declare its minigame")
	var lab := LAB_SCENE.instantiate() as LocalDevelopmentLab
	root.add_child(lab)
	await process_frame
	lab.round_controller.duration_multiplier = 0.05
	var baseline_nodes := get_node_count()
	_require(lab.start_reference_round(6601), "Tornado match must start")
	_require(await _wait_for_phase(lab, LocalRoundController.Phase.ACTIVE, 180), "Tornado must reach active")
	_require(
		not lab.player.is_first_person()
		and not lab.player.is_top_down_mode()
		and not lab.foot_button.visible
		and not lab.crosshair.visible,
		"Tornado must keep third-person movement without football controls"
	)
	_require(get_nodes_in_group(&"tornado_hazard").size() == 1, "Arena must mount tornado")
	_require(get_nodes_in_group(&"tornado_loose_object").size() == 12, "Arena must mount physical objects")
	var tornado_position: Vector3 = lab.tornado_host.get_hazard_position()
	lab.player.global_position = tornado_position + Vector3(1.4, 0.02, 0.0)
	var maximum_external_speed := 0.0
	for frame in 55:
		await physics_frame
		maximum_external_speed = maxf(
			maximum_external_speed,
			lab.player.get_external_horizontal_speed()
		)
	_require(lab.player.get_local_health() < 100, "Tornado core must damage player")
	_require(
		maximum_external_speed <= 5.25,
		"Continuous tornado force must remain capped instead of accumulating"
	)
	# Leaving the influence must restore normal control in about one second;
	# there is deliberately no stun state in this minigame.
	lab.player.global_position = Vector3(13.0, 0.02, -8.0)
	for frame in 65:
		await physics_frame
	_require(
		lab.player.get_external_horizontal_speed() < 0.25,
		"Tornado wall impacts must not leave a multi-second movement lock"
	)
	_require(await _wait_for_phase(lab, LocalRoundController.Phase.IDLE, 320), "Tornado must clean up")
	_require(get_node_count() == baseline_nodes, "Tornado cleanup must return to baseline")
	print(
		"TORNADO_ROUND_OK health=%d peak_external=%.2f baseline_nodes=%d"
		% [lab.player.get_local_health(), maximum_external_speed, baseline_nodes]
	)
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
		push_error("TORNADO_ROUND_FAIL: %s" % message)
