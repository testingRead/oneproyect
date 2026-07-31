extends SceneTree

const SCALE := preload("res://shared/gameplay_scale.gd")
const BOOTSTRAP := preload("res://scripts/bootstrap.gd")
const LAB_SCENE := preload("res://scenes/local/local_lab.tscn")
const CHARACTER_SCENE := preload("res://scenes/local/base_character.tscn")

var _failed := false


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_require(
		BOOTSTRAP.is_local_development(["--local-development"]),
		"LOCAL_DEVELOPMENT must have one explicit command-line switch"
	)
	_require(not root.has_node("Network"), "Local base must not create Network")
	_require(
		is_equal_approx(SCALE.CHARACTER_HEIGHT, 1.8)
		and is_equal_approx(SCALE.CHARACTER_MASS, 70.0)
		and is_equal_approx(SCALE.COLLISION_HEIGHT, 1.72)
		and is_equal_approx(SCALE.COLLISION_RADIUS, 0.34),
		"Character scale must come from the official contract"
	)
	_require(
		is_equal_approx(
			SCALE.JUMP_VELOCITY,
			sqrt(2.0 * SCALE.GRAVITY * SCALE.JUMP_HEIGHT)
		),
		"Jump velocity must be derived from gravity and official jump height"
	)

	var lab := LAB_SCENE.instantiate() as LocalDevelopmentLab
	root.add_child(lab)
	await process_frame
	for frame in 40:
		await physics_frame
	var player := lab.player
	_require(
		lab.get_meta(&"runtime_mode") == &"LOCAL_DEVELOPMENT",
		"Lab must declare its runtime mode"
	)
	_require(
		lab.get_active_dynamic_object_count() == 0
		and lab.get_node_or_null("World/ScaleReferences") == null
		and lab.get_node_or_null("World/TestCourse") == null,
		"The old laboratory course must not exist in the football scene"
	)
	_require(
		lab.playable_area.get_wall_count() == 4
		and not lab.playable_area.are_physical_walls_enabled(),
		"Island mode keeps optional inner walls disabled"
	)
	_require(
		lab.get_diagnostics().shore_boundaries == 4,
		"The island shore must remain the permanent physical boundary"
	)
	_require(
		player.has_node("Collision")
		and player.has_node("VisualRoot/Model")
		and player.has_node("CameraPivot/SpringArm/Camera")
		and player.has_node("AnchorPoints/Feet")
		and player.has_node("AnchorPoints/HeldItem")
		and player.has_node("InteractionContext")
		and player.has_node("InteractionAction"),
		"Character must keep physics, visual, camera and interaction anchors"
	)
	_require(player.is_on_floor(), "Character must settle on the island floor")
	_require(
		absf(player.get_collision_bottom_height()) < 0.035
		and absf(player.get_visual_foot_height()) < 0.035,
		"Visual feet and collision bottom must share the island floor"
	)

	player.set_first_person(true)
	player.add_touch_look(Vector2(64.0, 72.0))
	for frame in 3:
		await physics_frame
	var first_person_forward := -player.camera_pivot.global_basis.z
	first_person_forward.y = 0.0
	_require(
		player.is_first_person()
		and player.visual_root.visible
		and not player.visual_root.head.visible
		and player.visual_root.torso.visible
		and player.get_facing_direction().dot(first_person_forward.normalized()) > 0.99
		and player.visual_root.head.rotation.x > 0.05
		and is_zero_approx(player.spring_arm.spring_length),
		"First person must retain the body and align body/head with the view"
	)
	player.set_first_person(false)
	_require(
		not player.is_first_person()
		and player.visual_root.visible
		and player.visual_root.head.visible
		and is_equal_approx(player.spring_arm.spring_length, 4.8),
		"Third person must restore its official distance"
	)
	var push_probe := CHARACTER_SCENE.instantiate() as LocalBaseCharacter
	push_probe.controls_enabled = false
	push_probe.emit_metrics = false
	(push_probe.get_node("CameraPivot/SpringArm/Camera") as Camera3D).current = false
	lab.get_node("World").add_child(push_probe)
	push_probe.set_physics_process(false)
	player.set_view_direction(Vector3.FORWARD)
	player.set_facing_direction(Vector3.FORWARD)
	push_probe.global_position = player.global_position + Vector3.FORWARD
	for frame in 12:
		await physics_frame
	_require(
		player.is_hand_action_available()
		and player.get_hand_label() == "EMPUJAR"
		and player.request_hand_action()
		and player.visual_root.is_pushing(),
		"A player in front must offer EMPUJAR instead of a false kick"
	)
	push_probe.perform_network_kick(Vector3.FORWARD)
	_require(
		push_probe.visual_root.is_kicking(),
		"Remote kick events must trigger the visible leg animation"
	)
	push_probe.queue_free()
	await process_frame

	var baseline_nodes := get_node_count()
	for index in 12:
		lab.reset_lab()
		lab.set_playable_area_index(index % 3)
		await physics_frame
	_require(
		get_node_count() == baseline_nodes,
		"Resetting the island must not create residual nodes"
	)
	for area_index in 3:
		lab.set_playable_area_index(area_index)
		var expected: float = [
			SCALE.PLAYABLE_AREA_SMALL,
			SCALE.PLAYABLE_AREA_MEDIUM,
			SCALE.PLAYABLE_AREA_LARGE,
		][area_index]
		_require(
			is_equal_approx(lab.playable_area.get_area_size(), expected),
			"Area sizes must remain parameter-only variants"
		)

	lab.set_playable_area_index(0)
	lab.playable_area.set_physical_walls_enabled(true)
	player.global_position = Vector3(13.5, 0.04, 0.0)
	player.velocity = Vector3.ZERO
	player.set_touch_move(Vector2(1.0, 0.0))
	for frame in 90:
		await physics_frame
	player.set_touch_move(Vector2.ZERO)
	_require(
		player.global_position.x <= 14.58,
		"A closed minigame must be able to use the optional area boundary"
	)
	lab.playable_area.set_physical_walls_enabled(false)

	player.global_position = Vector3(58.0, 0.04, 0.0)
	player.velocity = Vector3.ZERO
	player.set_touch_move(Vector2(1.0, 0.0))
	for frame in 90:
		await physics_frame
	player.set_touch_move(Vector2.ZERO)
	_require(
		player.global_position.x <= 59.15,
		"The permanent shore must keep the character out of the ocean"
	)

	player.reset_to_spawn()
	for frame in 20:
		await physics_frame
	player.set_touch_move(Vector2(0.0, -1.0))
	for frame in 75:
		await physics_frame
	var running_speed := Vector2(player.velocity.x, player.velocity.z).length()
	_require(
		running_speed > SCALE.RUN_SPEED * 0.9
		and player.get_movement_ratio() > 0.88,
		"Animation ratio must follow real running speed"
	)
	player.set_touch_move(Vector2.ZERO)
	for frame in 35:
		await physics_frame
	_require(
		Vector2(player.velocity.x, player.velocity.z).length() < 0.08,
		"Local deceleration must stop without network correction"
	)

	player.reset_to_spawn()
	for frame in 20:
		await physics_frame
	var push_origin := player.global_position.x
	player.apply_external_push(Vector3.RIGHT, 5.0)
	for frame in 20:
		await physics_frame
	_require(
		player.global_position.x > push_origin + 0.45,
		"External impulses must displace the local body immediately"
	)
	for frame in 100:
		await physics_frame
	_require(absf(player.velocity.x) < 0.1, "External impulses must decay")

	player.reset_to_spawn()
	for frame in 20:
		await physics_frame
	var jump_origin := player.global_position.y
	var jump_apex := jump_origin
	player.request_jump()
	for frame in 100:
		await physics_frame
		jump_apex = maxf(jump_apex, player.global_position.y)
	_require(
		absf((jump_apex - jump_origin) - SCALE.JUMP_HEIGHT) < 0.14,
		"Jump apex must match the documented local height"
	)
	_require(
		player.is_on_floor() and absf(player.get_visual_foot_height()) < 0.04,
		"Landing must return the feet to the island floor"
	)

	player.set_view_direction(Vector3(0.0, 0.0, 1.0))
	var camera_forward := -player.camera_pivot.global_basis.z
	camera_forward.y = 0.0
	camera_forward = camera_forward.normalized()
	_require(
		camera_forward.dot(Vector3(0.0, 0.0, 1.0)) > 0.99,
		"Away view must face the centre instead of its own goal"
	)
	player.set_top_down_mode(true)
	player.set_top_down_aim(Vector2(0.0, -1.0), true)
	_require(
		player.get_top_down_aim_direction().dot(Vector3(0.0, 0.0, 1.0)) > 0.99,
		"Top-down screen-up aim must respect the team camera yaw"
	)
	player.set_top_down_mode(false)
	player.set_view_direction(Vector3(0.0, 0.0, -1.0))

	await _verify_statures()
	var diagnostics := lab.get_diagnostics()
	_require(
		diagnostics.dynamic_objects == 0
		and diagnostics.boundary_count == 4,
		"Diagnostics must prove the clean island baseline"
	)
	print(
		"LOCAL_BASE_OK nodes=%d objects=0 run_speed=%.2f jump_height=%.2f foot=%.3f area=%.0f"
		% [
			get_node_count(),
			running_speed,
			jump_apex - jump_origin,
			player.get_visual_foot_height(),
			lab.playable_area.get_area_size(),
		]
	)
	quit(1 if _failed else 0)


func _verify_statures() -> void:
	var statures := [
		SCALE.STATURE_SHORT,
		SCALE.STATURE_STANDARD,
		SCALE.STATURE_TALL,
	]
	for index in statures.size():
		var character := CHARACTER_SCENE.instantiate() as LocalBaseCharacter
		character.name = "StatureProbe%d" % index
		character.position = Vector3(30.0 + index * 2.0, 0.02, 30.0)
		character.controls_enabled = false
		root.add_child(character)
		await process_frame
		character.configure_stature(statures[index])
		var capsule := character.get_node("Collision").shape as CapsuleShape3D
		_require(
			is_equal_approx(capsule.height, SCALE.COLLISION_HEIGHT * statures[index])
			and absf(character.get_collision_bottom_height() - character.global_position.y) < 0.001,
			"Stature variants must preserve the foot origin"
		)
		character.queue_free()
		await process_frame


func _require(condition: bool, message: String) -> void:
	if condition:
		return
	_failed = true
	push_error("LOCAL_BASE_FAIL: " + message)
