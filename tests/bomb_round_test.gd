extends SceneTree

const LAB_SCENE := preload("res://scenes/local/local_lab.tscn")
const BOMB_MAP: MinigameMapDefinition = preload("res://data/maps/bomba_relevo.tres")

var _failed := false


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	ProjectSettings.set_setting("oneproyect/session_minigame_path", "res://data/minigames/bomba_relevo.tres")
	ProjectSettings.set_setting("oneproyect/session_auto_start", false)
	_require(BOMB_MAP.supports_minigame(&"bomba_relevo"), "Bomb map must declare its minigame")
	var lab := LAB_SCENE.instantiate() as LocalDevelopmentLab
	root.add_child(lab)
	await process_frame
	lab.round_controller.duration_multiplier = 0.02
	var baseline_nodes := get_node_count()
	_require(lab.start_reference_round(5501), "Bomb match must start from the room definition")
	_require(await _wait_for_phase(lab, LocalRoundController.Phase.ACTIVE, 180), "Bomb match must reach active")
	var mounted := lab.map_host.get_node_or_null("MountedMap")
	_require(
		mounted != null and get_nodes_in_group(&"bomb_collectible").size() == 1,
		"Bomb arena must mount a bomb"
	)
	_require(lab.bomb_host.get_holder_name() == "CharacterRoot", "Local player must begin holding the bomb")
	_require(await _wait_for_phase(lab, LocalRoundController.Phase.IDLE, 280), "Bomb match must explode, clean up, and return idle")
	_require(get_node_count() == baseline_nodes, "Bomb cleanup must return to baseline")
	print("BOMB_ROUND_OK holder=CharacterRoot baseline_nodes=%d" % baseline_nodes)
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
		push_error("BOMB_ROUND_FAIL: %s" % message)
