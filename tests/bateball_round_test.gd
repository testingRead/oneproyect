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
	lab.round_controller.duration_multiplier = 0.11
	var baseline_nodes := get_node_count()
	_require(lab.start_reference_round(7701), "Bateball must start")
	_require(await _wait_for_phase(lab, LocalRoundController.Phase.ACTIVE, 180), "Bateball must reach active")
	_require(lab.player.is_top_down_mode(), "Bateball must use top-down camera")
	_require(
		not lab.player.is_first_person()
		and not lab.foot_button.visible
		and not lab.hand_button.visible
		and not lab.crosshair.visible,
		"Bateball must expose only its right-pad aim action"
	)
	var camera_pitch := lab.player.camera_pivot.rotation.x
	_require(camera_pitch < -0.6 and camera_pitch > -1.25, "Arena camera must be elevated and oblique")
	for frame in 3:
		await physics_frame
	_require(lab.player.get_meta(&"bateball_team") == &"home", "Slot zero must join home")
	_require(rival.get_meta(&"bateball_team") == &"away", "Slot one must join away")
	_require(lab.player.global_position.z > rival.global_position.z, "Opposing teams must spawn on opposing halves")
	var unique_spawns: Dictionary = {}
	for slot in 8:
		var spawn: Transform3D = lab.map_host.get_spawn_transform(slot)
		unique_spawns[spawn.origin] = true
		_require(
			lab.map_host.get_team_for_slot(slot) == (&"home" if posmod(slot, 2) == 0 else &"away"),
			"Bateball team assignment must alternate for every slot"
		)
	_require(unique_spawns.size() == 8, "Bateball must provide eight unique 4v4 spawns")
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
	_require(lab.bateball_host.get_holder_name() == "JUGADOR", "Player must collect ball")
	lab.player.request_bat_swing()
	for frame in 238:
		await physics_frame
	_require(lab.player.get_bat_charge_ratio() > 0.9, "Bat must charge after three seconds")
	var press := InputEventScreenTouch.new()
	press.index = 7
	press.pressed = true
	press.position = lab.look_pad.global_position + Vector2(130.0, 180.0)
	lab.look_pad._input(press)
	var drag := InputEventScreenDrag.new()
	drag.index = 7
	drag.position = press.position + Vector2(90.0, 0.0)
	drag.relative = Vector2(90.0, 0.0)
	lab.look_pad._input(drag)
	await process_frame
	lab._update_aim_guide()
	_require(lab.player.get_top_down_aim_direction().dot(Vector3.RIGHT) > 0.95, "Right pad must aim the character")
	_require(lab._aim_line.visible, "Dragging must show the trajectory guide")
	var release := InputEventScreenTouch.new()
	release.index = 7
	release.pressed = false
	release.position = drag.position
	lab.look_pad._input(release)
	_require(not lab.bateball_host.is_holder(lab.player), "Releasing aim must shoot the held ball")
	_require(lab.banner_detail.text.begins_with("BALÓN SUELTO"), "HUD must identify a loose Bateball")
	var ball: RigidBody3D = lab.bateball_host.get_ball() as RigidBody3D
	_require(ball.linear_velocity.length() < 7.2, "Bateball shot must not cross the full field at excessive speed")
	_require(
		ball.physics_material_override != null
		and ball.physics_material_override.bounce >= 0.8
		and ball.physics_material_override.friction <= 0.1
		and ball.linear_damp <= 0.15,
		"Bateball must preserve useful speed when rebounding from arena walls"
	)
	# A charged hit on the carrier must create a readable contest: the rival is
	# pushed across the floor and the ball drops nearby instead of being fired.
	lab.player.reset_to_spawn()
	lab.player.global_position = Vector3(-1.0, 0.02, -20.0)
	rival.reset_to_spawn()
	rival.global_position = Vector3(1.0, 0.02, -20.0)
	lab.player.force_update_transform()
	rival.force_update_transform()
	rival.set_authoritative_health(100)
	lab.bateball_host.apply_authoritative_holder(rival)
	lab.player.set_facing_direction(Vector3.RIGHT)
	# Teleports update the visible transforms immediately, but CharacterBody3D
	# motion recovery can still use the previous physics transform in the same
	# tick. Settle both bodies before testing an actual gameplay hit; otherwise
	# the test manufactures a vertical recovery that cannot follow user input.
	for settle_frame in 2:
		await physics_frame
	var rival_before_hit := rival.global_position
	lab.player.perform_network_bat_swing(true)
	for frame in 18:
		await physics_frame
	var rival_displacement := Vector2(
		rival.global_position.x - rival_before_hit.x,
		rival.global_position.z - rival_before_hit.z
	).length()
	_require(not lab.bateball_host.is_holder(rival), "Charged bat must dislodge the ball carrier")
	_require(rival_displacement > 0.25 and rival_displacement < 2.5, "Charged bat push must be controlled")
	_require(
		rival.global_position.y < 0.35,
		"Charged bat must not launch the rival vertically (y=%.3f vy=%.3f)"
		% [rival.global_position.y, rival.velocity.y]
	)
	_require(
		ball.linear_velocity.length() < 2.0,
		"Dislodged ball must drop instead of being launched (velocity=%s)"
		% [ball.linear_velocity]
	)
	# Keep the old carrier over a stationary loose ball to verify that the
	# personal lockout, rather than incidental distance, prevents instant pickup.
	lab.player.global_position = Vector3(-6.0, 0.02, -20.0)
	rival.set_physics_process(false)
	ball.freeze = true
	rival.global_position = ball.global_position - Vector3.UP * ball.global_position.y
	for frame in 12:
		await physics_frame
	_require(not lab.bateball_host.is_holder(rival), "Dislodged carrier must not instantly reclaim the ball")
	for frame in 36:
		await physics_frame
	_require(lab.bateball_host.is_holder(rival), "Carrier may reclaim the ball after the short lockout")
	lab.bateball_host.apply_authoritative_holder(null)
	rival.set_physics_process(true)
	rival.reset_to_spawn()
	rival.set_authoritative_health(8)
	lab.player.global_position = Vector3(-0.5, 0.02, -20.0)
	rival.global_position = Vector3(1.0, 0.02, -20.0)
	lab.player.force_update_transform()
	rival.force_update_transform()
	for settle_frame in 2:
		await physics_frame
	lab.bateball_host.apply_authoritative_holder(rival)
	lab.player.set_facing_direction(Vector3.RIGHT)
	lab.player.perform_network_bat_swing(false)
	for frame in 18:
		await physics_frame
	_require(rival.get_local_health() == 0, "Bat damage must eliminate a low-health rival")
	_require(not lab.bateball_host.is_holder(rival), "Eliminated carrier must release the ball")
	for frame in 130:
		await physics_frame
	_require(
		rival.get_local_health() == 100
		and rival.global_position.distance_to(Vector3(0.0, 0.02, -34.0)) < 0.2,
		"Eliminated Bateball players must respawn at their team spawn"
	)
	_require(ball.global_position.distance_to(lab.player.global_position) > 0.6, "Shot must start beyond the player collider")
	# A real rigid-body rebound must preserve play instead of dying at the wall.
	lab.bateball_host.apply_authoritative_holder(null)
	lab.player.global_position = Vector3(-10.0, 0.02, -10.0)
	rival.global_position = Vector3(10.0, 0.02, -30.0)
	ball.freeze = false
	ball.global_position = Vector3(13.7, 0.28, -20.0)
	ball.linear_velocity = Vector3(7.0, 0.0, 0.0)
	ball.angular_velocity = Vector3.ZERO
	var wall_rebound_speed := 0.0
	for frame in 18:
		await physics_frame
		if ball.linear_velocity.x < 0.0:
			wall_rebound_speed = maxf(wall_rebound_speed, -ball.linear_velocity.x)
	_require(
		wall_rebound_speed > 4.5,
		"Bateball wall rebound must retain useful speed (rebound=%.2f)"
		% wall_rebound_speed
	)
	lab.bateball_host.apply_authoritative_holder(null)
	ball.global_position = Vector3(20.0, 0.4, -20.0)
	for frame in 3:
		await physics_frame
	_require(absf(ball.global_position.x) < 15.0, "Escaped ball must reset inside the arena")
	_require(
		ball.collision_layer == 1 and ball.collision_mask == 1,
		"Ball reset must always restore its physical collisions"
	)
	for frame in 52:
		await physics_frame
	_require(not ball.freeze, "Ball reset must resume physics while the match remains active")
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
