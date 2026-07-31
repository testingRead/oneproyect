extends SceneTree

const LAB_SCENE := preload("res://scenes/local/local_lab.tscn")
const CROWN_MAP: MinigameMapDefinition = preload("res://data/maps/corona_central.tres")
const BASE_CHARACTER_SCENE := preload("res://scenes/local/base_character.tscn")

var _failed := false


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	ProjectSettings.set_setting("oneproyect/session_minigame_path", "res://data/minigames/corona_central.tres")
	ProjectSettings.set_setting("oneproyect/session_auto_start", false)
	_require(CROWN_MAP.supports_minigame(&"corona_central"), "Crown map must declare its minigame")
	var lab := LAB_SCENE.instantiate() as LocalDevelopmentLab
	root.add_child(lab)
	await process_frame
	var rival := BASE_CHARACTER_SCENE.instantiate() as LocalBaseCharacter
	rival.controls_enabled = false
	rival.emit_metrics = false
	rival.set_meta(&"display_name", "Rival")
	rival.set_meta(&"lan_slot", 1)
	(rival.get_node("CameraPivot/SpringArm/Camera") as Camera3D).current = false
	lab.get_node("World").add_child(rival)
	rival.set_physics_process(false)
	rival.global_position = Vector3(10.0, 0.02, -20.0)
	lab.round_controller.duration_multiplier = 0.04
	var baseline_nodes := get_node_count()
	_require(lab.start_reference_round(4401), "Crown match must start from the room definition")
	_require(await _wait_for_phase(lab, LocalRoundController.Phase.ACTIVE, 180), "Crown match must reach active")
	var mounted := lab.map_host.get_node_or_null("MountedMap")
	_require(mounted != null and mounted.has_node("Crown"), "Crown arena must mount the central crown")
	lab.player.global_position = Vector3(0.0, 0.02, -20.0)
	for frame in 12:
		await physics_frame
	_require(lab.crown_host.get_holder_name() == "JUGADOR", "Touching crown must equip it")
	rival.global_position = lab.player.global_position
	for frame in 12:
		await physics_frame
	_require(
		lab.crown_host.get_holder_name() == "JUGADOR",
		"Overlapping players must not bounce the crown immediately"
	)
	for frame in 44:
		await physics_frame
	_require(
		lab.crown_host.get_holder_name() == "Rival",
		"A nearby rival must steal after cooldown (holder=%s distance=%.2f phase=%s)" % [
			lab.crown_host.get_holder_name(),
			rival.global_position.distance_to(lab.player.global_position),
			lab.round_controller.get_phase_name(),
		]
	)
	_require(await _wait_for_phase(lab, LocalRoundController.Phase.IDLE, 240), "Crown match must clean up")
	_require(get_node_count() == baseline_nodes, "Crown cleanup must return to baseline")
	print("CROWN_ROUND_OK holder=JUGADOR baseline_nodes=%d" % baseline_nodes)
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
		push_error("CROWN_ROUND_FAIL: %s" % message)
