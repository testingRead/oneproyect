class_name LocalBombArena
extends Node3D

const CENTRE := Vector3(0.0, 0.0, -20.0)
const BOMB_SCENE := preload("res://scenes/local/components/bomb_item.tscn")


func _ready() -> void:
	var floor_material := _material(Color(0.28, 0.17, 0.12), 0.95)
	var wall_material := _material(Color(0.16, 0.09, 0.07), 0.9)
	_add_box("BombFloor", CENTRE + Vector3(0.0, 0.01, 0.0), Vector3(26.0, 0.02, 26.0), floor_material, false)
	for wall in [
		[Vector3(-13.0, 1.2, -20.0), Vector3(0.4, 2.4, 26.4)],
		[Vector3(13.0, 1.2, -20.0), Vector3(0.4, 2.4, 26.4)],
		[Vector3(0.0, 1.2, -33.0), Vector3(26.4, 2.4, 0.4)],
		[Vector3(0.0, 1.2, -7.0), Vector3(26.4, 2.4, 0.4)],
	]:
		_add_box("ArenaWall", wall[0], wall[1], wall_material, true)
	var bomb := BOMB_SCENE.instantiate() as Area3D
	bomb.name = "Bomb"
	bomb.position = CENTRE + Vector3(0.0, 0.55, 0.0)
	add_child(bomb)


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
	material.metallic = 0.1
	return material
