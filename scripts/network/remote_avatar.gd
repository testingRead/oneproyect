class_name RemoteAvatar
extends Node3D

const HUMANOID_RIG := preload("res://scripts/characters/humanoid_rig.gd")
const ALL_LIMBS_MASK := HUMANOID_RIG.ALL_BODY_PARTS_MASK

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


func _process(delta: float) -> void:
	var previous_position := global_position
	_snapshot_elapsed = minf(_snapshot_elapsed + delta, 0.12)
	var displayed_position := target_position + target_velocity * _snapshot_elapsed
	global_position = global_position.lerp(
		displayed_position,
		clampf(delta * 18.0, 0.0, 1.0)
	)
	rotation.y = lerp_angle(rotation.y, target_yaw, clampf(delta * 14.0, 0.0, 1.0))
	var speed := global_position.distance_to(previous_position) / maxf(delta, 0.001)
	_walk_phase = HUMANOID_RIG.animate(self, delta, speed, _walk_phase, true)


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
