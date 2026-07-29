class_name GrayboxPlayer
extends CharacterBody3D

@export var move_speed := 6.0
@export var ground_acceleration := 28.0
@export var air_acceleration := 8.0
@export var jump_velocity := 7.5
@export var look_sensitivity := 0.003
@export var touch_look_sensitivity := 0.004

@onready var visual: Node3D = $Visual
@onready var camera_rig: Node3D = $CameraRig

signal health_changed(current: int, maximum: int)
signal defeated

const MAX_HEALTH := 100

var _touch_move := Vector2.ZERO
var _jump_requested := false
var _spawn_transform: Transform3D
var _health := MAX_HEALTH
var _invulnerability := 0.0
var _controls_enabled := true


func _ready() -> void:
	_spawn_transform = global_transform
	floor_snap_length = 0.35
	add_to_group("players")
	health_changed.emit(_health, MAX_HEALTH)
	if not OS.has_feature("mobile"):
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _physics_process(delta: float) -> void:
	_invulnerability = maxf(0.0, _invulnerability - delta)
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
	if _health == 0:
		defeated.emit()


func _apply_look(delta: Vector2) -> void:
	camera_rig.rotation.y -= delta.x
	camera_rig.rotation.x = clamp(camera_rig.rotation.x - delta.y, -0.9, 0.35)
