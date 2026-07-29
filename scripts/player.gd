class_name GrayboxPlayer
extends CharacterBody3D

const CHARACTER_CATALOG := preload("res://scripts/characters/character_catalog.gd")
const HUMANOID_RIG := preload("res://scripts/characters/humanoid_rig.gd")

@export var move_speed := 6.0
@export var ground_acceleration := 28.0
@export var air_acceleration := 8.0
@export var jump_velocity := 7.5
@export var look_sensitivity := 0.003
@export var touch_look_sensitivity := 0.004

@onready var visual: Node3D = $Visual
@onready var camera_rig: Node3D = $CameraRig

signal health_changed(current: int, maximum: int)
signal damaged(amount: int, current: int)
signal defeated
signal push_requested
signal limb_detached(
	part_transform: Transform3D,
	part_scale: Vector3,
	color: Color,
	impulse: Vector3
)

const MAX_HEALTH := 100
const ALL_LIMBS_MASK := HUMANOID_RIG.ALL_BODY_PARTS_MASK
const LIMB_MAX_HEALTH := [24, 34, 34, 20, 20, 38, 38]
const ACCESSORY_MAX_HEALTH := 12
const LIMB_VISUAL_PATHS := [
	NodePath("Visual/Head"),
	NodePath("Visual/LeftArm"),
	NodePath("Visual/RightArm"),
	NodePath("Visual/LeftHand"),
	NodePath("Visual/RightHand"),
	NodePath("Visual/LeftLeg"),
	NodePath("Visual/RightLeg"),
]
const LIMB_HITBOX_PATHS := [
	NodePath("Hitboxes/Head"),
	NodePath("Hitboxes/LeftArm"),
	NodePath("Hitboxes/RightArm"),
	NodePath("Hitboxes/LeftHand"),
	NodePath("Hitboxes/RightHand"),
	NodePath("Hitboxes/LeftLeg"),
	NodePath("Hitboxes/RightLeg"),
]

enum Limb {
	HEAD,
	LEFT_ARM,
	RIGHT_ARM,
	LEFT_HAND,
	RIGHT_HAND,
	LEFT_LEG,
	RIGHT_LEG,
}

enum Accessory {
	CAP = 7,
	BACKPACK,
	LEFT_EAR,
	RIGHT_EAR,
	TAIL,
}

const ACCESSORY_VISUAL_PATHS := {
	Accessory.CAP: NodePath("Visual/Cap"),
	Accessory.BACKPACK: NodePath("Visual/Backpack"),
	Accessory.LEFT_EAR: NodePath("Visual/LeftEar"),
	Accessory.RIGHT_EAR: NodePath("Visual/RightEar"),
	Accessory.TAIL: NodePath("Visual/Tail"),
}

var _touch_move := Vector2.ZERO
var _jump_requested := false
var _spawn_transform: Transform3D
var _health := MAX_HEALTH
var _invulnerability := 0.0
var _controls_enabled := true
var _push_cooldown := 0.0
var _first_person := false
var _look_sensitivity_scale := 1.0
var _walk_phase := 0.0
var _push_animation := 0.0
var _hurt_animation := 0.0
var _limb_health := PackedInt32Array()
var _limb_mask := ALL_LIMBS_MASK
var _head_accessory_health := ACCESSORY_MAX_HEALTH
var _torso_accessory_health := ACCESSORY_MAX_HEALTH
var _character_color: Color = CHARACTER_CATALOG.COLORS[0]
var _character_variant_index := 0
var _defeated_state := false
var _gameplay_collision_layer := 0
var _gameplay_collision_mask := 0


func _ready() -> void:
	_spawn_transform = global_transform
	_gameplay_collision_layer = collision_layer
	_gameplay_collision_mask = collision_mask
	floor_snap_length = 0.35
	add_to_group("players")
	_reset_limbs()
	health_changed.emit(_health, MAX_HEALTH)
	if not OS.has_feature("mobile"):
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _physics_process(delta: float) -> void:
	_invulnerability = maxf(0.0, _invulnerability - delta)
	_push_cooldown = maxf(0.0, _push_cooldown - delta)
	_push_animation = maxf(0.0, _push_animation - delta)
	_hurt_animation = maxf(0.0, _hurt_animation - delta)
	var desktop_move := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var movement_input := _touch_move if _touch_move.length_squared() > desktop_move.length_squared() else desktop_move
	if not _controls_enabled:
		movement_input = Vector2.ZERO
	var yaw_basis := Basis(Vector3.UP, camera_rig.rotation.y)
	var direction := yaw_basis * Vector3(movement_input.x, 0.0, movement_input.y)
	if direction.length_squared() > 1.0:
		direction = direction.normalized()

	var movement_scale := _get_leg_movement_scale()
	var jump_pressed := _jump_requested or Input.is_action_just_pressed("jump")
	var acceleration := ground_acceleration if is_on_floor() else air_acceleration
	velocity.x = move_toward(
		velocity.x,
		direction.x * move_speed * movement_scale,
		acceleration * delta
	)
	velocity.z = move_toward(
		velocity.z,
		direction.z * move_speed * movement_scale,
		acceleration * delta
	)
	if not is_on_floor():
		velocity += get_gravity() * delta
	elif _controls_enabled and jump_pressed:
		velocity.y = jump_velocity * movement_scale
	_jump_requested = false
	if _controls_enabled and Input.is_action_just_pressed("push"):
		request_push()

	if direction.length_squared() > 0.01:
		visual.rotation.y = lerp_angle(visual.rotation.y, atan2(direction.x, direction.z), 12.0 * delta)
	$Hitboxes.rotation.y = visual.rotation.y
	_walk_phase = HUMANOID_RIG.animate(
		visual,
		delta,
		Vector2(velocity.x, velocity.z).length(),
		_walk_phase,
		is_on_floor(),
		clampf(_push_animation / 0.30, 0.0, 1.0),
		clampf(_hurt_animation / 0.25, 0.0, 1.0)
	)

	move_and_slide()
	if global_position.y < -8.0 and not _defeated_state:
		_take_damage(MAX_HEALTH, -1, global_position)


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
	if (
		not _controls_enabled
		or _push_cooldown > 0.0
		or not (_is_limb_attached(Limb.LEFT_ARM) or _is_limb_attached(Limb.RIGHT_ARM))
	):
		return
	_push_cooldown = 0.72
	_push_animation = 0.30
	push_requested.emit()


func set_controls_enabled(enabled: bool) -> void:
	_controls_enabled = enabled and not _defeated_state
	if not _controls_enabled:
		_touch_move = Vector2.ZERO
		_jump_requested = false


func reset_to_spawn() -> void:
	_defeated_state = false
	collision_layer = _gameplay_collision_layer
	collision_mask = _gameplay_collision_mask
	global_transform = _spawn_transform
	velocity = Vector3.ZERO
	_touch_move = Vector2.ZERO
	camera_rig.rotation = Vector3(-0.22, 0.0, 0.0)
	_reset_limbs()
	heal_full(false)
	visual.visible = not _first_person


func enter_spectator() -> void:
	if not _defeated_state:
		return
	_controls_enabled = false
	_touch_move = Vector2.ZERO
	_jump_requested = false
	velocity = Vector3.ZERO
	collision_layer = 0
	collision_mask = 0
	_limb_mask = 0
	visual.visible = false
	global_position = Vector3(0.0, 15.0, 0.0)
	camera_rig.rotation = Vector3(-0.85, 0.0, 0.0)


func is_defeated() -> bool:
	return _defeated_state


func set_spawn_transform(spawn_transform: Transform3D, teleport := true) -> void:
	_spawn_transform = spawn_transform
	if teleport:
		reset_to_spawn()


func heal_full(restore_limbs := true) -> void:
	if restore_limbs:
		_reset_limbs()
	_health = MAX_HEALTH
	_invulnerability = 0.0
	health_changed.emit(_health, MAX_HEALTH)


func get_health() -> int:
	return _health


func get_visual_yaw() -> float:
	return visual.rotation.y


func get_limb_mask() -> int:
	return _limb_mask


func get_aim_forward() -> Vector3:
	var forward := camera_rig.global_basis * Vector3.FORWARD
	forward.y = 0.0
	return forward.normalized()


func get_shoot_origin() -> Vector3:
	return $CameraRig/SpringArm/Camera.global_position


func get_shoot_direction() -> Vector3:
	return (
		-$CameraRig/SpringArm/Camera.global_basis.z
	).normalized()


func apply_shot_damage(damage: int, hit_position: Vector3) -> void:
	if _defeated_state:
		return
	_invulnerability = 0.0
	_take_damage(maxi(1, damage), _find_closest_limb(hit_position), hit_position)


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
	velocity.y = maxf(velocity.y, lift_force)
	var target_limb := (
		Limb.LEFT_LEG
		if _limb_health[Limb.LEFT_LEG] >= _limb_health[Limb.RIGHT_LEG]
		else Limb.RIGHT_LEG
	)
	_take_damage(damage, target_limb, global_position + Vector3.DOWN)


func set_first_person(enabled: bool) -> void:
	_first_person = enabled
	visual.visible = not enabled and not _defeated_state
	$CameraRig/SpringArm.spring_length = 0.08 if enabled else 5.8
	$CameraRig/SpringArm/Camera.near = 0.05 if enabled else 0.1


func is_first_person() -> bool:
	return _first_person


func set_look_sensitivity_scale(value: float) -> void:
	_look_sensitivity_scale = clampf(value, 0.5, 2.0)


func get_look_sensitivity_scale() -> float:
	return _look_sensitivity_scale


func set_character_variant(index: int) -> void:
	var safe_index: int = CHARACTER_CATALOG.sanitize_index(index)
	_character_variant_index = safe_index
	_character_color = HUMANOID_RIG.apply_variant(visual, safe_index)
	HUMANOID_RIG.apply_limb_mask(visual, _limb_mask, safe_index)


func set_texture_detail(enabled: bool) -> void:
	HUMANOID_RIG.set_texture_detail(visual, enabled)


func set_model_quality(rounded: bool) -> void:
	HUMANOID_RIG.set_model_quality(visual, rounded)


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
	_take_damage(damage, _find_closest_limb(origin), origin)


func apply_limb_damage(limb: int, damage: int, origin: Vector3) -> void:
	if limb < Limb.HEAD or limb > Limb.RIGHT_LEG or damage <= 0:
		return
	_take_damage(damage, limb, origin)


func _take_damage(damage: int, limb: int, origin: Vector3) -> void:
	if _invulnerability > 0.0 or _defeated_state:
		return
	var safe_damage := maxi(1, damage)
	_health = maxi(0, _health - safe_damage)
	_invulnerability = 0.45
	_hurt_animation = 0.25
	if limb >= Limb.HEAD:
		if limb == Limb.HEAD:
			_damage_accessory_group(
				[Accessory.CAP, Accessory.LEFT_EAR, Accessory.RIGHT_EAR],
				safe_damage,
				origin,
				true
			)
		_damage_limb(limb, safe_damage, origin)
	else:
		_damage_accessory_group(
			[Accessory.BACKPACK, Accessory.TAIL],
			safe_damage,
			origin,
			false
		)
	health_changed.emit(_health, MAX_HEALTH)
	damaged.emit(safe_damage, _health)
	if _health == 0:
		_defeated_state = true
		defeated.emit()


func _damage_limb(limb: int, damage: int, origin: Vector3) -> void:
	if not _is_limb_attached(limb):
		return
	_limb_health[limb] = maxi(0, _limb_health[limb] - damage)
	if _limb_health[limb] == 0:
		_detach_limb(limb, origin)


func _find_closest_limb(origin: Vector3) -> int:
	var closest_limb := -1
	var closest_distance := (
		($Hitboxes/Torso as Area3D).global_position.distance_squared_to(origin)
	)
	for limb in LIMB_VISUAL_PATHS.size():
		if not _is_limb_attached(limb):
			continue
		var hitbox := get_node(LIMB_HITBOX_PATHS[limb]) as Area3D
		var distance := hitbox.global_position.distance_squared_to(origin)
		if distance < closest_distance:
			closest_distance = distance
			closest_limb = limb
	return closest_limb


func _detach_limb(limb: int, origin: Vector3) -> void:
	if limb == Limb.HEAD:
		for accessory in [Accessory.CAP, Accessory.LEFT_EAR, Accessory.RIGHT_EAR]:
			_detach_accessory(accessory, origin)
	_detach_single_limb(limb, origin)
	if limb == Limb.LEFT_ARM:
		_detach_single_limb(Limb.LEFT_HAND, origin)
	elif limb == Limb.RIGHT_ARM:
		_detach_single_limb(Limb.RIGHT_HAND, origin)


func _detach_single_limb(limb: int, origin: Vector3) -> void:
	if not _is_limb_attached(limb):
		return
	_limb_mask &= ~(1 << limb)
	_limb_health[limb] = 0
	var mesh := get_node(LIMB_VISUAL_PATHS[limb]) as MeshInstance3D
	var hitbox := get_node(LIMB_HITBOX_PATHS[limb]) as Area3D
	var collision := hitbox.get_node("Shape") as CollisionShape3D
	var piece_transform := Transform3D(mesh.global_basis.orthonormalized(), mesh.global_position)
	var impulse := mesh.global_position - origin
	if impulse.length_squared() < 0.01:
		impulse = Vector3.UP
	impulse = impulse.normalized() * 2.4 + Vector3.UP * 1.8
	mesh.visible = false
	collision.set_deferred("disabled", true)
	if limb == Limb.HEAD:
		$Visual/Visor.visible = false
	limb_detached.emit(piece_transform, mesh.scale, _get_mesh_color(mesh), impulse)


func _damage_accessory_group(
	accessories: Array,
	damage: int,
	origin: Vector3,
	head_group: bool
) -> void:
	var has_visible_accessory := false
	for accessory: int in accessories:
		var mesh := get_node(ACCESSORY_VISUAL_PATHS[accessory]) as MeshInstance3D
		has_visible_accessory = has_visible_accessory or mesh.visible
	if not has_visible_accessory:
		return
	if head_group:
		_head_accessory_health = maxi(0, _head_accessory_health - damage)
		if _head_accessory_health > 0:
			return
	else:
		_torso_accessory_health = maxi(0, _torso_accessory_health - damage)
		if _torso_accessory_health > 0:
			return
	for accessory: int in accessories:
		_detach_accessory(accessory, origin)


func _detach_accessory(accessory: int, origin: Vector3) -> void:
	if not _is_limb_attached(accessory):
		return
	var mesh := get_node(ACCESSORY_VISUAL_PATHS[accessory]) as MeshInstance3D
	if not mesh.visible:
		return
	_limb_mask &= ~(1 << accessory)
	var piece_transform := Transform3D(mesh.global_basis.orthonormalized(), mesh.global_position)
	var impulse := mesh.global_position - origin
	if impulse.length_squared() < 0.01:
		impulse = Vector3.UP
	impulse = impulse.normalized() * 1.8 + Vector3.UP * 1.35
	mesh.visible = false
	limb_detached.emit(piece_transform, mesh.scale, _get_mesh_color(mesh), impulse)


func _reset_limbs() -> void:
	_limb_mask = ALL_LIMBS_MASK
	_limb_health = PackedInt32Array(LIMB_MAX_HEALTH)
	_head_accessory_health = ACCESSORY_MAX_HEALTH
	_torso_accessory_health = ACCESSORY_MAX_HEALTH
	for limb in LIMB_VISUAL_PATHS.size():
		var hitbox := get_node(LIMB_HITBOX_PATHS[limb]) as Area3D
		(hitbox.get_node("Shape") as CollisionShape3D).set_deferred("disabled", false)
	HUMANOID_RIG.apply_limb_mask(visual, _limb_mask, _character_variant_index)


func _is_limb_attached(limb: int) -> bool:
	return (_limb_mask & (1 << limb)) != 0


func _get_mesh_color(mesh: MeshInstance3D) -> Color:
	var material := mesh.material_override as StandardMaterial3D
	if material == null:
		material = mesh.get_active_material(0) as StandardMaterial3D
	return material.albedo_color if material != null else _character_color


func _get_leg_movement_scale() -> float:
	var leg_count := int(_is_limb_attached(Limb.LEFT_LEG)) + int(
		_is_limb_attached(Limb.RIGHT_LEG)
	)
	if leg_count == 2:
		return 1.0
	if leg_count == 1:
		return 0.72
	return 0.48


func _apply_look(delta: Vector2) -> void:
	var scaled_delta := delta * _look_sensitivity_scale
	camera_rig.rotation.y -= scaled_delta.x
	camera_rig.rotation.x = clamp(camera_rig.rotation.x - scaled_delta.y, -0.9, 0.35)
