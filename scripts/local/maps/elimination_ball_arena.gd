class_name LocalEliminationBallArena
extends Node3D

const CENTRE := Vector3(0.0, 0.0, -20.0)
const BALL_BOUNDS := AABB(Vector3(-13.4, 0.15, -35.4), Vector3(26.8, 4.0, 30.8))


func _ready() -> void:
	var floor := _material(Color(0.08, 0.24, 0.22), 0.92)
	var wall := _material(Color(0.08, 0.12, 0.2), 0.82)
	var cover := _material(Color(0.87, 0.42, 0.12), 0.82)
	_add_box("ArenaFloor", CENTRE, Vector3(28.0, 0.04, 32.0), floor, false)
	for item in [
		[Vector3(-14.0, 2.0, -20.0), Vector3(0.45, 4.0, 32.5)],
		[Vector3(14.0, 2.0, -20.0), Vector3(0.45, 4.0, 32.5)],
		[Vector3(0.0, 2.0, -36.0), Vector3(28.5, 4.0, 0.45)],
		[Vector3(0.0, 2.0, -4.0), Vector3(28.5, 4.0, 0.45)],
	]:
		_add_box("ArenaWall", item[0], item[1], wall, true)
	# Low symmetric cover leaves clear throwing lanes while rewarding movement.
	for item in [
		[Vector3(-7.0, 0.65, -16.0), Vector3(2.4, 1.3, 1.0)],
		[Vector3(7.0, 0.65, -24.0), Vector3(2.4, 1.3, 1.0)],
		[Vector3(-7.0, 0.65, -24.0), Vector3(2.4, 1.3, 1.0)],
		[Vector3(7.0, 0.65, -16.0), Vector3(2.4, 1.3, 1.0)],
	]:
		_add_box("Cover", item[0], item[1], cover, true)
	_add_ball()


func get_ball_bounds() -> AABB:
	return BALL_BOUNDS


func _add_ball() -> void:
	var ball := RigidBody3D.new()
	ball.name = "EliminationBall"
	ball.position = CENTRE + Vector3.UP * 0.3
	ball.mass = 0.42
	ball.linear_damp = 0.16
	ball.continuous_cd = true
	ball.max_contacts_reported = 8
	ball.collision_layer = 1
	ball.collision_mask = 1
	var physics := PhysicsMaterial.new()
	physics.bounce = 0.72
	physics.friction = 0.12
	ball.physics_material_override = physics
	ball.add_to_group(&"elimination_ball")
	ball.add_to_group(&"local_round_object")
	var collision := CollisionShape3D.new()
	var shape := SphereShape3D.new()
	shape.radius = 0.3
	collision.shape = shape
	ball.add_child(collision)
	var mesh := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.3
	sphere.height = 0.6
	mesh.mesh = sphere
	mesh.material_override = _material(Color(0.95, 0.16, 0.12), 0.5)
	ball.add_child(mesh)
	add_child(ball)


func _add_box(node_name: String, position_value: Vector3, size: Vector3, material: Material, collision_enabled: bool) -> void:
	var root: Node3D = StaticBody3D.new() if collision_enabled else Node3D.new()
	root.name = node_name
	root.position = position_value
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mesh.mesh = box
	mesh.material_override = material
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(mesh)
	if collision_enabled:
		var collision := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = size
		collision.shape = shape
		root.add_child(collision)
	add_child(root)


func _material(color: Color, roughness: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness
	return material
