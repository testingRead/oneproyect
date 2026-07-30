class_name BatControlsFeature
extends "res://scripts/features/gameplay_feature.gd"

var _player: GrayboxPlayer
var _bat_root: Node3D
var _swing_time := 0.0


func _ready() -> void:
	feature_id = &"bat_controls"


func activate(context: Dictionary) -> void:
	super.activate(context)
	_player = context.get("player") as GrayboxPlayer
	if _player == null:
		return
	_ensure_bat()
	_bat_root.visible = true
	if not _player.push_requested.is_connected(_swing_bat):
		_player.push_requested.connect(_swing_bat)
	set_process(true)


func deactivate() -> void:
	set_process(false)
	if _bat_root != null:
		_bat_root.visible = false
	super.deactivate()


func _process(delta: float) -> void:
	if _player == null or _bat_root == null:
		return
	_swing_time = maxf(0.0, _swing_time - delta)
	var hand := _player.get_node("Visual/RightHand") as MeshInstance3D
	_bat_root.transform = hand.transform
	_bat_root.position += Vector3(0.0, -0.14, 0.38)
	var swing_weight := clampf(_swing_time / 0.48, 0.0, 1.0)
	_bat_root.rotation.x += -0.55 + sin(swing_weight * PI) * 1.45
	_bat_root.rotation.z += 0.22


func _swing_bat() -> void:
	_swing_time = 0.48


func _ensure_bat() -> void:
	if _bat_root != null:
		return
	_bat_root = Node3D.new()
	_bat_root.name = "PushBat"
	_player.get_node("Visual").add_child(_bat_root)
	var grip_material := StandardMaterial3D.new()
	grip_material.albedo_color = Color(0.07, 0.08, 0.09)
	grip_material.roughness = 0.72
	var body_material := StandardMaterial3D.new()
	body_material.albedo_color = Color(0.92, 0.48, 0.08)
	body_material.metallic = 0.45
	body_material.roughness = 0.38
	_add_cylinder("Grip", 0.055, 0.48, Vector3(0.0, 0.0, 0.0), grip_material)
	_add_cylinder("Barrel", 0.115, 0.82, Vector3(0.0, 0.65, 0.0), body_material)
	_bat_root.rotation.z = -0.18


func _add_cylinder(
	part_name: String,
	radius: float,
	height: float,
	part_position: Vector3,
	material: Material
) -> void:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius * 0.78
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 10
	var part := MeshInstance3D.new()
	part.name = part_name
	part.mesh = mesh
	part.position = part_position
	part.material_override = material
	part.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_bat_root.add_child(part)
