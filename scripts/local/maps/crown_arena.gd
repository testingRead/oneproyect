class_name LocalCrownArena
extends Node3D

const CENTRE := Vector3(0.0, 0.0, -20.0)


func _ready() -> void:
	var floor_material := _material(Color(0.18, 0.2, 0.32), 0.94)
	var wall_material := _material(Color(0.11, 0.14, 0.25), 0.9)
	_add_box("CrownFloor", CENTRE + Vector3(0.0, 0.01, 0.0), Vector3(26.0, 0.02, 26.0), floor_material, false)
	for wall in [
		[Vector3(-13.0, 1.2, -20.0), Vector3(0.4, 2.4, 26.4)],
		[Vector3(13.0, 1.2, -20.0), Vector3(0.4, 2.4, 26.4)],
		[Vector3(0.0, 1.2, -33.0), Vector3(26.4, 2.4, 0.4)],
		[Vector3(0.0, 1.2, -7.0), Vector3(26.4, 2.4, 0.4)],
	]:
		_add_box("ArenaWall", wall[0], wall[1], wall_material, true)
	_add_crown()


func _add_crown() -> void:
	var crown := Area3D.new()
	crown.name = "Crown"
	crown.position = CENTRE + Vector3(0.0, 0.6, 0.0)
	crown.collision_layer = 0
	crown.collision_mask = 1
	crown.monitoring = true
	crown.add_to_group(&"crown_collectible")
	var collision := CollisionShape3D.new()
	var shape := SphereShape3D.new()
	shape.radius = 0.62
	collision.shape = shape
	crown.add_child(collision)
	var ring := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.28
	torus.outer_radius = 0.48
	ring.mesh = torus
	ring.material_override = _material(Color(1.0, 0.75, 0.12), 0.8)
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	crown.add_child(ring)
	for index in 5:
		var spike := MeshInstance3D.new()
		var cone := CylinderMesh.new()
		cone.top_radius = 0.02
		cone.bottom_radius = 0.09
		cone.height = 0.42
		spike.mesh = cone
		spike.material_override = ring.material_override
		var angle := TAU * float(index) / 5.0
		spike.position = Vector3(cos(angle) * 0.36, 0.25, sin(angle) * 0.36)
		crown.add_child(spike)
	add_child(crown)


func _add_box(node_name: String, position_value: Vector3, size_value: Vector3, material: Material, collision_enabled: bool) -> void:
	var root: Node3D = StaticBody3D.new() if collision_enabled else Node3D.new()
	root.name = node_name
	root.position = position_value
	if root is StaticBody3D:
		(root as StaticBody3D).collision_layer = 1
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size_value
	mesh.mesh = box
	mesh.material_override = material
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(mesh)
	if collision_enabled:
		var collision := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = size_value
		collision.shape = shape
		root.add_child(collision)
	add_child(root)


func _material(color: Color, roughness: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness
	material.metallic = 0.18
	return material
