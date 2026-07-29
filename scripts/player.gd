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

var _touch_move := Vector2.ZERO
var _jump_requested := false
var _spawn_transform: Transform3D


func _ready() -> void:
	_spawn_transform = global_transform
	if not OS.has_feature("mobile"):
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _physics_process(delta: float) -> void:
	var desktop_move := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var movement_input := _touch_move if _touch_move.length_squared() > desktop_move.length_squared() else desktop_move
	var yaw_basis := Basis(Vector3.UP, camera_rig.rotation.y)
	var direction := yaw_basis * Vector3(movement_input.x, 0.0, movement_input.y)
	if direction.length_squared() > 1.0:
		direction = direction.normalized()

	var acceleration := ground_acceleration if is_on_floor() else air_acceleration
	velocity.x = move_toward(velocity.x, direction.x * move_speed, acceleration * delta)
	velocity.z = move_toward(velocity.z, direction.z * move_speed, acceleration * delta)

	if not is_on_floor():
		velocity += get_gravity() * delta
	elif _jump_requested or Input.is_action_just_pressed("jump"):
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
	_touch_move = value


func add_touch_look(delta: Vector2) -> void:
	_apply_look(delta * touch_look_sensitivity)


func request_jump() -> void:
	_jump_requested = true


func reset_to_spawn() -> void:
	global_transform = _spawn_transform
	velocity = Vector3.ZERO
	_touch_move = Vector2.ZERO
	camera_rig.rotation = Vector3(-0.22, 0.0, 0.0)


func _apply_look(delta: Vector2) -> void:
	camera_rig.rotation.y -= delta.x
	camera_rig.rotation.x = clamp(camera_rig.rotation.x - delta.y, -0.9, 0.35)
