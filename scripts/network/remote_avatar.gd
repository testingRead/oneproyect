class_name RemoteAvatar
extends Node3D

const HUMANOID_RIG := preload("res://scripts/characters/humanoid_rig.gd")
const ALL_LIMBS_MASK := HUMANOID_RIG.ALL_BODY_PARTS_MASK
const WEAPONS := preload("res://shared/weapon_profiles.gd")

@onready var name_label: Label3D = $Name

var target_position := Vector3.ZERO
var target_velocity := Vector3.ZERO
var target_yaw := 0.0
var _snapshot_elapsed := 0.0
var _walk_phase := 0.0
var _variant_index := 0
var _limb_mask := ALL_LIMBS_MASK
var _player_name := "Jugador"
var _health := 100
var _combat_pose_time := 0.0
var _shoot_animation := 0.0
var _reload_animation := 0.0
var _shots_since_reload := 0
var _held_weapon: Node3D
var _held_weapon_id := -1
var _detail_quality := 0


func _process(delta: float) -> void:
	_combat_pose_time = maxf(0.0, _combat_pose_time - delta)
	_shoot_animation = maxf(0.0, _shoot_animation - delta)
	_reload_animation = maxf(0.0, _reload_animation - delta)
	var previous_position := global_position
	_snapshot_elapsed = minf(_snapshot_elapsed + delta, 0.12)
	var displayed_position := target_position + target_velocity * _snapshot_elapsed
	global_position = global_position.lerp(
		displayed_position,
		clampf(delta * 18.0, 0.0, 1.0)
	)
	rotation.y = lerp_angle(rotation.y, target_yaw, clampf(delta * 14.0, 0.0, 1.0))
	var speed := global_position.distance_to(previous_position) / maxf(delta, 0.001)
	_walk_phase = HUMANOID_RIG.animate(
		self,
		delta,
		speed,
		_walk_phase,
		true,
		0.0,
		0.0,
		1.0 if _combat_pose_time > 0.0 else 0.0,
		clampf(_shoot_animation / 0.14, 0.0, 1.0),
		clampf(_reload_animation / 1.1, 0.0, 1.0)
	)
	if _held_weapon != null:
		var reload_weight := clampf(_reload_animation / maxf(
			0.2,
			WEAPONS.reload_seconds(_held_weapon_id)
		), 0.0, 1.0)
		_held_weapon.visible = _combat_pose_time > 0.0
		_held_weapon.position = Vector3(0.08, 0.52 - reload_weight * 0.2, 0.52)
		_held_weapon.rotation = Vector3(
			-0.08 + reload_weight * 0.45,
			0.0,
			reload_weight * 0.35
		)


func configure(player_name: String, player_color: int, initial_position: Vector3) -> void:
	_player_name = player_name
	_health = 100
	_update_name_label()
	target_position = initial_position
	global_position = initial_position
	_variant_index = HUMANOID_RIG.CATALOG.sanitize_index(player_color)
	HUMANOID_RIG.apply_variant(self, _variant_index)
	set_limb_mask(ALL_LIMBS_MASK)


func set_snapshot(position: Vector3, velocity: Vector3, facing_yaw: float) -> void:
	if global_position.distance_squared_to(position) > 36.0:
		global_position = position
	target_position = position
	target_velocity = velocity
	target_yaw = facing_yaw
	_snapshot_elapsed = 0.0


func set_limb_mask(mask: int) -> void:
	_limb_mask = mask & ALL_LIMBS_MASK
	HUMANOID_RIG.apply_limb_mask(self, _limb_mask, _variant_index)


func set_health(value: int) -> void:
	_health = clampi(value, 0, 100)
	_update_name_label()


func _update_name_label() -> void:
	if _player_name.is_empty():
		name_label.text = ""
	elif _health <= 0:
		name_label.text = "%s · ELIMINADO" % _player_name
	else:
		name_label.text = "%s · %d VIDA" % [_player_name, _health]


func get_limb_mask() -> int:
	return _limb_mask


func set_shadow_quality(enabled: bool) -> void:
	HUMANOID_RIG.set_shadow_quality(self, enabled)


func set_texture_detail(enabled: bool) -> void:
	HUMANOID_RIG.set_texture_detail(self, enabled)


func set_model_quality(rounded: bool) -> void:
	HUMANOID_RIG.set_model_quality(self, rounded)


func set_detail_quality(level: int) -> void:
	_detail_quality = clampi(level, 0, 2)
	HUMANOID_RIG.set_detail_quality(self, level)
	HUMANOID_RIG.apply_limb_mask(self, _limb_mask, _variant_index)
	if _held_weapon != null:
		var detail := _held_weapon.get_node_or_null("Detail")
		if detail != null:
			detail.visible = _detail_quality >= 1


func play_shoot_animation(weapon_id: int) -> void:
	_ensure_held_weapon(weapon_id)
	_combat_pose_time = 2.5
	_shoot_animation = 0.14
	_shots_since_reload += 1
	if _shots_since_reload >= WEAPONS.magazine_size(weapon_id):
		_shots_since_reload = 0
		_reload_animation = WEAPONS.reload_seconds(weapon_id)


func _ensure_held_weapon(weapon_id: int) -> void:
	if _held_weapon != null and _held_weapon_id == weapon_id:
		return
	if _held_weapon != null:
		_held_weapon.queue_free()
	_held_weapon_id = weapon_id
	_held_weapon = Node3D.new()
	_held_weapon.name = "HeldWeapon"
	add_child(_held_weapon)
	var dark := StandardMaterial3D.new()
	dark.albedo_color = Color(0.06, 0.075, 0.09)
	dark.metallic = 0.65
	dark.roughness = 0.38
	var accent := StandardMaterial3D.new()
	accent.albedo_color = Color(0.92, 0.28, 0.08)
	accent.roughness = 0.5
	var receiver_size := Vector3(0.17, 0.14, 0.48)
	var barrel_size := Vector3(0.07, 0.07, 0.34)
	var stock_size := Vector3(0.16, 0.18, 0.28)
	if weapon_id == WEAPONS.Id.P9:
		receiver_size = Vector3(0.14, 0.12, 0.32)
		barrel_size = Vector3(0.045, 0.045, 0.14)
		stock_size = Vector3(0.12, 0.24, 0.13)
	elif weapon_id == WEAPONS.Id.T12:
		receiver_size = Vector3(0.18, 0.15, 0.46)
		barrel_size = Vector3(0.065, 0.065, 0.7)
		stock_size = Vector3(0.18, 0.2, 0.42)
	_add_weapon_box("Receiver", receiver_size, Vector3.ZERO, dark)
	_add_weapon_box(
		"Barrel",
		barrel_size,
		Vector3(0, 0.02, receiver_size.z * 0.5 + barrel_size.z * 0.5),
		dark
	)
	_add_weapon_box(
		"Stock",
		stock_size,
		Vector3(0, -0.03, -receiver_size.z * 0.5 - stock_size.z * 0.42),
		accent
	)
	_add_weapon_box("Detail", Vector3(0.1, 0.22, 0.13), Vector3(0, -0.18, 0.02), accent)
	_held_weapon.get_node("Detail").visible = _detail_quality >= 1


func _add_weapon_box(
	part_name: String,
	size: Vector3,
	part_position: Vector3,
	material: Material
) -> void:
	var mesh := BoxMesh.new()
	mesh.size = size
	var part := MeshInstance3D.new()
	part.name = part_name
	part.mesh = mesh
	part.material_override = material
	part.position = part_position
	part.cast_shadow = (
		GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		if _detail_quality >= 1
		else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	)
	_held_weapon.add_child(part)
