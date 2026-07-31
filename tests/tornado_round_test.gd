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
	lab.round_controller.duration_multiplier = 0.02
	var baseline_nodes := get_node_count()
	_require(lab.start_reference_round(6601), "Tornado match must start")
	_require(await _wait_for_phase(lab, LocalRoundController.Phase.ACTIVE, 180), "Tornado must reach active")
	_require(get_nodes_in_group(&"tornado_hazard").size() == 1, "Arena must mount tornado")
	_require(get_nodes_in_group(&"tornado_loose_object").size() == 12, "Arena must mount physical objects")
	lab.player.global_position = Vector3(0.0, 0.02, -20.0)
	for frame in 70:
		await physics_frame
	_require(lab.player.get_local_health() < 100, "Tornado core must damage player")
	_require(await _wait_for_phase(lab, LocalRoundController.Phase.IDLE, 320), "Tornado must clean up")
	_require(get_node_count() == baseline_nodes, "Tornado cleanup must return to baseline")
	print("TORNADO_ROUND_OK health=%d baseline_nodes=%d" % [lab.player.get_local_health(), baseline_nodes])
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
