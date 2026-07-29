class_name GrayboxPlayer
extends CharacterBody3D

const SUIT_TEXTURE := preload("res://assets/textures/suit_panels.res")
const CHARACTER_COLORS := [
	Color(0.15, 0.58, 0.96),
	Color(0.22, 0.78, 0.5),
	Color(0.75, 0.42, 0.95),
	Color(1.0, 0.48, 0.14),
	Color(1.0, 0.78, 0.2),
]

@export var move_speed := 6.0
@export var ground_acceleration := 28.0
@export var air_acceleration := 8.0
@export var jump_velocity := 7.5
@export var look_sensitivity := 0.003
@export var touch_look_sensitivity := 0.004

@onready var visual: Node3D = $Visual
@onready var camera_rig: Node3D = $CameraRig
@onready var color_parts: Array[MeshInstance3D] = [
	$Visual/Body,
	$Visual/Head,
	$Visual/LeftArm,
	$Visual/RightArm,
	$Visual/LeftLeg,
	$Visual/RightLeg,
]

signal health_changed(current: int, maximum: int)
signal damaged(amount: int, current: int)
signal defeated
signal push_requested

const MAX_HEALTH := 100

var _touch_move := Vector2.ZERO
var _jump_requested := false
var _spawn_transform: Transform3D
var _health := MAX_HEALTH
var _invulnerability := 0.0
var _controls_enabled := true
var _push_cooldown := 0.0
var _first_person := false
var _look_sensitivity_scale := 1.0


func _ready() -> void:
	_spawn_transform = global_transform
	floor_snap_length = 0.35
	add_to_group("players")
	health_changed.emit(_health, MAX_HEALTH)
	if not OS.has_feature("mobile"):
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _physics_process(delta: float) -> void:
	_invulnerability = maxf(0.0, _invulnerability - delta)
	_push_cooldown = maxf(0.0, _push_cooldown - delta)
	var desktop_move := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var movement_input := _touch_move if _touch_move.length_squared() > desktop_move.length_squared() else desktop_move
	if not _controls_enabled:
		movement_input = Vector2.ZERO
	var yaw_basis := Basis(Vector3.UP, camera_rig.rotation.y)
	var direction := yaw_basis * Vector3(movement_input.x, 0.0, movement_input.y)
	if direction.length_squared() > 1.0:
		direction = direction.normalized()

	var acceleration := ground_acceleration if is_on_floor() else air_acceleration
	velocity.x = move_toward(velocity.x, direction.x * move_speed, acceleration * delta)
	velocity.z = move_toward(velocity.z, direction.z * move_speed, acceleration * delta)

	if not is_on_floor():
		velocity += get_gravity() * delta
	elif _controls_enabled and (_jump_requested or Input.is_action_just_pressed("jump")):
		velocity.y = jump_velocity
	_jump_requested = false
	if _controls_enabled and Input.is_action_just_pressed("push"):
		request_push()

	if direction.length_squared() > 0.01:
		visual.rotation.y = lerp_angle(visual.rotation.y, atan2(direction.x, direction.z), 12.0 * delta)

	move_and_slide()
	if global_position.y < -8.0:
		reset_to_spawn()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		_apply_look(event.relative * look_sensitivity)
	elif event is InputEventMouseButton and event.pressed:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func set_touch_move(value: Vector2) -> void:
	_touch_move = value if _controls_enabled else Vector2.ZERO


func add_touch_look(delta: Vector2) -> void:
	_apply_look(delta * touch_look_sensitivity)


func request_jump() -> void:
	if _controls_enabled:
		_jump_requested = true


func request_push() -> void:
	if not _controls_enabled or _push_cooldown > 0.0:
		return
	_push_cooldown = 0.72
	push_requested.emit()


func set_controls_enabled(enabled: bool) -> void:
	_controls_enabled = enabled
	if not enabled:
		_touch_move = Vector2.ZERO
		_jump_requested = false


func reset_to_spawn() -> void:
	global_transform = _spawn_transform
	velocity = Vector3.ZERO
	_touch_move = Vector2.ZERO
	camera_rig.rotation = Vector3(-0.22, 0.0, 0.0)
	heal_full()


func heal_full() -> void:
	_health = MAX_HEALTH
	_invulnerability = 0.0
	health_changed.emit(_health, MAX_HEALTH)


func get_health() -> int:
	return _health


func get_visual_yaw() -> float:
	return visual.rotation.y


func get_aim_forward() -> Vector3:
	var forward := camera_rig.global_basis * Vector3.FORWARD
	forward.y = 0.0
	return forward.normalized()


func apply_external_push(direction: Vector3, force := 5.2) -> void:
	var safe_direction := direction
	safe_direction.y = 0.0
	if safe_direction.length_squared() < 0.01:
		safe_direction = Vector3.FORWARD
	safe_direction = safe_direction.normalized()
	velocity.x += safe_direction.x * force
	velocity.z += safe_direction.z * force
	velocity.y = maxf(velocity.y, force * 0.42)


func apply_hazard_damage(damage: int, lift_force := 0.0) -> void:
	if _invulnerability > 0.0:
		return
	_health = maxi(0, _health - damage)
	_invulnerability = 0.45
	velocity.y = maxf(velocity.y, lift_force)
	health_changed.emit(_health, MAX_HEALTH)
	damaged.emit(damage, _health)
	if _health == 0:
		defeated.emit()


func set_first_person(enabled: bool) -> void:
	_first_person = enabled
	visual.visible = not enabled
	$CameraRig/SpringArm.spring_length = 0.08 if enabled else 5.8
	$CameraRig/SpringArm/Camera.near = 0.05 if enabled else 0.1


func is_first_person() -> bool:
	return _first_person


func set_look_sensitivity_scale(value: float) -> void:
	_look_sensitivity_scale = clampf(value, 0.5, 2.0)


func get_look_sensitivity_scale() -> float:
	return _look_sensitivity_scale


func set_character_variant(index: int) -> void:
	var safe_index := clampi(index, 0, CHARACTER_COLORS.size() - 1)
	var material := color_parts[0].get_active_material(0).duplicate() as StandardMaterial3D
	material.albedo_color = CHARACTER_COLORS[safe_index]
	for part in color_parts:
		part.material_override = material
	$Visual/Cap.visible = safe_index % 2 == 0
	$Visual/Backpack.visible = safe_index % 2 == 1


func set_texture_detail(enabled: bool) -> void:
	var material := color_parts[0].material_override as StandardMaterial3D
	if material != null:
		material.albedo_texture = SUIT_TEXTURE if enabled else null


func apply_damage_and_knockback(origin: Vector3, force: float, damage: int) -> void:
	if _invulnerability > 0.0:
		return
	var away := global_position - origin
	away.y = 0.0
	if away.length_squared() < 0.01:
		away = Vector3.FORWARD
	away = away.normalized()
	velocity.x += away.x * force
	velocity.z += away.z * force
	velocity.y = maxf(velocity.y, force * 0.62)
	_health = maxi(0, _health - damage)
	_invulnerability = 0.45
	health_changed.emit(_health, MAX_HEALTH)
	damaged.emit(damage, _health)
	if _health == 0:
		defeated.emit()


func _apply_look(delta: Vector2) -> void:
	var scaled_delta := delta * _look_sensitivity_scale
	camera_rig.rotation.y -= scaled_delta.x
	camera_rig.rotation.x = clamp(camera_rig.rotation.x - scaled_delta.y, -0.9, 0.35)
