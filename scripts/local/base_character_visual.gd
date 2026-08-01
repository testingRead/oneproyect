class_name BaseCharacterVisual
extends Node3D

const WEAPONS := preload("res://shared/weapon_profiles.gd")

@onready var torso: Node3D = $Model/Torso
@onready var pelvis: Node3D = $Model/Pelvis
@onready var head: Node3D = $Model/Head
@onready var left_arm: Node3D = $Model/LeftArmPivot
@onready var right_arm: Node3D = $Model/RightArmPivot
@onready var left_leg: Node3D = $Model/LeftLegPivot
@onready var right_leg: Node3D = $Model/RightLegPivot
@onready var left_foot: Node3D = $Model/LeftLegPivot/Foot
@onready var right_foot: Node3D = $Model/RightLegPivot/Foot
@onready var left_eye: Node3D = $Model/LeftEye
@onready var right_eye: Node3D = $Model/RightEye

var _phase := 0.0
var _movement_ratio := 0.0
var _stature := 1.0
var _left_ground_offset := 0.0
var _right_ground_offset := 0.0
var _left_ground_roll := 0.0
var _right_ground_roll := 0.0
var _push_remaining := 0.0
var _kick_remaining := 0.0
var _take_remaining := 0.0
var _throw_remaining := 0.0
var _goalkeeper_remaining := 0.0
var _goalkeeper_side := 0
var _goalkeeper_level := 1
var _heavy_carry := false
var _bat_remaining := 0.0
var _bat_charged := false
var _bat_mesh: Node3D
var _bat_barrel_material: StandardMaterial3D
var _ball_shot_remaining := 0.0
var _look_pitch := 0.0
var _combat_pose := false
var _shoot_remaining := 0.0
var _reload_remaining := 0.0
var _reload_duration := 1.0
var _weapon_mesh: Node3D
var _weapon_id := WEAPONS.Id.P9
var _muzzle_flash: MeshInstance3D


func set_stature(stature: float) -> void:
	_stature = clampf(stature, 0.8, 1.2)
	$Model.scale = Vector3(1.0, _stature, 1.0)


func set_team_color(team: StringName) -> void:
	_set_body_color(
		Color(0.88, 0.2, 0.18)
		if team == &"away"
		else Color(0.12, 0.5, 0.96)
	)


func set_player_slot_color(slot: int) -> void:
	var palette := [
		Color(0.12, 0.5, 0.96),
		Color(0.94, 0.22, 0.16),
		Color(0.18, 0.76, 0.38),
		Color(0.94, 0.62, 0.08),
		Color(0.58, 0.28, 0.92),
		Color(0.08, 0.74, 0.76),
		Color(0.92, 0.3, 0.66),
		Color(0.72, 0.76, 0.18),
	]
	_set_body_color(palette[posmod(slot, palette.size())])


func _set_body_color(color: Color) -> void:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.82
	for path in [
		"Model/Torso",
		"Model/Pelvis",
		"Model/LeftShoulder",
		"Model/RightShoulder",
		"Model/LeftArmPivot/Arm",
		"Model/RightArmPivot/Arm",
		"Model/LeftLegPivot/Leg",
		"Model/RightLegPivot/Leg",
	]:
		var part := get_node_or_null(path) as MeshInstance3D
		if part != null:
			part.material_override = material


func update_motion(
	delta: float,
	horizontal_speed: float,
	maximum_speed: float,
	on_floor: bool
) -> void:
	_movement_ratio = clampf(
		horizontal_speed / maxf(0.01, maximum_speed),
		0.0,
		1.0
	)
	if on_floor and _movement_ratio > 0.02:
		_phase = fmod(
			_phase + delta * lerpf(5.2, 10.2, _movement_ratio),
			TAU
		)
	var grounded_weight := 1.0 if on_floor else 0.0
	var swing := sin(_phase) * lerpf(0.18, 0.72, _movement_ratio)
	var lift := maxf(0.0, sin(_phase)) * _movement_ratio
	left_arm.rotation.x = lerpf(left_arm.rotation.x, swing, delta * 14.0)
	right_arm.rotation.x = lerpf(right_arm.rotation.x, -swing, delta * 14.0)
	left_arm.rotation.y = lerpf(left_arm.rotation.y, 0.0, delta * 13.0)
	right_arm.rotation.y = lerpf(right_arm.rotation.y, 0.0, delta * 13.0)
	left_arm.rotation.z = lerpf(left_arm.rotation.z, 0.0, delta * 13.0)
	right_arm.rotation.z = lerpf(right_arm.rotation.z, 0.0, delta * 13.0)
	left_leg.rotation.x = lerpf(
		left_leg.rotation.x,
		-swing * grounded_weight,
		delta * 14.0
	)
	right_leg.rotation.x = lerpf(
		right_leg.rotation.x,
		swing * grounded_weight,
		delta * 14.0
	)
	left_foot.rotation.x = PI * 0.5 - left_leg.rotation.x * 0.42
	right_foot.rotation.x = PI * 0.5 - right_leg.rotation.x * 0.42
	left_foot.rotation.z = lerpf(
		left_foot.rotation.z,
		_left_ground_roll if on_floor else 0.0,
		delta * 12.0
	)
	right_foot.rotation.z = lerpf(
		right_foot.rotation.z,
		_right_ground_roll if on_floor else 0.0,
		delta * 12.0
	)
	var body_bob := absf(sin(_phase * 2.0)) * 0.025 * _movement_ratio
	var look_down := clampf(-_look_pitch / 0.82, 0.0, 1.0)
	var torso_look := -_look_pitch * 0.22
	torso.position.y = 1.17 + body_bob
	pelvis.position.y = 0.79 + body_bob * 0.55
	head.position.y = 1.59 + body_bob - look_down * 0.075
	head.rotation.x = lerpf(head.rotation.x, -_look_pitch * 0.88, delta * 16.0)
	torso.rotation.z = lerpf(
		torso.rotation.z,
		-sin(_phase) * 0.035 * _movement_ratio,
		delta * 12.0
	)
	pelvis.rotation.z = lerpf(
		pelvis.rotation.z,
		sin(_phase) * 0.055 * _movement_ratio,
		delta * 12.0
	)
	torso.rotation.y = lerpf(torso.rotation.y, 0.0, delta * 12.0)
	if not on_floor:
		left_arm.rotation.x = lerpf(left_arm.rotation.x, -0.32, delta * 9.0)
		right_arm.rotation.x = lerpf(right_arm.rotation.x, -0.32, delta * 9.0)
		left_leg.rotation.x = lerpf(left_leg.rotation.x, 0.16, delta * 9.0)
		right_leg.rotation.x = lerpf(right_leg.rotation.x, -0.12, delta * 9.0)
	if _push_remaining > 0.0:
		_push_remaining = maxf(0.0, _push_remaining - delta)
		var push_weight := sin((_push_remaining / 0.42) * PI)
		left_arm.rotation.x = lerpf(left_arm.rotation.x, -1.28, push_weight)
		right_arm.rotation.x = lerpf(right_arm.rotation.x, -1.28, push_weight)
		torso.rotation.x = lerpf(torso.rotation.x, 0.16, push_weight)
	else:
		torso.rotation.x = lerpf(torso.rotation.x, torso_look, delta * 12.0)
	if _kick_remaining > 0.0:
		_kick_remaining = maxf(0.0, _kick_remaining - delta)
		var kick_progress := 1.0 - _kick_remaining / 0.5
		var kick_weight := sin(kick_progress * PI)
		right_leg.rotation.x = lerpf(right_leg.rotation.x, -1.05, kick_weight)
		right_foot.rotation.x = lerpf(
			right_foot.rotation.x,
			0.2,
			kick_weight
		)
		left_arm.rotation.x = lerpf(left_arm.rotation.x, 0.38, kick_weight)
		right_arm.rotation.x = lerpf(right_arm.rotation.x, -0.52, kick_weight)
		torso.rotation.x = lerpf(torso.rotation.x, 0.12, kick_weight)
	if _take_remaining > 0.0:
		_take_remaining = maxf(0.0, _take_remaining - delta)
		var take_progress := 1.0 - _take_remaining / 0.62
		var take_weight := sin(take_progress * PI)
		right_arm.rotation.x = lerpf(right_arm.rotation.x, -0.78, take_weight)
		left_arm.rotation.x = lerpf(left_arm.rotation.x, 0.22, take_weight)
		torso.rotation.x = lerpf(torso.rotation.x, 0.34, take_weight)
		torso.position.y = lerpf(torso.position.y, 1.05, take_weight)
		pelvis.position.y = lerpf(pelvis.position.y, 0.67, take_weight)
		head.position.y = lerpf(head.position.y, 1.48, take_weight)
	if _throw_remaining > 0.0:
		_throw_remaining = maxf(0.0, _throw_remaining - delta)
		var throw_progress := 1.0 - _throw_remaining / 0.62
		var throw_weight := sin(throw_progress * PI)
		var throw_angle := lerpf(
			0.72,
			-1.3,
			smoothstep(0.12, 0.78, throw_progress)
		)
		right_arm.rotation.x = lerpf(
			right_arm.rotation.x,
			throw_angle,
			throw_weight
		)
		left_arm.rotation.x = lerpf(left_arm.rotation.x, 0.5, throw_weight)
		torso.rotation.x = lerpf(torso.rotation.x, 0.18, throw_weight)
		torso.rotation.z = lerpf(torso.rotation.z, -0.12, throw_weight)
	if _goalkeeper_remaining > 0.0:
		_goalkeeper_remaining = maxf(0.0, _goalkeeper_remaining - delta)
		var dive_weight := sin((_goalkeeper_remaining / 0.72) * PI)
		left_arm.rotation.x = lerpf(left_arm.rotation.x, -1.62, dive_weight)
		right_arm.rotation.x = lerpf(right_arm.rotation.x, -1.62, dive_weight)
		left_arm.rotation.z = lerpf(
			left_arm.rotation.z,
			float(_goalkeeper_side) * -0.95,
			dive_weight
		)
		right_arm.rotation.z = lerpf(
			right_arm.rotation.z,
			float(_goalkeeper_side) * -0.95,
			dive_weight
		)
		torso.rotation.z = lerpf(
			torso.rotation.z,
			float(_goalkeeper_side) * 0.58,
			dive_weight
		)
		torso.position.x = lerpf(
			torso.position.x,
			float(_goalkeeper_side) * 0.28,
			dive_weight
		)
		torso.rotation.x = lerpf(
			torso.rotation.x,
			0.28 + float(_goalkeeper_level) * 0.05,
			dive_weight
		)
	if _heavy_carry:
		# Both hands meet in front of the chest so a large bomb reads as heavy.
		left_arm.rotation.x = lerpf(left_arm.rotation.x, -1.05, delta * 18.0)
		right_arm.rotation.x = lerpf(right_arm.rotation.x, -1.05, delta * 18.0)
		left_arm.rotation.z = lerpf(left_arm.rotation.z, -0.5, delta * 18.0)
		right_arm.rotation.z = lerpf(right_arm.rotation.z, 0.5, delta * 18.0)
		torso.rotation.x = lerpf(torso.rotation.x, 0.16, delta * 12.0)
	if _bat_remaining > 0.0:
		_bat_remaining = maxf(0.0, _bat_remaining - delta)
		var bat_progress := 1.0 - _bat_remaining / 0.46
		var bat_weight := sin(clampf(bat_progress, 0.0, 1.0) * PI)
		var sweep := smoothstep(0.12, 0.78, bat_progress)
		# One-handed baseball sweep: wind up over the anatomical right shoulder,
		# rotate the torso, then follow through across the body.
		right_arm.rotation.x = lerpf(right_arm.rotation.x, -1.28, bat_weight)
		right_arm.rotation.z = lerpf(right_arm.rotation.z, lerpf(-0.72, 0.92, sweep), bat_weight)
		right_arm.rotation.y = lerpf(right_arm.rotation.y, lerpf(-0.5, 0.7, sweep), bat_weight)
		left_arm.rotation.x = lerpf(left_arm.rotation.x, -0.38, bat_weight)
		left_arm.rotation.z = lerpf(left_arm.rotation.z, 0.32, bat_weight)
		torso.rotation.y = lerpf(torso.rotation.y, lerpf(0.52, -0.62, sweep), bat_weight)
		torso.rotation.x = lerpf(torso.rotation.x, 0.1, bat_weight)
		if _bat_mesh != null:
			_bat_mesh.rotation.z = lerpf(-0.28, 0.62, sweep)
			_bat_mesh.rotation.x = lerpf(-0.2, 0.18, sweep)
	if _ball_shot_remaining > 0.0:
		_ball_shot_remaining = maxf(0.0, _ball_shot_remaining - delta)
		var shot_progress := 1.0 - _ball_shot_remaining / 0.34
		var shot_weight := sin(shot_progress * PI)
		left_arm.rotation.x = lerpf(left_arm.rotation.x, -1.18, shot_weight)
		right_arm.rotation.x = lerpf(right_arm.rotation.x, -1.18, shot_weight)
		left_arm.rotation.z = lerpf(left_arm.rotation.z, -0.2, shot_weight)
		right_arm.rotation.z = lerpf(right_arm.rotation.z, 0.2, shot_weight)
		torso.rotation.x = lerpf(torso.rotation.x, 0.16, shot_weight)
	if _combat_pose:
		var long_weapon := _weapon_id != WEAPONS.Id.P9
		left_arm.rotation.x = lerpf(
			left_arm.rotation.x, -1.28 if long_weapon else -1.08, delta * 18.0
		)
		right_arm.rotation.x = lerpf(right_arm.rotation.x, -1.2, delta * 18.0)
		left_arm.rotation.z = lerpf(
			left_arm.rotation.z, -0.32 if long_weapon else -0.18, delta * 15.0
		)
		right_arm.rotation.z = lerpf(
			right_arm.rotation.z, 0.08 if long_weapon else 0.12, delta * 15.0
		)
		torso.rotation.x = lerpf(torso.rotation.x, 0.08, delta * 14.0)
	if _shoot_remaining > 0.0:
		_shoot_remaining = maxf(0.0, _shoot_remaining - delta)
		var recoil_weight := sin((_shoot_remaining / 0.16) * PI)
		right_arm.rotation.x = lerpf(right_arm.rotation.x, -0.86, recoil_weight)
		torso.rotation.x = lerpf(torso.rotation.x, -0.05, recoil_weight)
		if is_instance_valid(_weapon_mesh):
			_weapon_mesh.position.z = lerpf(_weapon_mesh.position.z, -0.08, recoil_weight)
		if is_instance_valid(_muzzle_flash):
			_muzzle_flash.visible = _shoot_remaining > 0.085
	elif is_instance_valid(_weapon_mesh):
		_weapon_mesh.position.z = lerpf(_weapon_mesh.position.z, 0.0, delta * 16.0)
		if is_instance_valid(_muzzle_flash):
			_muzzle_flash.visible = false
	if _reload_remaining > 0.0:
		_reload_remaining = maxf(0.0, _reload_remaining - delta)
		var reload_progress := 1.0 - _reload_remaining / _reload_duration
		var reload_weight := sin(reload_progress * PI)
		right_arm.rotation.x = lerpf(right_arm.rotation.x, -0.42, reload_weight)
		right_arm.rotation.z = lerpf(right_arm.rotation.z, 0.72, reload_weight)
		left_arm.rotation.x = lerpf(left_arm.rotation.x, -0.52, reload_weight)
		if is_instance_valid(_weapon_mesh):
			_weapon_mesh.rotation.x = lerpf(0.0, 0.72, reload_weight)
	elif is_instance_valid(_weapon_mesh):
		_weapon_mesh.rotation.x = lerpf(_weapon_mesh.rotation.x, 0.0, delta * 15.0)
	$Model/LeftLegPivot.position.y = (
		0.72
		+ _left_ground_offset * grounded_weight
		+ lift * 0.025 * grounded_weight
	)
	$Model/RightLegPivot.position.y = (
		0.72
		+ _right_ground_offset * grounded_weight
		+ maxf(0.0, -sin(_phase)) * 0.025 * _movement_ratio * grounded_weight
	)


func set_foot_contacts(
	left_height: float,
	right_height: float,
	left_normal: Vector3,
	right_normal: Vector3
) -> void:
	_left_ground_offset = clampf(left_height, -0.16, 0.16)
	_right_ground_offset = clampf(right_height, -0.16, 0.16)
	_left_ground_roll = atan2(-left_normal.x, maxf(0.01, left_normal.y))
	_right_ground_roll = atan2(-right_normal.x, maxf(0.01, right_normal.y))


func clear_foot_contacts() -> void:
	_left_ground_offset = 0.0
	_right_ground_offset = 0.0
	_left_ground_roll = 0.0
	_right_ground_roll = 0.0


func trigger_push() -> void:
	_push_remaining = 0.42


func is_pushing() -> bool:
	return _push_remaining > 0.0


func trigger_kick() -> void:
	_kick_remaining = 0.5


func is_kicking() -> bool:
	return _kick_remaining > 0.0


func set_look_pitch(pitch: float, first_person: bool) -> void:
	_look_pitch = clampf(pitch, -0.82, 0.28) if first_person else 0.0


func set_first_person_presentation(enabled: bool) -> void:
	# Keep the body, arms and legs visible. Only the local head is hidden to
	# avoid placing the near plane inside its mesh; remote avatars remain whole.
	head.visible = not enabled
	left_eye.visible = not enabled
	right_eye.visible = not enabled


func trigger_take() -> void:
	_take_remaining = 0.62


func trigger_throw() -> void:
	_throw_remaining = 0.62


func trigger_goalkeeper_dive(side: int, level: int) -> void:
	_goalkeeper_side = clampi(side, -1, 1)
	_goalkeeper_level = clampi(level, 0, 2)
	_goalkeeper_remaining = 0.72


func set_heavy_carry(enabled: bool) -> void:
	_heavy_carry = enabled


func set_bat_equipped(enabled: bool) -> void:
	if enabled and _bat_mesh == null:
		_bat_mesh = _build_bat_mesh()
		$Model/RightArmPivot/ItemSocket.add_child(_bat_mesh)
	if enabled and _bat_mesh != null:
		_bat_mesh.visible = enabled
	elif not enabled and _bat_mesh != null:
		_bat_mesh.queue_free()
		_bat_mesh = null
		_bat_barrel_material = null
	if enabled and _bat_mesh != null:
		_bat_mesh.rotation = Vector3(-0.2, 0.0, -0.28)


func trigger_bat_swing(charged: bool) -> void:
	_bat_charged = charged
	_bat_remaining = 0.46
	if _bat_mesh != null:
		_bat_mesh.scale = Vector3.ONE * (1.18 if charged else 1.0)


func set_bat_charge_ratio(ratio: float) -> void:
	if not is_instance_valid(_bat_mesh) or _bat_barrel_material == null:
		return
	var weight := clampf(ratio, 0.0, 1.0)
	_bat_barrel_material.albedo_color = Color(0.62, 0.43, 0.18).lerp(
		Color(1.0, 0.16, 0.035), weight
	)
	_bat_barrel_material.emission_enabled = weight > 0.7
	_bat_barrel_material.emission = Color(1.0, 0.08, 0.01) * weight
	_bat_barrel_material.emission_energy_multiplier = lerpf(0.0, 2.4, weight)
	_bat_mesh.scale = Vector3.ONE * lerpf(1.0, 1.1, weight)


func trigger_ball_shot() -> void:
	_ball_shot_remaining = 0.34


func set_shooter_weapon(enabled: bool, weapon_id := 0) -> void:
	_combat_pose = enabled
	_weapon_id = weapon_id
	if is_instance_valid(_weapon_mesh):
		_weapon_mesh.queue_free()
		_weapon_mesh = null
		_muzzle_flash = null
	if not enabled:
		_shoot_remaining = 0.0
		_reload_remaining = 0.0
		return
	_weapon_mesh = _build_weapon_mesh(weapon_id)
	$Model/RightArmPivot/ItemSocket.add_child(_weapon_mesh)


func trigger_shoot() -> void:
	_shoot_remaining = 0.16
	if is_instance_valid(_muzzle_flash):
		_muzzle_flash.visible = true


func trigger_reload(duration: float) -> void:
	_reload_duration = maxf(0.2, duration)
	_reload_remaining = _reload_duration


func is_shooting() -> bool:
	return _shoot_remaining > 0.0


func is_reloading() -> bool:
	return _reload_remaining > 0.0


func _build_weapon_mesh(weapon_id: int) -> Node3D:
	var root := Node3D.new()
	root.name = "ShooterWeapon"
	root.position = Vector3(0.0, -0.03, 0.08)
	root.rotation = Vector3(0.0, PI, 0.0)
	var dark := StandardMaterial3D.new()
	dark.albedo_color = Color(0.055, 0.07, 0.085)
	dark.metallic = 0.55
	dark.roughness = 0.36
	var accent := StandardMaterial3D.new()
	accent.albedo_color = Color(0.9, 0.24, 0.08)
	accent.metallic = 0.2
	accent.roughness = 0.48
	var length := 0.48
	var receiver := Vector3(0.15, 0.13, 0.34)
	if weapon_id == WEAPONS.Id.C16:
		length = 0.92
		receiver = Vector3(0.17, 0.15, 0.55)
	elif weapon_id == WEAPONS.Id.T12:
		length = 1.02
		receiver = Vector3(0.19, 0.17, 0.5)
	_add_weapon_box(root, "Receiver", receiver, Vector3.ZERO, dark)
	_add_weapon_box(root, "Grip", Vector3(0.12, 0.28, 0.15), Vector3(0.0, -0.2, 0.1), accent)
	_add_weapon_box(root, "Sight", Vector3(0.045, 0.06, 0.07), Vector3(0.0, 0.11, -receiver.z * 0.42), accent)
	var barrel_mesh := CylinderMesh.new()
	barrel_mesh.top_radius = 0.026 if weapon_id != WEAPONS.Id.T12 else 0.038
	barrel_mesh.bottom_radius = barrel_mesh.top_radius
	barrel_mesh.height = length * 0.52
	barrel_mesh.radial_segments = 8
	var barrel := MeshInstance3D.new()
	barrel.name = "Barrel"
	barrel.mesh = barrel_mesh
	barrel.material_override = dark
	barrel.rotation.x = PI * 0.5
	barrel.position.z = -receiver.z * 0.5 - length * 0.26
	barrel.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(barrel)
	var flash_mesh := SphereMesh.new()
	flash_mesh.radius = 0.075 if weapon_id != WEAPONS.Id.T12 else 0.11
	flash_mesh.height = flash_mesh.radius * 1.45
	flash_mesh.radial_segments = 6
	flash_mesh.rings = 3
	var flash_material := StandardMaterial3D.new()
	flash_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	flash_material.albedo_color = Color(1.0, 0.68, 0.08)
	flash_material.emission_enabled = true
	flash_material.emission = Color(1.0, 0.18, 0.015)
	flash_material.emission_energy_multiplier = 2.2
	_muzzle_flash = MeshInstance3D.new()
	_muzzle_flash.name = "MuzzleFlash"
	_muzzle_flash.mesh = flash_mesh
	_muzzle_flash.material_override = flash_material
	_muzzle_flash.position.z = barrel.position.z - length * 0.28
	_muzzle_flash.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_muzzle_flash.visible = false
	root.add_child(_muzzle_flash)
	return root


func _add_weapon_box(
	root: Node3D,
	part_name: String,
	size: Vector3,
	position_value: Vector3,
	material: Material
) -> void:
	var mesh := BoxMesh.new()
	mesh.size = size
	var part := MeshInstance3D.new()
	part.name = part_name
	part.mesh = mesh
	part.position = position_value
	part.material_override = material
	part.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(part)


func _build_bat_mesh() -> Node3D:
	var root := Node3D.new()
	root.name = "ArenaBat"
	root.position = Vector3(0.0, -0.02, 0.0)
	root.rotation = Vector3(-0.2, 0.0, -0.28)
	var handle := MeshInstance3D.new()
	var handle_mesh := CylinderMesh.new()
	handle_mesh.top_radius = 0.035
	handle_mesh.bottom_radius = 0.045
	handle_mesh.height = 0.55
	handle.mesh = handle_mesh
	var handle_material := StandardMaterial3D.new()
	handle_material.albedo_color = Color(0.18, 0.07, 0.025)
	handle.material_override = handle_material
	handle.position.y = 0.25
	root.add_child(handle)
	var barrel := MeshInstance3D.new()
	var barrel_mesh := CylinderMesh.new()
	barrel_mesh.top_radius = 0.11
	barrel_mesh.bottom_radius = 0.075
	barrel_mesh.height = 0.72
	barrel.mesh = barrel_mesh
	var barrel_material := StandardMaterial3D.new()
	barrel_material.albedo_color = Color(0.78, 0.2, 0.12) if _bat_charged else Color(0.62, 0.43, 0.18)
	barrel_material.roughness = 0.68
	barrel.material_override = barrel_material
	_bat_barrel_material = barrel_material
	barrel.position.y = 0.85
	root.add_child(barrel)
	return root


func get_movement_ratio() -> float:
	return _movement_ratio


func get_visual_foot_height() -> float:
	return minf(
		($Model/LeftLegPivot/Foot/Sole as Marker3D).global_position.y,
		($Model/RightLegPivot/Foot/Sole as Marker3D).global_position.y
	)
