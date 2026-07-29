class_name RemoteAvatar
extends Node3D

const SUIT_TEXTURE := preload("res://assets/textures/suit_panels.res")
const COLORS := [
	Color(0.96, 0.33, 0.3),
	Color(0.22, 0.78, 0.5),
	Color(0.75, 0.42, 0.95),
	Color(1.0, 0.72, 0.2),
	Color(1.0, 0.78, 0.2),
]

@onready var body_mesh: MeshInstance3D = $Body
@onready var color_parts: Array[MeshInstance3D] = [
	$Body,
	$Head,
	$LeftArm,
	$RightArm,
	$LeftLeg,
	$RightLeg,
]
@onready var name_label: Label3D = $Name
@onready var cap: MeshInstance3D = $Cap
@onready var backpack: MeshInstance3D = $Backpack

var target_position := Vector3.ZERO
var target_yaw := 0.0


func _process(delta: float) -> void:
	global_position = global_position.lerp(target_position, clampf(delta * 12.0, 0.0, 1.0))
	rotation.y = lerp_angle(rotation.y, target_yaw, clampf(delta * 14.0, 0.0, 1.0))


func configure(player_name: String, player_color: int, initial_position: Vector3) -> void:
	name_label.text = player_name
	target_position = initial_position
	global_position = initial_position
	var material := body_mesh.get_active_material(0).duplicate() as StandardMaterial3D
	material.albedo_color = COLORS[clampi(player_color, 0, COLORS.size() - 1)]
	for part in color_parts:
		part.material_override = material
	cap.visible = player_color % 2 == 0
	backpack.visible = not cap.visible


func set_snapshot(position: Vector3, facing_yaw: float) -> void:
	target_position = position
	target_yaw = facing_yaw


func set_shadow_quality(enabled: bool) -> void:
	var shadow_mode := (
		GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		if enabled
		else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	)
	for part in color_parts:
		part.cast_shadow = shadow_mode


func set_texture_detail(enabled: bool) -> void:
	var material := color_parts[0].material_override as StandardMaterial3D
	if material != null:
		material.albedo_texture = SUIT_TEXTURE if enabled else null
