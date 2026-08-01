class_name LocalShooterArena
extends Node3D

const CENTRE := Vector3(0.0, 0.0, -20.0)
const SHOT_BOUNDS := AABB(Vector3(-14.2, 0.0, -39.2), Vector3(28.4, 5.5, 38.4))


func _ready() -> void:
	var floor := _material(Color(0.075, 0.105, 0.14), 0.82, 0.08)
	var wall := _material(Color(0.15, 0.19, 0.24), 0.76, 0.18)
	var orange := _material(Color(0.88, 0.24, 0.07), 0.62, 0.12)
	var blue := _material(Color(0.08, 0.46, 0.68), 0.7, 0.14)
	_add_box("ArenaFloor", CENTRE + Vector3.DOWN * 0.12, Vector3(30.0, 0.24, 40.0), floor, true)
	for item in [
		[Vector3(-15.0, 2.1, -20.0), Vector3(0.5, 4.2, 40.5)],
		[Vector3(15.0, 2.1, -20.0), Vector3(0.5, 4.2, 40.5)],
		[Vector3(0.0, 2.1, -40.0), Vector3(30.5, 4.2, 0.5)],
		[Vector3(0.0, 2.1, 0.0), Vector3(30.5, 4.2, 0.5)],
	]:
		_add_box("Boundary", item[0], item[1], wall, true)
	# Alternating cover leaves several readable firing lanes without making the
	# arena expensive or letting a single position see every spawn.
	for item in [
		[Vector3(-8.5, 1.05, -10.0), Vector3(4.8, 2.1, 1.0), orange],
		[Vector3(8.5, 1.05, -30.0), Vector3(4.8, 2.1, 1.0), orange],
		[Vector3(-8.5, 1.05, -30.0), Vector3(1.0, 2.1, 4.8), blue],
		[Vector3(8.5, 1.05, -10.0), Vector3(1.0, 2.1, 4.8), blue],
		[Vector3(0.0, 0.7, -20.0), Vector3(5.4, 1.4, 2.2), wall],
		[Vector3(-12.0, 0.65, -20.0), Vector3(2.0, 1.3, 3.2), wall],
		[Vector3(12.0, 0.65, -20.0), Vector3(2.0, 1.3, 3.2), wall],
	]:
		_add_box("Cover", item[0], item[1], item[2], true)
	_add_lane_marks()


func get_shot_bounds() -> AABB:
	return SHOT_BOUNDS


func _add_lane_marks() -> void:
	var material := _material(Color(0.94, 0.58, 0.1), 0.72, 0.0)
	for x in [-10.0, 0.0, 10.0]:
		_add_box(
			"LaneMark",
			Vector3(x, 0.015, -20.0),
			Vector3(0.08, 0.02, 35.0),
			material,
			false
		)


func _add_box(
	node_name: String,
	position_value: Vector3,
	size_value: Vector3,
	material: Material,
	collision_enabled: bool
) -> void:
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


func _material(color: Color, roughness: float, metallic: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness
	material.metallic = metallic
	return material
