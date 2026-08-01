class_name LocalBateballArena
extends Node3D

const CENTRE := Vector3(0.0, 0.0, -20.0)
const BALL_BOUNDS := AABB(
	Vector3(-14.35, 0.2, -39.35),
	Vector3(28.7, 4.6, 38.7)
)


func _ready() -> void:
	var floor := _material(Color(0.09, 0.19, 0.29), 0.92)
	var wall := _material(Color(0.15, 0.11, 0.27), 0.8)
	var cover := _material(Color(0.72, 0.38, 0.12), 0.82)
	_add_box("ArenaFloor", CENTRE, Vector3(30.0, 0.04, 40.0), floor, false)
	for item in [
		[Vector3(-15.0, 2.5, -20.0), Vector3(0.5, 5.0, 40.5)],
		[Vector3(15.0, 2.5, -20.0), Vector3(0.5, 5.0, 40.5)],
		[Vector3(0.0, 2.5, -40.0), Vector3(30.5, 5.0, 0.5)],
		[Vector3(0.0, 2.5, 0.0), Vector3(30.5, 5.0, 0.5)],
	]:
		_add_box("ArenaWall", item[0], item[1], wall, true)
	for item in [
		[Vector3(-6.0, 0.7, -14.5), Vector3(3.2, 1.4, 1.1)],
		[Vector3(6.0, 0.7, -25.5), Vector3(3.2, 1.4, 1.1)],
		[Vector3(-7.4, 0.7, -25.0), Vector3(1.2, 1.4, 3.8)],
		[Vector3(7.4, 0.7, -15.0), Vector3(1.2, 1.4, 3.8)],
	]:
		_add_box("Cover", item[0], item[1], cover, true)
	_add_goal(&"north", -39.15)
	_add_goal(&"south", -0.85)
	_add_ball()


func _add_goal(side: StringName, z: float) -> void:
	var goal := Area3D.new()
	goal.name = "GoalNorth" if side == &"north" else "GoalSouth"
	goal.position = Vector3(0.0, 1.1, z)
	goal.collision_layer = 0
	goal.collision_mask = 1
	goal.add_to_group(&"bateball_goal")
	goal.set_meta(&"scores_for", &"home" if side == &"north" else &"away")
	var shape := BoxShape3D.new()
	shape.size = Vector3(6.2, 2.2, 1.1)
	var collision := CollisionShape3D.new()
	collision.shape = shape
	goal.add_child(collision)
	add_child(goal)
	for x in [-3.0, 3.0]:
		_add_box("GoalPost", Vector3(x, 1.25, z), Vector3(0.18, 2.5, 0.18), _material(Color(0.9, 0.92, 0.98), 0.6), true)
	_add_box("GoalBar", Vector3(0.0, 2.48, z), Vector3(6.18, 0.18, 0.18), _material(Color(0.9, 0.92, 0.98), 0.6), true)


func _add_ball() -> void:
	var ball := RigidBody3D.new()
	ball.name = "Bateball"
	ball.position = CENTRE + Vector3(0.0, 0.28, 0.0)
	ball.mass = 0.34
	ball.linear_damp = 0.12
	ball.continuous_cd = true
	ball.max_contacts_reported = 8
	ball.collision_layer = 1
	ball.collision_mask = 1
	var ball_physics := PhysicsMaterial.new()
	ball_physics.bounce = 0.84
	ball_physics.friction = 0.08
	ball.physics_material_override = ball_physics
	ball.add_to_group(&"bateball_ball")
	ball.add_to_group(&"local_round_object")
	var collision := CollisionShape3D.new()
	var shape := SphereShape3D.new()
	shape.radius = 0.26
	collision.shape = shape
	ball.add_child(collision)
	var mesh := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.26
	sphere.height = 0.52
	mesh.mesh = sphere
	mesh.material_override = _material(Color(1.0, 0.78, 0.12), 0.54)
	ball.add_child(mesh)
	add_child(ball)


func get_ball_bounds() -> AABB:
	return BALL_BOUNDS


func _add_box(node_name: String, position_value: Vector3, size_value: Vector3, material: Material, collision_enabled: bool) -> void:
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


func _material(color: Color, roughness: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness
	return material
