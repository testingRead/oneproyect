class_name LocalMapHost
extends Node3D

var current_definition: MinigameMapDefinition
var current_seed := 0
var current_signature := PackedByteArray()
var _mounted_root: Node3D


func mount_map(definition: MinigameMapDefinition, seed: int) -> void:
	unmount_map()
	current_definition = definition
	current_seed = seed
	current_signature = definition.variation_signature(seed)
	if definition.map_scene != null:
		_mounted_root = definition.map_scene.instantiate() as Node3D
		_mounted_root.name = "MountedMap"
		add_child(_mounted_root)
		if _mounted_root.has_method("configure_variation"):
			_mounted_root.call("configure_variation", current_signature)
		return
	_mounted_root = Node3D.new()
	_mounted_root.name = "MountedMap"
	add_child(_mounted_root)
	var structure := _material(Color(0.54, 0.58, 0.62), 0.9)
	var accent := _material(Color(0.24, 0.42, 0.52), 0.86)
	var object_material := _material(Color(0.76, 0.46, 0.18), 0.84)
	_add_static_box("Foundation", Vector3(0.0, 0.2, -18.0), Vector3(24.0, 0.4, 18.0), structure)
	_add_static_box("BackWall", Vector3(0.0, 1.7, -26.8), Vector3(24.0, 3.0, 0.4), accent)
	_add_static_box("LeftWall", Vector3(-11.8, 1.7, -18.0), Vector3(0.4, 3.0, 18.0), accent)
	_add_static_box("RightWall", Vector3(11.8, 1.7, -18.0), Vector3(0.4, 3.0, 18.0), accent)
	if _variant_enabled(0):
		_add_static_box("OptionalRoom", Vector3(-6.0, 1.25, -20.0), Vector3(8.0, 2.5, 0.35), accent)
	if _variant_enabled(1):
		_add_static_box("OptionalBridge", Vector3(0.0, 0.65, -8.0), Vector3(4.0, 0.3, 4.0), structure)
	if _variant_enabled(2):
		_add_static_box("BlockedDoor", Vector3(0.0, 1.1, -26.35), Vector3(2.2, 2.2, 0.45), object_material)
	var box_offset := -4.0 if _variant_enabled(3) else 4.0
	_add_rigid_box("RoundLightBox", Vector3(box_offset, 0.5, -16.0), 1.0, 2.0, object_material)
	_add_rigid_box("RoundHeavyBox", Vector3(-box_offset, 0.75, -21.0), 1.5, 10.0, object_material)


func unmount_map() -> void:
	if is_instance_valid(_mounted_root):
		_mounted_root.free()
	_mounted_root = null
	current_definition = null
	current_signature = PackedByteArray()


func get_spawn_transform(slot := 0) -> Transform3D:
	if current_definition == null:
		return Transform3D(Basis.IDENTITY, Vector3(0.0, 0.02, 8.0))
	return Transform3D(Basis.IDENTITY, current_definition.get_spawn_for_slot(slot))


func has_team_layout() -> bool:
	return current_definition != null and current_definition.has_team_layout()


func get_team_for_slot(slot: int) -> StringName:
	return current_definition.get_team_for_slot(slot) if current_definition != null else &"home"


func get_team_facing_for_slot(slot: int) -> Vector3:
	return current_definition.get_team_facing_for_slot(slot) if current_definition != null else Vector3(0.0, 0.0, -1.0)


func get_mounted_node_count() -> int:
	if not is_instance_valid(_mounted_root):
		return 0
	return _count_branch(_mounted_root)


func _variant_enabled(index: int) -> bool:
	return index < current_signature.size() and current_signature[index] == 1


func _add_static_box(
	node_name: String,
	position_value: Vector3,
	size: Vector3,
	material: StandardMaterial3D
) -> void:
	var body := StaticBody3D.new()
	body.name = node_name
	body.position = position_value
	body.collision_layer = 1
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	collision.shape = shape
	body.add_child(collision)
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mesh.mesh = box
	mesh.material_override = material
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	body.add_child(mesh)
	_mounted_root.add_child(body)


func _add_rigid_box(
	node_name: String,
	position_value: Vector3,
	size_value: float,
	mass_value: float,
	material: StandardMaterial3D
) -> void:
	var body := RigidBody3D.new()
	body.name = node_name
	body.position = position_value
	body.mass = mass_value
	body.collision_layer = 1
	body.collision_mask = 1
	body.add_to_group(&"local_round_object")
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3.ONE * size_value
	collision.shape = shape
	body.add_child(collision)
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3.ONE * size_value
	mesh.mesh = box
	mesh.material_override = material
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	body.add_child(mesh)
	_mounted_root.add_child(body)


func _count_branch(node: Node) -> int:
	var count := 1
	for child in node.get_children():
		count += _count_branch(child)
	return count


func _material(color: Color, roughness_value: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness_value
	return material
