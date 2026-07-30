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
	_require(
		not root.has_node("Network"),
		"Local base test must start without a Network singleton"
	)
	_require(
		is_equal_approx(SCALE.CHARACTER_HEIGHT, 1.8)
		and is_equal_approx(SCALE.CHARACTER_MASS, 70.0)
		and is_equal_approx(SCALE.COLLISION_HEIGHT, 1.72)
		and is_equal_approx(SCALE.COLLISION_RADIUS, 0.34),
		"Character scale and reference mass must come from the official contract"
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
		lab.playable_area.get_wall_count() == 4
		and not lab.playable_area.are_physical_walls_enabled(),
		"Event areas must reuse four optional walls but island mode keeps them disabled"
	)
	_require(
		lab.get_active_dynamic_object_count() == 5,
		"Lab must expose three boxes, one rolling ball and one rock"
	)
	_require(
		lab.get_diagnostics().shore_boundaries == 4,
		"The island shore must be the permanent physical boundary"
	)
	var interaction_counts: Dictionary = lab.get_interaction_counts()
	_require(
		interaction_counts.static >= 1
		and interaction_counts.mobile == 1
		and interaction_counts.movable == 5,
		"Objects must declare static, programmed-mobile or user-movable ownership"
	)
	_require(
		player.has_node("Collision")
		and player.has_node("VisualRoot/Model")
		and player.has_node("CameraPivot")
		and player.has_node("AnchorPoints/Feet")
		and player.has_node("AnchorPoints/HeldItem")
		and player.has_node("InteractionRay"),
		"Character must separate collision, visual, camera, anchors and interaction probe"
	)
	_require(
		player.is_on_floor(),
		"Standard character must settle on the reference floor"
	)
	_require(
		absf(player.get_collision_bottom_height()) < 0.035
		and absf(player.get_visual_foot_height()) < 0.035,
		"Visual feet and collision bottom must share the floor origin"
	)

	var baseline_nodes := get_node_count()
	for index in 12:
		lab.set_playable_area_index(index % 3)
		lab.reset_lab()
		await physics_frame
	_require(
		get_node_count() == baseline_nodes,
		"Changing limits and resetting must not create residual nodes"
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
			"Small, medium and large limits must be parameter-only variants"
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
		"Minigames must be able to opt into a small physical boundary"
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
		"Permanent shore collision must keep the character out of the ocean"
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
		"Local deceleration must stop the player without network correction"
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
	_require(
		absf(player.velocity.x) < 0.1,
		"External impulses must decay without accumulating every frame"
	)

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
		"Landing must return visual feet to the same floor reference"
	)

	await _verify_statures()
	await _verify_slope_contact(lab, player)
	await _verify_moving_platform(lab, player)
	await _verify_movable_objects(lab)

	var diagnostics := lab.get_diagnostics()
	_require(
		diagnostics.dynamic_objects == diagnostics.initial_dynamic_objects
		and diagnostics.boundary_count == 4,
		"Diagnostics must prove reset completeness"
	)
	print(
		"LOCAL_BASE_OK nodes=%d objects=%d run_speed=%.2f jump_height=%.2f foot=%.3f area=%.0f"
		% [
			get_node_count(),
			lab.get_active_dynamic_object_count(),
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
			"Short, standard and tall silhouettes must preserve the foot origin"
		)
		character.queue_free()
		await process_frame


func _verify_slope_contact(
	lab: LocalDevelopmentLab,
	player: LocalBaseCharacter
) -> void:
	player.global_position = Vector3(-7.0, 2.2, 3.0)
	player.velocity = Vector3.ZERO
	player.set_touch_move(Vector2.ZERO)
	for frame in 90:
		await physics_frame
	_require(player.is_on_floor(), "Character must settle on the reference slope")
	var query := PhysicsRayQueryParameters3D.create(
		player.global_position + Vector3.UP * 0.18,
		player.global_position + Vector3.DOWN * 0.25,
		1
	)
	query.exclude = [player.get_rid()]
	var hit := lab.get_world_3d().direct_space_state.intersect_ray(query)
	_require(not hit.is_empty(), "Foot probe must find the slope below the character")
	_require(
		absf(float(hit.position.y) - player.get_visual_foot_height()) < 0.14,
		"Visual foot reference must remain close to sloped contact"
	)


func _verify_moving_platform(
	lab: LocalDevelopmentLab,
	player: LocalBaseCharacter
) -> void:
	var platform := lab.get_node("World/TestCourse/MovingPlatform") as AnimatableBody3D
	player.global_position = platform.global_position + Vector3(0.0, 0.75, 0.0)
	player.velocity = Vector3.ZERO
	player.set_touch_move(Vector2.ZERO)
	for frame in 35:
		await physics_frame
	var initial_x := player.global_position.x
	for frame in 90:
		await physics_frame
	_require(
		player.is_on_floor(),
		"Character must stay grounded on the moving reference platform"
	)
	_require(
		absf(player.global_position.x - initial_x) > 0.35,
		"Moving platform must carry the local CharacterBody"
	)


func _verify_movable_objects(lab: LocalDevelopmentLab) -> void:
	var ball := lab.get_node("World/TestCourse/Ball") as RigidBody3D
	var rock := lab.get_node("World/TestCourse/Rock") as RigidBody3D
	var medium_box := lab.get_node("World/TestCourse/MediumBox") as RigidBody3D
	var large_box := lab.get_node("World/TestCourse/LargeBox") as RigidBody3D
	var player := lab.player
	var ball_reset: Transform3D = ball.get_meta(&"initial_transform")
	var rock_reset: Transform3D = rock.get_meta(&"initial_transform")
	var medium_origin := medium_box.global_position
	var large_origin := large_box.global_position
	var ball_shape := (ball.get_child(0) as CollisionShape3D).shape as SphereShape3D
	var rock_shape := (rock.get_child(0) as CollisionShape3D).shape as SphereShape3D
	_require(
		is_equal_approx(ball_shape.radius, 0.22)
		and is_equal_approx(ball.mass, 0.43)
		and is_equal_approx(rock_shape.radius, 0.14)
		and is_equal_approx(rock.mass, 0.32),
		"Ball and throwable stone must use their approved human-scale dimensions"
	)

	medium_box.apply_central_impulse(Vector3(0.0, 0.0, 2.2))
	large_box.apply_central_impulse(Vector3(0.0, 0.0, 2.2))
	await physics_frame
	_require(
		medium_box.linear_velocity.length() > large_box.linear_velocity.length() * 3.0,
		"Equal impulse must preserve a clear medium/heavy mass difference"
	)
	for frame in 45:
		await physics_frame
	_require(
		medium_box.global_position.distance_to(medium_origin)
		> large_box.global_position.distance_to(large_origin),
		"Medium box must respond more than the heavy box to equal impulse"
	)
	lab.reset_lab()
	await physics_frame
	_require(
		ball.global_position.distance_to(ball_reset.origin) < 0.02
		and rock.global_position.distance_to(rock_reset.origin) < 0.02,
		"Movable references must return exactly on laboratory reset"
	)

	player.global_position = Vector3(
		ball_reset.origin.x,
		0.02,
		ball_reset.origin.z + 1.35
	)
	player.velocity = Vector3.ZERO
	player.set_touch_move(Vector2(0.0, -1.0))
	for frame in 45:
		await physics_frame
	player.set_touch_move(Vector2.ZERO)
	_require(
		ball.global_position.distance_to(ball_reset.origin) > 0.08,
		"Walking into the ball must transfer visible force locally (distance=%.3f)"
		% ball.global_position.distance_to(ball_reset.origin)
	)

	lab.reset_lab()
	await physics_frame
	player.global_position = Vector3(
		ball_reset.origin.x,
		0.02,
		ball_reset.origin.z + 1.05
	)
	player.velocity = Vector3.ZERO
	player.camera_pivot.rotation.y = 0.0
	for frame in 10:
		await physics_frame
	_require(
		player.get_context_action() == LocalBaseCharacter.ACTION_KICK,
		"Ball in front must change the contextual action to KICK"
	)
	_require(player.request_context_action(), "Contextual kick must start")
	for frame in 24:
		await physics_frame
	_require(
		ball.global_position.distance_to(ball_reset.origin) > 0.35,
		"Kick contact window must move the ball"
	)

	lab.reset_lab()
	await physics_frame
	player.global_position = Vector3(
		ball_reset.origin.x,
		0.02,
		ball_reset.origin.z + 1.05
	)
	player.camera_pivot.rotation.y = 0.0
	for frame in 10:
		await physics_frame
	_require(player.request_context_action(), "Miss probe must begin a kick")
	player.camera_pivot.rotation.y = PI * 0.5
	for frame in 24:
		await physics_frame
	_require(
		ball.global_position.distance_to(ball_reset.origin) < 0.05,
		"Kick must miss when the ball is no longer inside the foot contact probe"
	)

	lab.reset_lab()
	await physics_frame
	player.global_position = Vector3(
		rock_reset.origin.x,
		0.02,
		rock_reset.origin.z + 1.0
	)
	player.camera_pivot.rotation.y = 0.0
	for frame in 10:
		await physics_frame
	_require(
		player.get_context_action() == LocalBaseCharacter.ACTION_TAKE,
		"Small stone in front must expose TAKE"
	)
	_require(
		player.request_context_action()
		and player.get_held_object() == rock
		and player.get_context_action() == LocalBaseCharacter.ACTION_THROW,
		"TAKE must equip the stone and switch the action to THROW"
	)
	for frame in 22:
		await physics_frame
	_require(player.request_context_action(), "Equipped stone must be throwable")
	for frame in 8:
		await physics_frame
	_require(
		player.get_held_object() == null and rock.linear_velocity.length() > 0.4,
		"THROW must release the stone with a physical impulse"
	)
	lab.reset_lab()
	await physics_frame


func _require(condition: bool, message: String) -> void:
	if condition:
		return
	_failed = true
	push_error("LOCAL_BASE_FAIL: " + message)
