class_name LocalPlayableArea
extends Node3D

const SCALE := preload("res://shared/gameplay_scale.gd")

signal area_changed(size: float, bounds: Rect2)

@export_enum("Small:30", "Medium:60", "Large:100") var initial_area := 1
@export var wall_height := 1.6
@export var wall_thickness := 0.28

var _size := SCALE.PLAYABLE_AREA_MEDIUM
var _walls: Array[StaticBody3D] = []
var _physical_walls_enabled := false


func _ready() -> void:
	_build_walls_once()
	set_area_index(initial_area)


func set_area_index(index: int) -> void:
	match clampi(index, 0, 2):
		0:
			set_area_size(SCALE.PLAYABLE_AREA_SMALL)
		1:
			set_area_size(SCALE.PLAYABLE_AREA_MEDIUM)
		_:
			set_area_size(SCALE.PLAYABLE_AREA_LARGE)


func set_area_size(value: float) -> void:
	_size = clampf(
		value,
		SCALE.PLAYABLE_AREA_SMALL,
		SCALE.PLAYABLE_AREA_LARGE
	)
	if _walls.size() != 4:
		return
	var half := _size * 0.5
	_configure_wall(_walls[0], Vector3(0.0, wall_height * 0.5, -half), Vector3(_size, wall_height, wall_thickness))
	_configure_wall(_walls[1], Vector3(0.0, wall_height * 0.5, half), Vector3(_size, wall_height, wall_thickness))
	_configure_wall(_walls[2], Vector3(-half, wall_height * 0.5, 0.0), Vector3(wall_thickness, wall_height, _size))
	_configure_wall(_walls[3], Vector3(half, wall_height * 0.5, 0.0), Vector3(wall_thickness, wall_height, _size))
	area_changed.emit(_size, get_playable_bounds())


func set_physical_walls_enabled(enabled: bool) -> void:
	_physical_walls_enabled = enabled
	for wall in _walls:
		(wall.get_node("Collision") as CollisionShape3D).disabled = not enabled
		_update_guide(wall)


func are_physical_walls_enabled() -> bool:
	return _physical_walls_enabled


func get_area_size() -> float:
	return _size


func get_playable_bounds(margin := 0.0) -> Rect2:
	var center := Vector2(global_position.x, global_position.z)
	var bounds := SCALE.playable_bounds(_size, center)
	var safe_margin := clampf(margin, 0.0, _size * 0.45)
	return bounds.grow(-safe_margin)


func contains_world_position(world_position: Vector3, margin := 0.0) -> bool:
	return get_playable_bounds(margin).has_point(
		Vector2(world_position.x, world_position.z)
	)


func clamp_world_position(world_position: Vector3, margin := 0.0) -> Vector3:
	var bounds := get_playable_bounds(margin)
	return Vector3(
		clampf(world_position.x, bounds.position.x, bounds.end.x),
		world_position.y,
		clampf(world_position.z, bounds.position.y, bounds.end.y)
	)


func get_wall_count() -> int:
	return _walls.size()


func _build_walls_once() -> void:
	if not _walls.is_empty():
		return
	var wall_material := StandardMaterial3D.new()
	wall_material.albedo_color = Color(0.08, 0.78, 0.9, 0.22)
	wall_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	wall_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	for index in 4:
		var body := StaticBody3D.new()
		body.name = "Boundary%d" % (index + 1)
		body.collision_layer = 2
		body.collision_mask = 1
		var shape := CollisionShape3D.new()
		shape.name = "Collision"
		shape.shape = BoxShape3D.new()
		body.add_child(shape)
		var mesh := MeshInstance3D.new()
		mesh.name = "Guide"
		mesh.mesh = BoxMesh.new()
		mesh.material_override = wall_material
		mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		body.add_child(mesh)
		add_child(body)
		_walls.append(body)
	set_physical_walls_enabled(_physical_walls_enabled)


func _configure_wall(body: StaticBody3D, wall_position: Vector3, size: Vector3) -> void:
	body.position = wall_position
	var shape := body.get_node("Collision") as CollisionShape3D
	(shape.shape as BoxShape3D).size = size
	var mesh := body.get_node("Guide") as MeshInstance3D
	(mesh.mesh as BoxMesh).size = size
	_update_guide(body)


func _update_guide(body: StaticBody3D) -> void:
	var collision := body.get_node("Collision") as CollisionShape3D
	var collision_size := (collision.shape as BoxShape3D).size
	var mesh := body.get_node("Guide") as MeshInstance3D
	if _physical_walls_enabled:
		mesh.position = Vector3.ZERO
		(mesh.mesh as BoxMesh).size = collision_size
	else:
		mesh.position = Vector3(0.0, -body.position.y + 0.015, 0.0)
		(mesh.mesh as BoxMesh).size = Vector3(
			collision_size.x,
			0.03,
			collision_size.z
		)
