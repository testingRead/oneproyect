class_name LocalTornadoArena
extends Node3D

const CENTRE := Vector3(0.0, 0.0, -20.0)


func _ready() -> void:
	var floor := _material(Color(0.23, 0.25, 0.17), 0.95)
	var wall := _material(Color(0.18, 0.2, 0.12), 0.9)
	_add_static_box("TornadoFloor", CENTRE, Vector3(34.0, 0.04, 34.0), floor, false)
	for wall_data in [
		[Vector3(-17.0, 2.0, -20.0), Vector3(0.45, 4.0, 34.45)],
		[Vector3(17.0, 2.0, -20.0), Vector3(0.45, 4.0, 34.45)],
		[Vector3(0.0, 2.0, -37.0), Vector3(34.45, 4.0, 0.45)],
		[Vector3(0.0, 2.0, -3.0), Vector3(34.45, 4.0, 0.45)],
	]:
		_add_static_box("StormWall", wall_data[0], wall_data[1], wall, true)
	for index in 12:
		var angle := TAU * float(index) / 12.0
		var radius := 7.0 + float(index % 3) * 3.0
		var size := 0.42 if index % 3 == 0 else 0.75 if index % 3 == 1 else 1.15
		var mass := 1.1 if size < 0.6 else 4.5 if size < 1.0 else 13.0
		_add_loose_object(
			"StormObject%d" % index,
			CENTRE + Vector3(cos(angle) * radius, size * 0.5 + 0.04, sin(angle) * radius),
			size,
			mass,
			_material(Color(0.38 + 0.03 * float(index % 3), 0.25, 0.12), 0.84)
		)
	_add_tornado()


func _add_tornado() -> void:
	var tornado := Node3D.new()
	tornado.name = "Tornado"
	tornado.position = CENTRE
	tornado.add_to_group(&"tornado_hazard")
	for index in 5:
		var mesh := MeshInstance3D.new()
		mesh.name = "FunnelBand%d" % index
		var band := CylinderMesh.new()
		band.top_radius = 0.75 + float(index) * 0.52
		band.bottom_radius = 0.28 + float(index) * 0.18
		band.height = 0.56
		mesh.mesh = band
		mesh.position.y = 0.35 + float(index) * 0.55
		mesh.rotation.y = float(index) * 0.55
		var material := _material(Color(0.37, 0.41, 0.37, 0.34), 0.75)
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mesh.material_override = material
		mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		tornado.add_child(mesh)
	var light := OmniLight3D.new()
	light.light_color = Color(0.68, 0.82, 0.64)
	light.light_energy = 0.75
	light.omni_range = 5.0
	light.shadow_enabled = false
	tornado.add_child(light)
	add_child(tornado)


func _add_static_box(node_name: String, position_value: Vector3, size_value: Vector3, material: Material, collision_enabled: bool) -> void:
	var root: Node3D = StaticBody3D.new() if collision_enabled else Node3D.new()
	root.name = node_name
	root.position = position_value
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


func _add_loose_object(node_name: String, position_value: Vector3, size_value: float, mass_value: float, material: Material) -> void:
	var body := RigidBody3D.new()
	body.name = node_name
	body.position = position_value
	body.mass = mass_value
	body.collision_layer = 1
	body.collision_mask = 1
	body.add_to_group(&"tornado_loose_object")
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
	add_child(body)


func _material(color: Color, roughness: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness
	return material
