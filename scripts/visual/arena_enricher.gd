class_name ArenaEnricher
extends Node3D

const INDUSTRIAL_FLOOR := preload("res://assets/textures/industrial_floor.webp")

@export var half_extent := 25.5
@export var build_boundary := false
@export var palette_primary := Color(0.16, 0.3, 0.4)
@export var palette_accent := Color(0.12, 0.72, 0.68)
@export var physical_prop_count := 8
@export var floor_texture: Texture2D = INDUSTRIAL_FLOOR

var _quality_level := 0
var _medium_details: Node3D
var _high_details: Node3D
var _high_built := false
var _box_mesh: BoxMesh
var _box_shape: BoxShape3D
var _primary_material: StandardMaterial3D
var _accent_material: StandardMaterial3D


func _ready() -> void:
	add_to_group(&"quality_receiver")
	_create_shared_resources()
	if build_boundary:
		_build_floor_and_boundary()
	else:
		_texture_existing_floor()
	_build_cover()
	_build_physical_props()
	_medium_details = Node3D.new()
	_medium_details.name = "MediumDetails"
	add_child(_medium_details)
	_build_medium_details()
	set_quality_level(0)


func _texture_existing_floor() -> void:
	var floor_mesh := get_node_or_null("Floor/Mesh") as MeshInstance3D
	if floor_mesh == null:
		return
	var material := _primary_material.duplicate() as StandardMaterial3D
	material.albedo_texture = floor_texture
	material.uv1_scale = Vector3(6.0, 6.0, 6.0)
	floor_mesh.material_override = material


func set_quality_level(level: int) -> void:
	_quality_level = clampi(level, 0, 2)
	if _medium_details != null:
		_medium_details.visible = _quality_level >= 1
	if _quality_level >= 2 and not _high_built:
		_build_high_details()
	if _high_details != null:
		_high_details.visible = _quality_level >= 2


func _create_shared_resources() -> void:
	_primary_material = StandardMaterial3D.new()
	_primary_material.albedo_color = palette_primary
	_primary_material.roughness = 0.86
	_accent_material = StandardMaterial3D.new()
	_accent_material.albedo_color = palette_accent
	_accent_material.roughness = 0.68
	_box_mesh = BoxMesh.new()
	_box_mesh.size = Vector3.ONE
	_box_mesh.material = _primary_material
	_box_shape = BoxShape3D.new()
	_box_shape.size = Vector3.ONE


func _build_floor_and_boundary() -> void:
	var floor_size := half_extent * 2.0
	var floor_material := _primary_material.duplicate() as StandardMaterial3D
	floor_material.albedo_texture = floor_texture
	floor_material.uv1_scale = Vector3(6.0, 6.0, 6.0)
	_add_static_box(
		"Floor",
		Vector3(0.0, -0.25, 0.0),
		Vector3(floor_size, 0.5, floor_size),
		floor_material
	)
	_add_static_box(
		"NorthWall",
		Vector3(0.0, 1.1, -half_extent),
		Vector3(floor_size, 2.2, 0.7),
		_accent_material
	)
	_add_static_box(
		"SouthWall",
		Vector3(0.0, 1.1, half_extent),
		Vector3(floor_size, 2.2, 0.7),
		_accent_material
	)
	_add_static_box(
		"EastWall",
		Vector3(half_extent, 1.1, 0.0),
		Vector3(0.7, 2.2, floor_size),
		_accent_material
	)
	_add_static_box(
		"WestWall",
		Vector3(-half_extent, 1.1, 0.0),
		Vector3(0.7, 2.2, floor_size),
		_accent_material
	)


func _build_cover() -> void:
	var positions := [
		Vector3(-15.0, 0.75, -5.0),
		Vector3(15.0, 0.75, 5.0),
		Vector3(-6.0, 0.75, 15.0),
		Vector3(6.0, 0.75, -15.0),
		Vector3(-18.0, 1.3, 14.0),
		Vector3(18.0, 1.3, -14.0),
	]
	for index in positions.size():
		var size := (
			Vector3(4.2, 2.6, 1.2)
			if index >= 4
			else Vector3(3.2, 1.5, 1.4)
		)
		_add_static_box(
			"Cover%02d" % index,
			positions[index],
			size,
			_accent_material if index % 2 else _primary_material
		)


func _build_physical_props() -> void:
	for index in physical_prop_count:
		var body := RigidBody3D.new()
		body.name = "PhysicsProp%02d" % index
		body.mass = 0.75 + float(index % 3) * 0.25
		body.position = Vector3(
			-10.5 + float(index % 4) * 7.0,
			1.0 + float(index / 4) * 0.15,
			-10.0 + float(index / 4) * 19.0
		)
		body.rotation.y = float(index) * 0.37
		body.collision_layer = 2
		body.collision_mask = 3
		add_child(body)
		var mesh := MeshInstance3D.new()
		mesh.name = "Mesh"
		mesh.mesh = _box_mesh
		mesh.scale = Vector3(1.0, 1.0, 1.0)
		mesh.material_override = (
			_accent_material if index % 3 == 0 else _primary_material
		)
		mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mesh.add_to_group(&"quality_shadow")
		body.add_child(mesh)
		var collision := CollisionShape3D.new()
		collision.shape = _box_shape
		body.add_child(collision)


func _build_medium_details() -> void:
	for index in 8:
		var angle := TAU * float(index) / 8.0
		var column := MeshInstance3D.new()
		column.name = "Beacon%02d" % index
		var mesh := CylinderMesh.new()
		mesh.top_radius = 0.12
		mesh.bottom_radius = 0.22
		mesh.height = 3.8
		mesh.radial_segments = 8
		mesh.material = _accent_material
		column.mesh = mesh
		column.position = Vector3(cos(angle), 0.0, sin(angle)) * (half_extent - 2.0)
		column.position.y = 1.9
		column.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_medium_details.add_child(column)


func _build_high_details() -> void:
	_high_built = true
	_high_details = Node3D.new()
	_high_details.name = "HighDetails"
	add_child(_high_details)
	var trunk_material := StandardMaterial3D.new()
	trunk_material.albedo_color = Color(0.24, 0.16, 0.1)
	trunk_material.roughness = 1.0
	var crown_material := StandardMaterial3D.new()
	crown_material.albedo_color = Color(0.12, 0.38, 0.24)
	crown_material.roughness = 0.92
	for index in 10:
		var angle := TAU * float(index) / 10.0 + 0.17
		var radius := half_extent - 4.0
		var root := Node3D.new()
		root.position = Vector3(cos(angle) * radius, 0.0, sin(angle) * radius)
		_high_details.add_child(root)
		var trunk := MeshInstance3D.new()
		var trunk_mesh := CylinderMesh.new()
		trunk_mesh.top_radius = 0.18
		trunk_mesh.bottom_radius = 0.32
		trunk_mesh.height = 3.6
		trunk_mesh.radial_segments = 12
		trunk_mesh.material = trunk_material
		trunk.mesh = trunk_mesh
		trunk.position.y = 1.8
		trunk.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		root.add_child(trunk)
		var crown := MeshInstance3D.new()
		var crown_mesh := SphereMesh.new()
		crown_mesh.radius = 1.25
		crown_mesh.height = 2.5
		crown_mesh.radial_segments = 16
		crown_mesh.rings = 8
		crown_mesh.material = crown_material
		crown.mesh = crown_mesh
		crown.position.y = 4.0
		crown.scale = Vector3(1.0, 1.25, 1.0)
		crown.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		root.add_child(crown)


func _add_static_box(
	node_name: String,
	position_value: Vector3,
	size: Vector3,
	material: Material
) -> void:
	var body := StaticBody3D.new()
	body.name = node_name
	body.position = position_value
	add_child(body)
	var mesh := MeshInstance3D.new()
	mesh.name = "Mesh"
	mesh.mesh = _box_mesh
	mesh.scale = size
	mesh.material_override = material
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mesh.add_to_group(&"quality_shadow")
	body.add_child(mesh)
	var collision := CollisionShape3D.new()
	collision.name = "Collision"
	collision.shape = _box_shape
	collision.scale = size
	body.add_child(collision)
