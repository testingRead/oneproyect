extends SceneTree

const LAB_SCENE := preload("res://scenes/local/local_lab.tscn")
const BATEBALL_MAP: MinigameMapDefinition = preload("res://data/maps/bateball_arena.tres")

var _failed := false


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	ProjectSettings.set_setting("oneproyect/session_minigame_path", "res://data/minigames/bateball_arena.tres")
	ProjectSettings.set_setting("oneproyect/session_auto_start", false)
	_require(BATEBALL_MAP.supports_minigame(&"bateball_arena"), "Bateball map must declare its minigame")
	var lab := LAB_SCENE.instantiate() as LocalDevelopmentLab
	root.add_child(lab)
	await process_frame
	lab.round_controller.duration_multiplier = 0.05
	var baseline_nodes := get_node_count()
	_require(lab.start_reference_round(7701), "Bateball must start")
	_require(await _wait_for_phase(lab, LocalRoundController.Phase.ACTIVE, 180), "Bateball must reach active")
	_require(lab.player.is_top_down_mode(), "Bateball must use top-down camera")
	var camera_pitch := lab.player.camera_pivot.rotation.x
	_require(camera_pitch < -0.6 and camera_pitch > -1.25, "Arena camera must be elevated and oblique")
	lab.player.global_position = Vector3(0.0, 0.02, -20.0)
	for frame in 10:
		await physics_frame
	_require(lab.bateball_host.get_holder_name() == "CharacterRoot", "Player must collect ball")
	lab.player.request_bat_swing()
	for frame in 238:
		await physics_frame
	_require(lab.player.get_bat_charge_ratio() > 0.9, "Bat must charge after three seconds")
	var press := InputEventScreenTouch.new()
	press.index = 7
	press.pressed = true
	press.position = lab.look_pad.global_position + Vector2(130.0, 180.0)
	lab.look_pad._gui_input(press)
	var drag := InputEventScreenDrag.new()
	drag.index = 7
	drag.position = press.position + Vector2(90.0, 0.0)
	drag.relative = Vector2(90.0, 0.0)
	lab.look_pad._gui_input(drag)
	await process_frame
	lab._update_aim_guide()
	_require(lab.player.get_top_down_aim_direction().dot(Vector3.RIGHT) > 0.95, "Right pad must aim the character")
	_require(lab._aim_line.visible, "Dragging must show the trajectory guide")
	var release := InputEventScreenTouch.new()
	release.index = 7
	release.pressed = false
	release.position = drag.position
	lab.look_pad._gui_input(release)
	_require(not lab.bateball_host.is_holder(lab.player), "Releasing aim must shoot the held ball")
	_require(await _wait_for_phase(lab, LocalRoundController.Phase.IDLE, 600), "Bateball must clean up")
	_require(get_node_count() == baseline_nodes, "Bateball cleanup must return to baseline")
	print("BATEBALL_ROUND_OK baseline_nodes=%d" % baseline_nodes)
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
		push_error("BATEBALL_ROUND_FAIL: %s" % message)
