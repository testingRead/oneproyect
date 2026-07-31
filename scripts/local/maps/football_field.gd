class_name LocalFootballField
extends Node3D

const BOT_SCRIPT := preload("res://scripts/local/maps/football_goalkeeper_bot.gd")

const FIELD_CENTRE_Z := -20.0
const BALL_SPAWN := Vector3(0.0, 2.0, FIELD_CENTRE_Z)
const NORTH_GOAL_CENTRE := Vector3(0.0, 1.18, -38.45)
const SOUTH_GOAL_CENTRE := Vector3(0.0, 1.18, -1.55)

var _grass: StandardMaterial3D
var _border: StandardMaterial3D
var _line: StandardMaterial3D
var _goal: StandardMaterial3D
var _ball_material: StandardMaterial3D
var _ball: RigidBody3D


func _ready() -> void:
	_grass = _material(Color(0.12, 0.38, 0.16), 0.96)
	_border = _material(Color(0.12, 0.19, 0.24), 0.86)
	_line = _material(Color(0.94, 0.96, 0.92), 0.8, true)
	_goal = _material(Color(0.94, 0.94, 0.88), 0.7)
	_ball_material = _material(Color(0.96, 0.94, 0.82), 0.64)
	_build_field()


func configure_variation(signature: PackedByteArray) -> void:
	# Small seed-driven physical variations keep matches surprising without
	# changing the official scale or the goal geometry.
	if not is_instance_valid(_ball) or signature.is_empty():
		return
	var material := _ball.physics_material_override as PhysicsMaterial
	if material == null:
		return
	material.friction = 0.42 if signature[0] == 0 else 0.56
	material.bounce = 0.56 if signature.size() < 2 or signature[1] == 0 else 0.7


func get_ball_spawn_transform() -> Transform3D:
	return Transform3D(Basis.IDENTITY, BALL_SPAWN)


func _build_field() -> void:
	# The island remains the physical floor. This thin mesh only identifies
	# the pitch and avoids a second overlapping collision plane.
	_add_visual_box(
		"Pitch",
		Vector3(0.0, 0.007, FIELD_CENTRE_Z),
		Vector3(24.0, 0.014, 36.0),
		_grass
	)
	_add_perimeter()
	_add_field_markings()
	_add_goal(&"north", -37.7, -39.5, -38.6, NORTH_GOAL_CENTRE)
	_add_goal(&"south", -2.3, -0.5, -1.4, SOUTH_GOAL_CENTRE)
	_add_goalkeeper_bot(&"home", Vector3(0.0, 0.95, -2.75))
	_add_goalkeeper_bot(&"away", Vector3(0.0, 0.95, -37.25))
	_add_ball()


func _add_perimeter() -> void:
	_add_static_box(
		"LeftReboundWall",
		Vector3(-12.2, 1.2, FIELD_CENTRE_Z),
		Vector3(0.4, 2.4, 36.4),
		_border
	)
	_add_static_box(
		"RightReboundWall",
		Vector3(12.2, 1.2, FIELD_CENTRE_Z),
		Vector3(0.4, 2.4, 36.4),
		_border
	)
	for end in [
		{"prefix": "North", "z": -38.2},
		{"prefix": "South", "z": -1.8},
	]:
		_add_static_box(
			"%sLeftWall" % end.prefix,
			Vector3(-8.15, 1.2, end.z),
			Vector3(10.1, 2.4, 0.4),
			_border
		)
		_add_static_box(
			"%sRightWall" % end.prefix,
			Vector3(8.15, 1.2, end.z),
			Vector3(10.1, 2.4, 0.4),
			_border
		)


func _add_field_markings() -> void:
	_add_visual_box(
		"HalfLine",
		Vector3(0.0, 0.022, FIELD_CENTRE_Z),
		Vector3(20.0, 0.025, 0.09),
		_line
	)
	_add_visual_box(
		"LeftLine",
		Vector3(-11.75, 0.023, FIELD_CENTRE_Z),
		Vector3(0.09, 0.025, 35.4),
		_line
	)
	_add_visual_box(
		"RightLine",
		Vector3(11.75, 0.023, FIELD_CENTRE_Z),
		Vector3(0.09, 0.025, 35.4),
		_line
	)
	_add_visual_box(
		"SouthLine",
		Vector3(0.0, 0.024, -2.3),
		Vector3(23.5, 0.025, 0.09),
		_line
	)
	_add_visual_box(
		"NorthLine",
		Vector3(0.0, 0.024, -37.7),
		Vector3(23.5, 0.025, 0.09),
		_line
	)
	for side in [-1.0, 1.0]:
		var penalty_z: float = FIELD_CENTRE_Z + side * 14.4
		_add_visual_box(
			"PenaltyFront%s" % ("South" if side > 0.0 else "North"),
			Vector3(0.0, 0.025, penalty_z),
			Vector3(10.0, 0.025, 0.09),
			_line
		)
		_add_visual_box(
			"PenaltyLeft%s" % ("South" if side > 0.0 else "North"),
			Vector3(-5.0, 0.025, FIELD_CENTRE_Z + side * 15.95),
			Vector3(0.09, 0.025, 3.1),
			_line
		)
		_add_visual_box(
			"PenaltyRight%s" % ("South" if side > 0.0 else "North"),
			Vector3(5.0, 0.025, FIELD_CENTRE_Z + side * 15.95),
			Vector3(0.09, 0.025, 3.1),
			_line
		)


func _add_goal(
	side: StringName,
	front_z: float,
	back_z: float,
	side_z: float,
	area_position: Vector3
) -> void:
	var prefix := "North" if side == &"north" else "South"
	_add_static_box(
		prefix + "GoalLeftPost",
		Vector3(-3.0, 1.3, front_z),
		Vector3(0.18, 2.6, 0.18),
		_goal
	)
	_add_static_box(
		prefix + "GoalRightPost",
		Vector3(3.0, 1.3, front_z),
		Vector3(0.18, 2.6, 0.18),
		_goal
	)
	_add_static_box(
		prefix + "GoalCrossbar",
		Vector3(0.0, 2.6, front_z),
		Vector3(6.18, 0.18, 0.18),
		_goal
	)
	_add_static_box(
		prefix + "GoalBack",
		Vector3(0.0, 1.3, back_z),
		Vector3(6.2, 2.6, 0.15),
		_border
	)
	_add_static_box(
		prefix + "GoalLeftSide",
		Vector3(-3.1, 1.3, side_z),
		Vector3(0.15, 2.6, 1.8),
		_border
	)
	_add_static_box(
		prefix + "GoalRightSide",
		Vector3(3.1, 1.3, side_z),
		Vector3(0.15, 2.6, 1.8),
		_border
	)
	var goal_area := Area3D.new()
	goal_area.name = prefix + "GoalArea"
	goal_area.position = area_position
	goal_area.collision_layer = 0
	goal_area.collision_mask = 1
	goal_area.monitoring = true
	goal_area.add_to_group(&"football_goal")
	goal_area.set_meta(
		&"scores_for",
		&"home" if side == &"north" else &"away"
	)
	var collision := CollisionShape3D.new()
	collision.name = "Collision"
	var shape := BoxShape3D.new()
	shape.size = Vector3(6.4, 2.6, 1.6)
	collision.shape = shape
	goal_area.add_child(collision)
	add_child(goal_area)
	_add_goalkeeper_zone(prefix, area_position)


func _add_goalkeeper_zone(prefix: String, area_position: Vector3) -> void:
	var zone := Area3D.new()
	zone.name = prefix + "GoalkeeperZone"
	zone.position = area_position + Vector3(0.0, 0.0, 0.55 if prefix == "North" else -0.55)
	zone.collision_layer = 0
	zone.collision_mask = 1
	zone.monitoring = true
	zone.add_to_group(&"goalkeeper_zone")
	zone.set_meta(&"goal_side", &"home" if prefix == "North" else &"away")
	var collision := CollisionShape3D.new()
	collision.name = "Collision"
	var shape := BoxShape3D.new()
	shape.size = Vector3(7.2, 2.8, 2.8)
	collision.shape = shape
	zone.add_child(collision)
	add_child(zone)


func _add_ball() -> void:
	var ball := RigidBody3D.new()
	ball.name = "Football"
	ball.position = BALL_SPAWN
	ball.mass = 0.43
	ball.collision_layer = 1
	ball.collision_mask = 1
	ball.continuous_cd = true
	ball.linear_damp = 0.28
	ball.angular_damp = 0.2
	ball.add_to_group(&"football_ball")
	ball.add_to_group(&"kickable_ball")
	ball.add_to_group(&"local_round_object")
	_ball = ball
	var physics_material := PhysicsMaterial.new()
	physics_material.friction = 0.48
	physics_material.bounce = 0.62
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


func _add_goalkeeper_bot(side: StringName, position_value: Vector3) -> void:
	var bot := Node3D.new()
	bot.set_script(BOT_SCRIPT)
	bot.name = "HomeGoalkeeperBot" if side == &"home" else "AwayGoalkeeperBot"
	bot.position = position_value
	bot.add_to_group(&"football_goalkeeper_bot")
	bot.set_meta(&"goal_side", side)
	var body := MeshInstance3D.new()
	var capsule := CapsuleMesh.new()
	capsule.radius = 0.34
	capsule.height = 1.55
	body.mesh = capsule
	body.material_override = _material(
		Color(0.92, 0.45, 0.12) if side == &"home" else Color(0.18, 0.48, 0.92),
		0.92
	)
	body.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	body.position.y = 0.05
	bot.add_child(body)
	var head := MeshInstance3D.new()
	var head_mesh := SphereMesh.new()
	head_mesh.radius = 0.24
	head_mesh.height = 0.48
	head.mesh = head_mesh
	head.material_override = _material(Color(0.82, 0.62, 0.45), 0.92)
	head.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	head.position = Vector3(0.0, 0.92, 0.0)
	bot.add_child(head)
	add_child(bot)


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
	var physics_material := PhysicsMaterial.new()
	physics_material.friction = 0.38
	physics_material.bounce = 0.72
	body.physics_material_override = physics_material
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
