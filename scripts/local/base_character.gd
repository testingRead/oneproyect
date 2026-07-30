class_name LocalBaseCharacter
extends CharacterBody3D

const SCALE := preload("res://shared/gameplay_scale.gd")

signal metrics_changed(metrics: Dictionary)
signal push_performed(hit: bool)

@export_range(0.8, 1.2, 0.01) var stature := SCALE.STATURE_STANDARD
@export var controls_enabled := true
@export var emit_metrics := true

@onready var collision: CollisionShape3D = $Collision
@onready var visual_root: BaseCharacterVisual = $VisualRoot
@onready var camera_pivot: Node3D = $CameraPivot

var _touch_move := Vector2.ZERO
var _jump_requested := false
var _touch_sprint := false
var _external_velocity := Vector3.ZERO
var _motor_velocity := Vector3.ZERO
var _last_metrics_second := -1
var _spawn_transform: Transform3D
var _push_cooldown := 0.0


func _ready() -> void:
	_spawn_transform = global_transform
	floor_snap_length = SCALE.FLOOR_SNAP_DISTANCE
	floor_stop_on_slope = true
	floor_max_angle = deg_to_rad(46.0)
	max_slides = 6
	configure_stature(stature)
	add_to_group(&"local_base_character")
	if not OS.has_feature("mobile"):
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _physics_process(delta: float) -> void:
	_push_cooldown = maxf(0.0, _push_cooldown - delta)
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
	if not controls_enabled or _push_cooldown > 0.0:
		return false
	_push_cooldown = 0.42
	visual_root.trigger_push()
	var direction := -camera_pivot.global_basis.z
	direction.y = 0.0
	direction = direction.normalized()
	var origin := global_position + Vector3.UP * 0.82
	var query := PhysicsRayQueryParameters3D.create(
		origin,
		origin + direction * 1.65,
		1
	)
	query.exclude = [get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	var body := hit.get("collider") as RigidBody3D
	if body == null:
		push_performed.emit(false)
		return false
	body.sleeping = false
	body.apply_central_impulse(direction * 2.4 + Vector3.UP * 0.28)
	push_performed.emit(true)
	return true


func add_touch_look(delta: Vector2) -> void:
	camera_pivot.rotation.y -= delta.x * 0.0035
	camera_pivot.rotation.x = clampf(
		camera_pivot.rotation.x - delta.y * 0.0035,
		-0.82,
		0.28
	)


func apply_external_push(direction: Vector3, force := 5.0) -> void:
	var safe_direction := direction
	if safe_direction.length_squared() < 0.001:
		safe_direction = Vector3.FORWARD
	safe_direction = safe_direction.normalized()
	_external_velocity += safe_direction * force
	velocity.y = maxf(velocity.y, maxf(0.0, safe_direction.y * force))


func reset_to_spawn() -> void:
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


func _push_contacted_rigid_bodies() -> void:
	var horizontal_velocity := Vector3(velocity.x, 0.0, velocity.z)
	if horizontal_velocity.length_squared() < 0.16:
		return
	for index in get_slide_collision_count():
		var collision_info := get_slide_collision(index)
		var body := collision_info.get_collider() as RigidBody3D
		if body == null:
			continue
		var direction := -collision_info.get_normal()
		direction.y = 0.0
		if direction.length_squared() < 0.01:
			continue
		direction = direction.normalized()
		var approach_speed := maxf(0.0, horizontal_velocity.dot(direction))
		if approach_speed <= 0.1:
			continue
		body.sleeping = false
		body.apply_central_force(direction * minf(18.0, 4.0 + approach_speed * 2.2))
