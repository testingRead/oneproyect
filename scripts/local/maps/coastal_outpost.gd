class_name LocalCoastalOutpost
extends Node3D

var _concrete: StandardMaterial3D
var _wall: StandardMaterial3D
var _roof: StandardMaterial3D
var _accent: StandardMaterial3D
var _crate: StandardMaterial3D


func _ready() -> void:
	_concrete = _material(Color(0.43, 0.48, 0.5), 0.94)
	_wall = _material(Color(0.72, 0.7, 0.62), 0.88)
	_roof = _material(Color(0.13, 0.28, 0.34), 0.82)
	_accent = _material(Color(0.9, 0.46, 0.12), 0.78)
	_crate = _material(Color(0.5, 0.3, 0.14), 0.92)
	_build_structure()


func configure_variation(signature: PackedByteArray) -> void:
	for slot_index in 4:
		var enabled := (
			slot_index < signature.size()
			and signature[slot_index] == 1
		)
		for node in get_tree().get_nodes_in_group(
			StringName("coastal_variant_%d" % slot_index)
		):
			if is_ancestor_of(node):
				_set_branch_enabled(node, enabled)


func _build_structure() -> void:
	_add_static_box(
		"Foundation",
		Vector3(0.0, 0.15, -19.0),
		Vector3(32.0, 0.3, 26.0),
		_concrete
	)
	_add_static_box(
		"BuildingFloor",
		Vector3(0.0, 0.32, -20.0),
		Vector3(16.0, 0.34, 10.0),
		_concrete
	)
	_add_static_box("BackWall", Vector3(0.0, 1.9, -24.8), Vector3(16.0, 3.2, 0.4), _wall)
	_add_static_box("LeftWall", Vector3(-7.8, 1.9, -20.0), Vector3(0.4, 3.2, 10.0), _wall)
	_add_static_box("RightWall", Vector3(7.8, 1.9, -20.0), Vector3(0.4, 3.2, 10.0), _wall)
	_add_static_box("FrontLeft", Vector3(-5.1, 1.9, -15.2), Vector3(5.8, 3.2, 0.4), _wall)
	_add_static_box("FrontRight", Vector3(5.1, 1.9, -15.2), Vector3(5.8, 3.2, 0.4), _wall)
	_add_static_box("DoorHeader", Vector3(0.0, 3.05, -15.2), Vector3(4.4, 0.9, 0.4), _wall)
	_add_static_box("Roof", Vector3(0.0, 3.62, -20.0), Vector3(16.4, 0.34, 10.4), _roof)

	# Exterior stairs make elevation part of normal locomotion, not a teleport.
	for step_index in 8:
		var step_height := 0.43 * float(step_index + 1)
		_add_static_box(
			"Step%02d" % step_index,
			Vector3(9.2, step_height * 0.5, -13.8 - step_index * 0.72),
			Vector3(2.4, step_height, 0.72),
			_concrete
		)
	_add_static_box("RoofLanding", Vector3(8.3, 3.47, -19.2), Vector3(2.0, 0.3, 2.8), _concrete)

	# Lightweight observation canopy gives the roof a readable silhouette.
	for position_value in [
		Vector3(-3.2, 4.75, -22.2),
		Vector3(3.2, 4.75, -22.2),
		Vector3(-3.2, 4.75, -17.8),
		Vector3(3.2, 4.75, -17.8),
	]:
		_add_static_box("CanopyPost", position_value, Vector3(0.18, 2.1, 0.18), _accent)
	_add_static_box("Canopy", Vector3(0.0, 5.83, -20.0), Vector3(7.4, 0.22, 5.2), _roof)

	_add_static_box("YardBarrierA", Vector3(-9.0, 0.65, -10.0), Vector3(6.0, 1.0, 0.5), _concrete)
	_add_static_box("YardBarrierB", Vector3(8.0, 0.65, -28.0), Vector3(7.0, 1.0, 0.5), _concrete)
	_add_rigid_box("SupplyCrateA", Vector3(-4.0, 0.75, -11.5), 1.5, 9.0)
	_add_rigid_box("SupplyCrateB", Vector3(4.0, 0.5, -12.0), 1.0, 3.5)

	var side_shelter := _add_static_box(
		"SideShelter",
		Vector3(-11.0, 1.35, -21.0),
		Vector3(5.0, 0.25, 7.0),
		_roof
	)
	side_shelter.add_to_group(&"coastal_variant_0")
	var roof_bridge := _add_static_box(
		"RoofBridge",
		Vector3(-8.8, 3.55, -20.0),
		Vector3(2.0, 0.28, 3.0),
		_concrete
	)
	roof_bridge.add_to_group(&"coastal_variant_1")
	var blocked_door := _add_static_box(
		"BlockedDoor",
		Vector3(0.0, 1.25, -15.0),
		Vector3(2.0, 2.5, 0.5),
		_accent
	)
	blocked_door.add_to_group(&"coastal_variant_2")
	var optional_crate := _add_rigid_box(
		"OptionalHeavyCrate",
		Vector3(10.5, 1.0, -23.0),
		2.0,
		18.0
	)
	optional_crate.add_to_group(&"coastal_variant_3")


func _add_static_box(
	node_name: String,
	position_value: Vector3,
	size: Vector3,
	material: StandardMaterial3D
) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = node_name
	body.position = position_value
	body.collision_layer = 1
	var collision := CollisionShape3D.new()
	collision.name = "Collision"
	var shape := BoxShape3D.new()
	shape.size = size
	collision.shape = shape
	body.add_child(collision)
	var mesh := MeshInstance3D.new()
	mesh.name = "Mesh"
	var box := BoxMesh.new()
	box.size = size
	mesh.mesh = box
	mesh.material_override = material
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	body.add_child(mesh)
	add_child(body)
	return body


func _add_rigid_box(
	node_name: String,
	position_value: Vector3,
	size_value: float,
	mass_value: float
) -> RigidBody3D:
	var body := RigidBody3D.new()
	body.name = node_name
	body.position = position_value
	body.mass = mass_value
	body.collision_layer = 1
	body.collision_mask = 1
	body.add_to_group(&"local_round_object")
	var collision := CollisionShape3D.new()
	collision.name = "Collision"
	var shape := BoxShape3D.new()
	shape.size = Vector3.ONE * size_value
	collision.shape = shape
	body.add_child(collision)
	var mesh := MeshInstance3D.new()
	mesh.name = "Mesh"
	var box := BoxMesh.new()
	box.size = Vector3.ONE * size_value
	mesh.mesh = box
	mesh.material_override = _crate
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	body.add_child(mesh)
	add_child(body)
	return body


func _set_branch_enabled(node: Node, enabled: bool) -> void:
	if node is Node3D:
		(node as Node3D).visible = enabled
	if node is CollisionObject3D:
		(node as CollisionObject3D).collision_layer = 1 if enabled else 0
		(node as CollisionObject3D).collision_mask = 1 if enabled else 0
	if node is RigidBody3D:
		(node as RigidBody3D).freeze = not enabled


func _material(color: Color, roughness_value: float) -> StandardMaterial3D:
	var result := StandardMaterial3D.new()
	result.albedo_color = color
	result.roughness = roughness_value
	return result
