class_name LocalFootballField
extends Node3D

const BALL_SPAWN := Vector3(0.0, 0.23, -13.0)

var _grass: StandardMaterial3D
var _border: StandardMaterial3D
var _line: StandardMaterial3D
var _goal: StandardMaterial3D
var _ball_material: StandardMaterial3D


func _ready() -> void:
	_grass = _material(Color(0.12, 0.38, 0.16), 0.96)
	_border = _material(Color(0.18, 0.24, 0.28), 0.9)
	_line = _material(Color(0.92, 0.95, 0.9), 0.8, true)
	_goal = _material(Color(0.92, 0.92, 0.86), 0.72)
	_ball_material = _material(Color(0.95, 0.94, 0.84), 0.64)
	_build_field()


func configure_variation(_signature: PackedByteArray) -> void:
	# The first football validation has one deterministic layout.
	pass


func get_ball_spawn_transform() -> Transform3D:
	return Transform3D(Basis.IDENTITY, BALL_SPAWN)


func _build_field() -> void:
	_add_static_box("Pitch", Vector3(0.0, -0.12, -20.0), Vector3(20.0, 0.24, 30.0), _grass)
	_add_static_box("LeftFence", Vector3(-10.2, 0.65, -20.0), Vector3(0.4, 1.3, 30.4), _border)
	_add_static_box("RightFence", Vector3(10.2, 0.65, -20.0), Vector3(0.4, 1.3, 30.4), _border)
	_add_static_box("SouthFence", Vector3(0.0, 0.65, -4.8), Vector3(20.4, 1.3, 0.4), _border)
	_add_static_box("NorthFenceLeft", Vector3(-6.7, 0.65, -35.2), Vector3(7.0, 1.3, 0.4), _border)
	_add_static_box("NorthFenceRight", Vector3(6.7, 0.65, -35.2), Vector3(7.0, 1.3, 0.4), _border)

	_add_visual_box("HalfLine", Vector3(0.0, 0.015, -20.0), Vector3(20.0, 0.025, 0.09), _line)
	_add_visual_box("LeftLine", Vector3(-9.75, 0.016, -20.0), Vector3(0.09, 0.025, 29.4), _line)
	_add_visual_box("RightLine", Vector3(9.75, 0.016, -20.0), Vector3(0.09, 0.025, 29.4), _line)
	_add_visual_box("SouthLine", Vector3(0.0, 0.017, -5.3), Vector3(19.5, 0.025, 0.09), _line)
	_add_visual_box("NorthLine", Vector3(0.0, 0.017, -34.7), Vector3(19.5, 0.025, 0.09), _line)
	_add_visual_box("PenaltyFront", Vector3(0.0, 0.018, -28.5), Vector3(10.0, 0.025, 0.09), _line)
	_add_visual_box("PenaltyLeft", Vector3(-5.0, 0.018, -31.6), Vector3(0.09, 0.025, 6.2), _line)
	_add_visual_box("PenaltyRight", Vector3(5.0, 0.018, -31.6), Vector3(0.09, 0.025, 6.2), _line)

	_add_static_box("GoalLeftPost", Vector3(-3.0, 1.3, -34.7), Vector3(0.18, 2.6, 0.18), _goal)
	_add_static_box("GoalRightPost", Vector3(3.0, 1.3, -34.7), Vector3(0.18, 2.6, 0.18), _goal)
	_add_static_box("GoalCrossbar", Vector3(0.0, 2.6, -34.7), Vector3(6.18, 0.18, 0.18), _goal)
	_add_static_box("GoalBack", Vector3(0.0, 1.3, -36.5), Vector3(6.2, 2.6, 0.15), _border)
	_add_static_box("GoalLeftSide", Vector3(-3.1, 1.3, -35.6), Vector3(0.15, 2.6, 1.8), _border)
	_add_static_box("GoalRightSide", Vector3(3.1, 1.3, -35.6), Vector3(0.15, 2.6, 1.8), _border)
	_add_goal_area()
	_add_ball()


func _add_goal_area() -> void:
	var goal_area := Area3D.new()
	goal_area.name = "TargetGoal"
	goal_area.position = Vector3(0.0, 1.18, -35.45)
	goal_area.collision_layer = 0
	goal_area.collision_mask = 1
	goal_area.monitoring = true
	goal_area.add_to_group(&"football_goal")
	var collision := CollisionShape3D.new()
	collision.name = "Collision"
	var shape := BoxShape3D.new()
	shape.size = Vector3(5.8, 2.35, 1.25)
	collision.shape = shape
	goal_area.add_child(collision)
	add_child(goal_area)


func _add_ball() -> void:
	var ball := RigidBody3D.new()
	ball.name = "Football"
	ball.position = BALL_SPAWN
	ball.mass = 0.43
	ball.collision_layer = 1
	ball.collision_mask = 1
	ball.continuous_cd = true
	ball.add_to_group(&"football_ball")
	ball.add_to_group(&"kickable_ball")
	ball.add_to_group(&"local_round_object")
	var physics_material := PhysicsMaterial.new()
	physics_material.friction = 0.58
	physics_material.bounce = 0.52
	ball.physics_material_override = physics_material
	var collision := CollisionShape3D.new()
	collision.name = "Collision"
	var shape := SphereShape3D.new()
	shape.radius = 0.22
	collision.shape = shape
	ball.add_child(collision)
	var mesh := MeshInstance3D.new()
	mesh.name = "Mesh"
	var sphere := SphereMesh.new()
	sphere.radius = 0.22
	sphere.height = 0.44
	sphere.radial_segments = 16
	sphere.rings = 8
	mesh.mesh = sphere
	mesh.material_override = _ball_material
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	ball.add_child(mesh)
	add_child(ball)


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


func _add_visual_box(
	node_name: String,
	position_value: Vector3,
	size: Vector3,
	material: StandardMaterial3D
) -> void:
	var mesh := MeshInstance3D.new()
	mesh.name = node_name
	mesh.position = position_value
	var box := BoxMesh.new()
	box.size = size
	mesh.mesh = box
	mesh.material_override = material
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mesh)


func _material(
	color: Color,
	roughness_value: float,
	unshaded := false
) -> StandardMaterial3D:
	var result := StandardMaterial3D.new()
	result.albedo_color = color
	result.roughness = roughness_value
	result.shading_mode = (
		BaseMaterial3D.SHADING_MODE_UNSHADED
		if unshaded
		else BaseMaterial3D.SHADING_MODE_PER_PIXEL
	)
	return result
