class_name LocalBaseCharacter
extends CharacterBody3D

const SCALE := preload("res://shared/gameplay_scale.gd")

signal metrics_changed(metrics: Dictionary)
signal push_performed(hit: bool)
signal hand_action_changed(label: String)
signal action_resolved(action: StringName, hit: bool)
signal local_health_changed(current: int, maximum: int)
signal object_impulse_requested(object_name: String, impulse: Vector3)

const ACTION_PUSH := &"PUSH"
const ACTION_KICK := &"KICK"
const ACTION_TAKE := &"TAKE"
const ACTION_THROW := &"THROW"

@export_range(0.8, 1.2, 0.01) var stature := SCALE.STATURE_STANDARD
@export var controls_enabled := true
@export var emit_metrics := true

@onready var collision: CollisionShape3D = $Collision
@onready var visual_root: BaseCharacterVisual = $VisualRoot
@onready var camera_pivot: Node3D = $CameraPivot
@onready var spring_arm: SpringArm3D = $CameraPivot/SpringArm
@onready var interaction_context: ShapeCast3D = $InteractionContext
@onready var interaction_action: ShapeCast3D = $InteractionAction
@onready var interaction_scan: Timer = $InteractionScan
@onready var held_item_anchor: Marker3D = $AnchorPoints/HeldItem
@onready var visual_item_socket: Marker3D = $VisualRoot/Model/RightArmPivot/ItemSocket

var _touch_move := Vector2.ZERO
var _jump_requested := false
var _touch_sprint := false
var _external_velocity := Vector3.ZERO
var _motor_velocity := Vector3.ZERO
var _last_metrics_second := -1
var _spawn_transform: Transform3D
var _hand_cooldown := 0.0
var _foot_cooldown := 0.0
var _hand_action := ACTION_PUSH
var _context_body: RigidBody3D
var _kick_target: RigidBody3D
var _kick_pending := false
var _kick_elapsed := 0.0
var _take_target: RigidBody3D
var _take_pending := false
var _take_elapsed := 0.0
var _throw_pending := false
var _throw_elapsed := 0.0
var _held_object: RigidBody3D
var _held_original_parent: Node
var _held_collision_layer := 0
var _held_collision_mask := 0
var _first_person := false
var _third_person_spring_length := 4.8
var _goalkeeper_cooldown := 0.0
var _goalkeeper_remaining := 0.0
var _goalkeeper_side := 0
var _goalkeeper_level := 1
var _local_health := 100


func _ready() -> void:
	_spawn_transform = global_transform
	_third_person_spring_length = spring_arm.spring_length
	floor_snap_length = SCALE.FLOOR_SNAP_DISTANCE
	floor_stop_on_slope = true
	floor_max_angle = deg_to_rad(46.0)
	max_slides = 6
	configure_stature(stature)
	add_to_group(&"local_base_character")
	interaction_scan.timeout.connect(_refresh_interaction_context)
	if not OS.has_feature("mobile"):
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	_refresh_interaction_context()


func _physics_process(delta: float) -> void:
	_hand_cooldown = maxf(0.0, _hand_cooldown - delta)
	_foot_cooldown = maxf(0.0, _foot_cooldown - delta)
	_goalkeeper_cooldown = maxf(0.0, _goalkeeper_cooldown - delta)
	_goalkeeper_remaining = maxf(0.0, _goalkeeper_remaining - delta)
	_align_interaction_nodes()
	_resolve_kick(delta)
	_resolve_take(delta)
	_resolve_throw(delta)
	var desktop := Input.get_vector(
		"move_left",
		"move_right",
		"move_forward",
		"move_back"
	)
	var movement_input := (
		_touch_move
		if _touch_move.length_squared() > desktop.length_squared()
		else desktop
	)
	if not controls_enabled:
		movement_input = Vector2.ZERO
	var input_strength := clampf(movement_input.length(), 0.0, 1.0)
	var wants_run := (
		Input.is_action_pressed("sprint")
		or _touch_sprint
		or (_touch_move.length() > 0.82 and _touch_move == movement_input)
	)
	var requested_speed := SCALE.RUN_SPEED if wants_run else SCALE.WALK_SPEED
	var yaw_basis := Basis(Vector3.UP, camera_pivot.rotation.y)
	var direction := yaw_basis * Vector3(movement_input.x, 0.0, movement_input.y)
	if direction.length_squared() > 1.0:
		direction = direction.normalized()
	var target := direction * requested_speed * input_strength
	var horizontal := Vector3(_motor_velocity.x, 0.0, _motor_velocity.z)
	var acceleration := SCALE.AIR_ACCELERATION
	if is_on_floor():
		acceleration = (
			SCALE.GROUND_ACCELERATION
			if target.length_squared() > horizontal.length_squared()
			else SCALE.GROUND_DECELERATION
		)
	horizontal = horizontal.move_toward(target, acceleration * delta)
	_motor_velocity.x = horizontal.x
	_motor_velocity.z = horizontal.z
	velocity.x = horizontal.x + _external_velocity.x
	velocity.z = horizontal.z + _external_velocity.z
	_external_velocity = _external_velocity.move_toward(Vector3.ZERO, delta * 5.5)
	if not is_on_floor():
		velocity.y -= SCALE.GRAVITY * delta
	elif controls_enabled and (
		_jump_requested
		or Input.is_action_just_pressed("jump")
	):
		velocity.y = SCALE.JUMP_VELOCITY
	_jump_requested = false
	if direction.length_squared() > 0.01:
		visual_root.rotation.y = lerp_angle(
			visual_root.rotation.y,
			atan2(direction.x, direction.z),
			delta * 12.0
		)
	move_and_slide()
	_push_contacted_rigid_bodies()
	_update_foot_contacts()
	var real_speed := Vector2(velocity.x, velocity.z).length()
	visual_root.update_motion(
		delta,
		real_speed,
		SCALE.RUN_SPEED,
		is_on_floor()
	)
	_sync_held_anchor()
	if global_position.y < -3.0:
		reset_to_spawn()
	if emit_metrics:
		_emit_metrics_once_per_second(real_speed)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		add_touch_look(event.relative)
	elif event is InputEventMouseButton and event.pressed:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func configure_stature(value: float) -> void:
	stature = clampf(value, 0.8, 1.2)
	var capsule := collision.shape as CapsuleShape3D
	if capsule == null:
		return
	capsule = capsule.duplicate() as CapsuleShape3D
	capsule.height = SCALE.COLLISION_HEIGHT * stature
	capsule.radius = SCALE.COLLISION_RADIUS
	collision.shape = capsule
	collision.position.y = capsule.height * 0.5
	visual_root.set_stature(stature)
	camera_pivot.position.y = SCALE.CHARACTER_HEIGHT * stature * 0.82


func set_touch_move(value: Vector2) -> void:
	_touch_move = value.limit_length(1.0) if controls_enabled else Vector2.ZERO


func set_touch_sprint(enabled: bool) -> void:
	_touch_sprint = enabled


func request_jump() -> void:
	if controls_enabled:
		_jump_requested = true


func request_push() -> bool:
	if not controls_enabled or _hand_cooldown > 0.0:
		return false
	_hand_cooldown = 0.42
	visual_root.trigger_push()
	var hit := _perform_generic_push()
	push_performed.emit(hit)
	action_resolved.emit(ACTION_PUSH, hit)
	return hit


func request_context_action() -> bool:
	return request_hand_action()


func request_hand_action() -> bool:
	if not controls_enabled or _hand_cooldown > 0.0:
		return false
	_refresh_interaction_context()
	match _hand_action:
		ACTION_TAKE:
			return _take_context_object()
		ACTION_THROW:
			return _throw_held_object()
		_:
			return request_push()


func request_foot_action() -> bool:
	if not controls_enabled or _foot_cooldown > 0.0:
		return false
	_refresh_interaction_context()
	return _begin_kick()


func get_context_action() -> StringName:
	return _hand_action


func get_hand_action() -> StringName:
	return _hand_action


func get_context_label() -> String:
	return get_hand_label()


func get_hand_label() -> String:
	match _hand_action:
		ACTION_TAKE:
			return "TOMAR"
		ACTION_THROW:
			return "LANZAR"
		_:
			return "EMPUJAR"


func get_held_object() -> RigidBody3D:
	return _held_object


func set_first_person(enabled: bool) -> void:
	if _first_person == enabled:
		return
	_first_person = enabled
	spring_arm.spring_length = 0.0 if enabled else _third_person_spring_length
	visual_root.visible = not enabled


func is_first_person() -> bool:
	return _first_person


func set_facing_direction(direction: Vector3) -> void:
	var horizontal := Vector3(direction.x, 0.0, direction.z)
	if horizontal.length_squared() < 0.001:
		return
	horizontal = horizontal.normalized()
	visual_root.rotation.y = atan2(horizontal.x, horizontal.z)


func get_facing_direction() -> Vector3:
	var direction := visual_root.global_basis.z
	direction.y = 0.0
	if direction.length_squared() < 0.001:
		return Vector3.FORWARD
	return direction.normalized()


func get_kick_direction() -> Vector3:
	var horizontal := get_facing_direction()
	var pitch := _get_kick_pitch()
	return (
		horizontal * cos(pitch)
		+ Vector3.UP * sin(pitch)
	).normalized()


func get_kick_force() -> float:
	var pitch := _get_kick_pitch()
	return lerpf(3.2, 8.0, inverse_lerp(-0.6, 0.5, pitch))


func request_goalkeeper_dive(side: int, level: int) -> bool:
	if not controls_enabled or _goalkeeper_cooldown > 0.0:
		return false
	_goalkeeper_cooldown = 0.7
	_goalkeeper_remaining = 0.72
	_goalkeeper_side = clampi(side, -1, 1)
	_goalkeeper_level = clampi(level, 0, 2)
	visual_root.trigger_goalkeeper_dive(_goalkeeper_side, _goalkeeper_level)
	var horizontal := Vector3(float(_goalkeeper_side) * 2.8, 0.0, 0.0)
	var vertical: float = [0.35, 1.15, 2.45][_goalkeeper_level]
	_external_velocity += horizontal
	velocity.y = maxf(velocity.y, vertical)
	return true


func is_goalkeeper_diving() -> bool:
	return _goalkeeper_remaining > 0.0


func get_goalkeeper_side() -> int:
	return _goalkeeper_side


func get_goalkeeper_level() -> int:
	return _goalkeeper_level


func add_touch_look(delta: Vector2) -> void:
	camera_pivot.rotation.y -= delta.x * 0.0035
	camera_pivot.rotation.x = clampf(
		camera_pivot.rotation.x - delta.y * 0.0035,
		-0.82,
		0.28
	)


func _get_kick_pitch() -> float:
	# The default camera looks slightly down at the character. Offset the kick
	# aim so a neutral view produces a useful, higher football trajectory.
	return clampf(camera_pivot.rotation.x + 0.22, -0.6, 0.5)


func apply_external_push(direction: Vector3, force := 5.0) -> void:
	var safe_direction := direction
	if safe_direction.length_squared() < 0.001:
		safe_direction = Vector3.FORWARD
	safe_direction = safe_direction.normalized()
	_external_velocity += safe_direction * force
	velocity.y = maxf(velocity.y, maxf(0.0, safe_direction.y * force))


func reset_local_health() -> void:
	_local_health = 100
	local_health_changed.emit(_local_health, 100)


func get_local_health() -> int:
	return _local_health


func apply_local_damage(amount: int) -> void:
	if amount <= 0:
		return
	_local_health = maxi(0, _local_health - amount)
	local_health_changed.emit(_local_health, 100)


func reset_to_spawn() -> void:
	_return_held_object_to_origin()
	global_transform = _spawn_transform
	velocity = Vector3.ZERO
	_motor_velocity = Vector3.ZERO
	_external_velocity = Vector3.ZERO
	_touch_move = Vector2.ZERO


func set_spawn_transform(value: Transform3D, teleport := true) -> void:
	_spawn_transform = value
	if teleport:
		reset_to_spawn()


func get_movement_ratio() -> float:
	return visual_root.get_movement_ratio()


func get_collision_bottom_height() -> float:
	var capsule := collision.shape as CapsuleShape3D
	return global_position.y + collision.position.y - capsule.height * 0.5


func get_visual_foot_height() -> float:
	return visual_root.get_visual_foot_height()


func get_diagnostics() -> Dictionary:
	return {
		"position": global_position,
		"velocity": velocity,
		"on_floor": is_on_floor(),
		"collision_bottom": get_collision_bottom_height(),
		"visual_foot": get_visual_foot_height(),
		"movement_ratio": get_movement_ratio(),
		"stature": stature,
	}


func _emit_metrics_once_per_second(horizontal_speed: float) -> void:
	var second := Time.get_ticks_msec() / 1000
	if second == _last_metrics_second:
		return
	_last_metrics_second = second
	var metrics := get_diagnostics()
	metrics["horizontal_speed"] = horizontal_speed
	metrics_changed.emit(metrics)


func _update_foot_contacts() -> void:
	if not is_on_floor():
		visual_root.clear_foot_contacts()
		return
	var left_ray := $VisualRoot/GroundProbes/Left as RayCast3D
	var right_ray := $VisualRoot/GroundProbes/Right as RayCast3D
	left_ray.force_raycast_update()
	right_ray.force_raycast_update()
	var left_height := 0.0
	var right_height := 0.0
	var left_normal := Vector3.UP
	var right_normal := Vector3.UP
	if left_ray.is_colliding():
		left_height = left_ray.get_collision_point().y - global_position.y
		left_normal = left_ray.get_collision_normal()
	if right_ray.is_colliding():
		right_height = right_ray.get_collision_point().y - global_position.y
		right_normal = right_ray.get_collision_normal()
	visual_root.set_foot_contacts(
		left_height,
		right_height,
		left_normal,
		right_normal
	)


func _align_interaction_nodes() -> void:
	interaction_context.rotation.y = camera_pivot.rotation.y
	interaction_action.rotation.y = camera_pivot.rotation.y
	_sync_held_anchor()


func _refresh_interaction_context() -> void:
	var next_action := ACTION_PUSH
	var next_body: RigidBody3D
	if not is_instance_valid(_held_object):
		_align_interaction_nodes()
		interaction_context.force_shapecast_update()
		next_body = _get_nearest_body(interaction_context)
	_context_body = next_body
	if is_instance_valid(_held_object):
		next_action = ACTION_THROW
	elif is_instance_valid(next_body) and next_body.is_in_group(&"pickup_stone"):
		next_action = ACTION_TAKE
	else:
		next_action = ACTION_PUSH
	if next_action == _hand_action:
		return
	_hand_action = next_action
	hand_action_changed.emit(get_hand_label())


func _begin_kick() -> bool:
	_foot_cooldown = 0.52
	_align_foot_action()
	interaction_action.force_shapecast_update()
	_kick_target = _get_nearest_body_in_group(
		interaction_action,
		&"kickable_ball"
	)
	if _kick_target == null:
		_kick_target = _query_kickable_body()
	_kick_pending = true
	_kick_elapsed = 0.0
	visual_root.trigger_kick()
	return true


func _resolve_kick(delta: float) -> void:
	if not _kick_pending:
		return
	_kick_elapsed += delta
	if _kick_elapsed < 0.18:
		return
	_kick_pending = false
	_align_foot_action()
	interaction_action.force_shapecast_update()
	var hit := (
		is_instance_valid(_kick_target)
		and _query_kick_contact(_kick_target)
		and _kick_target.is_in_group(&"kickable_ball")
	)
	if hit:
		var direction := get_kick_direction()
		var impulse := direction * get_kick_force()
		_kick_target.sleeping = false
		_kick_target.apply_central_impulse(impulse)
		object_impulse_requested.emit(_kick_target.name, impulse)
	action_resolved.emit(ACTION_KICK, hit)
	_kick_target = null
	_refresh_interaction_context()


func _align_foot_action() -> void:
	# The model's local +Z is its face, while ShapeCast3D points along -Z.
	interaction_action.rotation.y = visual_root.rotation.y - PI


func _query_kickable_body() -> RigidBody3D:
	var nearest: RigidBody3D
	var nearest_distance := INF
	for candidate in get_tree().get_nodes_in_group(&"kickable_ball"):
		var body := candidate as RigidBody3D
		if body == null or not _query_kick_contact(body):
			continue
		var distance := global_position.distance_squared_to(body.global_position)
		if distance < nearest_distance:
			nearest = body
			nearest_distance = distance
	return nearest


func _query_kick_contact(target: RigidBody3D) -> bool:
	if not is_instance_valid(target):
		return false
	var forward := get_facing_direction()
	var to_target := target.global_position - global_position
	var horizontal_target := Vector3(to_target.x, 0.0, to_target.z)
	# Keep the interaction forgiving enough for a moving ball: the final
	# impulse still follows the body's facing direction, never the camera.
	if horizontal_target.length_squared() <= 1.65 * 1.65 and horizontal_target.length_squared() > 0.001:
		if forward.dot(horizontal_target.normalized()) > 0.18 and absf(to_target.y) < 1.1:
			return true
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = interaction_action.shape
	query.transform = Transform3D(
		Basis.IDENTITY,
		global_position + Vector3(0.0, 0.22, 0.0) + forward * 0.88
	)
	query.collision_mask = 1
	query.exclude = [get_rid()]
	for hit in get_world_3d().direct_space_state.intersect_shape(query, 8):
		if hit.collider == target:
			return true
	return false


func _take_context_object() -> bool:
	var body := _context_body
	if not is_instance_valid(body) or not body.is_in_group(&"pickup_stone"):
		return false
	_hand_cooldown = 0.62
	_take_target = body
	_take_pending = true
	_take_elapsed = 0.0
	_face_interaction_direction()
	visual_root.trigger_take()
	return true


func _resolve_take(delta: float) -> void:
	if not _take_pending:
		return
	_take_elapsed += delta
	if _take_elapsed < 0.26:
		return
	_take_pending = false
	interaction_context.force_shapecast_update()
	var hit := (
		is_instance_valid(_take_target)
		and _cast_contains(interaction_context, _take_target)
		and _take_target.is_in_group(&"pickup_stone")
	)
	if hit:
		_equip_object(_take_target)
	action_resolved.emit(ACTION_TAKE, hit)
	_take_target = null
	_refresh_interaction_context()


func _equip_object(body: RigidBody3D) -> void:
	_held_object = body
	_held_original_parent = body.get_parent()
	_held_collision_layer = body.collision_layer
	_held_collision_mask = body.collision_mask
	body.freeze = true
	body.linear_velocity = Vector3.ZERO
	body.angular_velocity = Vector3.ZERO
	body.collision_layer = 0
	body.collision_mask = 0
	_sync_held_anchor()
	body.reparent(held_item_anchor, false)
	body.transform = Transform3D.IDENTITY
	var object_label := body.get_node_or_null("ObjectLabel") as Label3D
	if object_label != null:
		object_label.hide()


func _throw_held_object() -> bool:
	if not is_instance_valid(_held_object):
		return false
	_hand_cooldown = 0.62
	_throw_pending = true
	_throw_elapsed = 0.0
	_face_interaction_direction()
	visual_root.trigger_throw()
	return true


func _resolve_throw(delta: float) -> void:
	if not _throw_pending:
		return
	_throw_elapsed += delta
	if _throw_elapsed < 0.28:
		return
	_throw_pending = false
	var hit := _release_held_object()
	action_resolved.emit(ACTION_THROW, hit)
	_refresh_interaction_context()


func _release_held_object() -> bool:
	if not is_instance_valid(_held_object):
		return false
	var body := _held_object
	var world_transform := body.global_transform
	body.reparent(_held_original_parent, true)
	body.global_transform = world_transform
	body.collision_layer = _held_collision_layer
	body.collision_mask = _held_collision_mask
	body.freeze = false
	body.sleeping = false
	body.linear_velocity = Vector3.ZERO
	body.angular_velocity = Vector3.ZERO
	var object_label := body.get_node_or_null("ObjectLabel") as Label3D
	if object_label != null:
		object_label.show()
	var direction := _get_interaction_direction()
	body.apply_central_impulse(direction * 2.2 + Vector3.UP * 0.62)
	_held_object = null
	_held_original_parent = null
	return true


func _return_held_object_to_origin() -> void:
	_take_pending = false
	_take_target = null
	_throw_pending = false
	if not is_instance_valid(_held_object):
		_held_object = null
		_held_original_parent = null
		return
	var body := _held_object
	body.reparent(_held_original_parent, true)
	body.collision_layer = _held_collision_layer
	body.collision_mask = _held_collision_mask
	body.freeze = true
	if body.has_meta(&"initial_transform"):
		body.global_transform = body.get_meta(&"initial_transform")
	body.linear_velocity = Vector3.ZERO
	body.angular_velocity = Vector3.ZERO
	var object_label := body.get_node_or_null("ObjectLabel") as Label3D
	if object_label != null:
		object_label.show()
	body.freeze = false
	_held_object = null
	_held_original_parent = null
	_refresh_interaction_context()


func _perform_generic_push() -> bool:
	_align_interaction_nodes()
	interaction_action.force_shapecast_update()
	var body := _get_nearest_body(interaction_action)
	if body == null:
		return false
	body.sleeping = false
	body.apply_central_impulse(
		_get_interaction_direction() * 2.4 + Vector3.UP * 0.28
	)
	return true


func _get_interaction_direction() -> Vector3:
	var direction := -camera_pivot.global_basis.z
	direction.y = 0.0
	if direction.length_squared() < 0.01:
		return Vector3.FORWARD
	return direction.normalized()


func _face_interaction_direction() -> void:
	var direction := _get_interaction_direction()
	visual_root.rotation.y = atan2(direction.x, direction.z)


func _sync_held_anchor() -> void:
	if is_instance_valid(visual_item_socket):
		held_item_anchor.global_transform = visual_item_socket.global_transform


func _get_nearest_body(shape_cast: ShapeCast3D) -> RigidBody3D:
	var nearest: RigidBody3D
	var nearest_distance := INF
	for index in shape_cast.get_collision_count():
		var body := shape_cast.get_collider(index) as RigidBody3D
		if body == null:
			continue
		var distance := global_position.distance_squared_to(body.global_position)
		if distance < nearest_distance:
			nearest = body
			nearest_distance = distance
	return nearest


func _get_nearest_body_in_group(
	shape_cast: ShapeCast3D,
	group: StringName
) -> RigidBody3D:
	var nearest: RigidBody3D
	var nearest_distance := INF
	for index in shape_cast.get_collision_count():
		var body := shape_cast.get_collider(index) as RigidBody3D
		if body == null or not body.is_in_group(group):
			continue
		var distance := global_position.distance_squared_to(body.global_position)
		if distance < nearest_distance:
			nearest = body
			nearest_distance = distance
	return nearest


func _cast_contains(shape_cast: ShapeCast3D, target: RigidBody3D) -> bool:
	for index in shape_cast.get_collision_count():
		if shape_cast.get_collider(index) == target:
			return true
	return false


func _push_contacted_rigid_bodies() -> void:
	# move_and_slide() removes the velocity component blocked by the contact.
	# Use the motor intent retained by the controller so the contacted body
	# still receives the force that the character tried to apply.
	var horizontal_velocity := Vector3(
		_motor_velocity.x + _external_velocity.x,
		0.0,
		_motor_velocity.z + _external_velocity.z
	)
	if horizontal_velocity.length_squared() < 0.16:
		return
	for index in get_slide_collision_count():
		var collision_info := get_slide_collision(index)
		var body := collision_info.get_collider() as RigidBody3D
		if body == null:
			continue
		if body.is_in_group(&"pickup_stone"):
			continue
		var direction := -collision_info.get_normal()
		direction.y = 0.0
		if direction.length_squared() < 0.01:
			continue
		direction = direction.normalized()
		var body_velocity := Vector3(
			body.linear_velocity.x,
			0.0,
			body.linear_velocity.z
		)
		var relative_velocity := horizontal_velocity - body_velocity
		var approach_speed := maxf(0.0, relative_velocity.dot(direction))
		if approach_speed <= 0.1:
			continue
		var effective_mass := 1.0 / (
			1.0 / SCALE.CHARACTER_MASS
			+ 1.0 / maxf(0.01, body.mass)
		)
		body.sleeping = false
		body.apply_central_impulse(
			direction * approach_speed * effective_mass
		)
