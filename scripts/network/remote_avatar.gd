class_name RemoteAvatar
extends Node3D

const COLORS := [
	Color(0.96, 0.33, 0.3),
	Color(0.22, 0.78, 0.5),
	Color(0.75, 0.42, 0.95),
	Color(1.0, 0.72, 0.2),
	Color(0.2, 0.72, 0.95),
]

@onready var body_mesh: MeshInstance3D = $Body
@onready var name_label: Label3D = $Name

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
	body_mesh.material_override = material


func set_snapshot(position: Vector3, facing_yaw: float) -> void:
	target_position = position
	target_yaw = facing_yaw
