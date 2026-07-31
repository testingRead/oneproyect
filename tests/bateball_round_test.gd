extends SceneTree

const LAB_SCENE := preload("res://scenes/local/local_lab.tscn")
const BATEBALL_MAP: MinigameMapDefinition = preload("res://data/maps/bateball_arena.tres")
const BASE_CHARACTER_SCENE := preload("res://scenes/local/base_character.tscn")

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
	var rival := BASE_CHARACTER_SCENE.instantiate() as LocalBaseCharacter
	rival.name = "RivalProbe"
	rival.controls_enabled = false
	rival.emit_metrics = false
	rival.set_meta(&"display_name", "Rival")
	rival.set_meta(&"lan_slot", 1)
	var rival_camera := rival.get_node("CameraPivot/SpringArm/Camera") as Camera3D
	rival_camera.current = false
	lab.get_node("World").add_child(rival)
	rival.set_physics_process(false)
	lab.round_controller.duration_multiplier = 0.05
	var baseline_nodes := get_node_count()
	_require(lab.start_reference_round(7701), "Bateball must start")
	_require(await _wait_for_phase(lab, LocalRoundController.Phase.ACTIVE, 180), "Bateball must reach active")
	_require(lab.player.is_top_down_mode(), "Bateball must use top-down camera")
	var camera_pitch := lab.player.camera_pivot.rotation.x
	_require(camera_pitch < -0.6 and camera_pitch > -1.25, "Arena camera must be elevated and oblique")
	for frame in 3:
		await physics_frame
	_require(lab.player.get_meta(&"bateball_team") == &"home", "Slot zero must join home")
	_require(rival.get_meta(&"bateball_team") == &"away", "Slot one must join away")
	_require(lab.player.global_position.z > rival.global_position.z, "Opposing teams must spawn on opposing halves")
	var right_socket := lab.player.visual_root.get_node("Model/RightArmPivot/ItemSocket") as Node3D
	var left_arm := lab.player.visual_root.get_node("Model/LeftArmPivot") as Node3D
	_require(
		lab.player.visual_root.to_local(right_socket.global_position).x
		< lab.player.visual_root.to_local(left_arm.global_position).x,
		"Bat socket must be on anatomical right"
	)
	_require(right_socket.get_node_or_null("ArenaBat") != null, "Bat must be equipped in the right hand")
	rival.update_remote_presentation(0.1, Vector3(4.5, 0.0, 0.0), 0.4)
	_require(rival.get_movement_ratio() > 0.5, "Remote velocity must drive locomotion animation")
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
	var ball: RigidBody3D = lab.bateball_host.get_ball() as RigidBody3D
	_require(ball.global_position.distance_to(lab.player.global_position) > 0.6, "Shot must start beyond the player collider")
	ball.global_position = Vector3(20.0, 0.4, -20.0)
	for frame in 3:
		await physics_frame
	_require(absf(ball.global_position.x) < 15.0, "Escaped ball must reset inside the arena")
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
