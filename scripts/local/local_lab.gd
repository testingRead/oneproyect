class_name LocalDevelopmentLab
extends Node3D

const SCALE := preload("res://shared/gameplay_scale.gd")

@onready var player: LocalBaseCharacter = $World/CharacterRoot
@onready var playable_area: LocalPlayableArea = $World/PlayableArea
@onready var metrics_label: Label = $HUD/DiagnosticsPanel/Margin/Rows/Metrics
@onready var area_label: Label = $HUD/DiagnosticsPanel/Margin/Rows/Area
@onready var joystick: GrayboxVirtualJoystick = $HUD/Joystick
@onready var look_pad: LookPad = $HUD/LookPad
@onready var jump_button: TouchActionButton = $HUD/Jump
@onready var area_button: TouchActionButton = $HUD/Area

var _area_index := 1
var _initial_dynamic_count := 0
var _last_metrics: Dictionary = {}


func _ready() -> void:
	set_meta(&"runtime_mode", &"LOCAL_DEVELOPMENT")
	var network := get_node_or_null("/root/Network")
	if network != null and network.has_method("disconnect_session"):
		network.call("disconnect_session")
	_build_island_once()
	_build_scale_references_once()
	_build_test_course_once()
	_initial_dynamic_count = get_active_dynamic_object_count()
	joystick.value_changed.connect(player.set_touch_move)
	look_pad.look_delta.connect(player.add_touch_look)
	jump_button.action_pressed.connect(player.request_jump)
	area_button.action_pressed.connect(_cycle_area)
	player.metrics_changed.connect(_on_player_metrics)
	playable_area.area_changed.connect(_on_area_changed)
	playable_area.set_area_index(_area_index)
	_on_player_metrics(player.get_diagnostics())


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_pressed():
		return
	if event is InputEventKey:
		match event.physical_keycode:
			KEY_1:
				set_playable_area_index(0)
			KEY_2:
				set_playable_area_index(1)
			KEY_3:
				set_playable_area_index(2)
			KEY_R:
				reset_lab()
			KEY_ESCAPE:
				Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func set_playable_area_index(index: int) -> void:
	_area_index = clampi(index, 0, 2)
	playable_area.set_area_index(_area_index)


func reset_lab() -> void:
	player.reset_to_spawn()
	for body in get_tree().get_nodes_in_group(&"local_test_object"):
		if body is RigidBody3D and body.has_meta(&"initial_transform"):
			var rigid := body as RigidBody3D
			rigid.freeze = true
			rigid.global_transform = rigid.get_meta(&"initial_transform")
			rigid.linear_velocity = Vector3.ZERO
			rigid.angular_velocity = Vector3.ZERO
			rigid.freeze = false
	for platform in get_tree().get_nodes_in_group(&"local_moving_platform"):
		if platform.has_method("reset_platform"):
			platform.call("reset_platform")


func get_active_dynamic_object_count() -> int:
	var count := 0
	for object in get_tree().get_nodes_in_group(&"local_test_object"):
		if is_instance_valid(object):
			count += 1
	return count


func get_diagnostics() -> Dictionary:
	return {
		"runtime_mode": get_meta(&"runtime_mode", &""),
		"player": player.get_diagnostics(),
		"playable_area": playable_area.get_playable_bounds(),
		"playable_area_size": playable_area.get_area_size(),
		"boundary_count": playable_area.get_wall_count(),
		"dynamic_objects": get_active_dynamic_object_count(),
		"initial_dynamic_objects": _initial_dynamic_count,
	}


func save_capture(capture_name: String) -> Error:
	if DisplayServer.get_name() == "headless":
		return ERR_UNAVAILABLE
	var safe_name := capture_name.validate_filename()
	var directory := "user://local_base_captures"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(directory))
	var image := get_viewport().get_texture().get_image()
	return image.save_png("%s/%s.png" % [directory, safe_name])


func _cycle_area() -> void:
	set_playable_area_index((_area_index + 1) % 3)


func _on_player_metrics(metrics: Dictionary) -> void:
	_last_metrics = metrics
	var position: Vector3 = metrics.position
	var velocity: Vector3 = metrics.velocity
	metrics_label.text = (
		"POS  %6.2f  %5.2f  %6.2f\n"
		+ "VEL  %5.2f m/s  SUELO %s  MOV %4.2f\n"
		+ "PIE VIS %+.3f  CÁPSULA %+.3f  OBJ %d/%d"
	) % [
		position.x,
		position.y,
		position.z,
		Vector2(velocity.x, velocity.z).length(),
		"SÍ" if bool(metrics.on_floor) else "NO",
		float(metrics.movement_ratio),
		float(metrics.visual_foot),
		float(metrics.collision_bottom),
		get_active_dynamic_object_count(),
		_initial_dynamic_count,
	]


func _on_area_changed(size: float, bounds: Rect2) -> void:
	area_label.text = (
		"ÁREA %d × %d m  ·  MUNDO %d × %d m  ·  LÍMITES %s"
		% [
			int(size),
			int(size),
			int(SCALE.PHYSICAL_WORLD_SIZE),
			int(SCALE.PHYSICAL_WORLD_SIZE),
			str(bounds),
		]
	)


func _build_island_once() -> void:
	var content := $World/PhysicalWorld
	if content.get_child_count() > 0:
		return
	var island_material := _material(Color(0.22, 0.38, 0.24), 0.96)
	var ocean_material := _material(Color(0.03, 0.28, 0.42, 0.82), 0.55)
	ocean_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_add_static_box(
		content,
		"Island",
		Vector3(0.0, -0.2, 0.0),
		Vector3(SCALE.ISLAND_SIZE, 0.4, SCALE.ISLAND_SIZE),
		island_material
	)
	var ocean := MeshInstance3D.new()
	ocean.name = "Ocean"
	var ocean_mesh := BoxMesh.new()
	ocean_mesh.size = Vector3(
		SCALE.PHYSICAL_WORLD_SIZE,
		0.12,
		SCALE.PHYSICAL_WORLD_SIZE
	)
	ocean.mesh = ocean_mesh
	ocean.position.y = -0.52
	ocean.material_override = ocean_material
	ocean.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	content.add_child(ocean)
	_add_grid(content)


func _build_scale_references_once() -> void:
	var content := $World/ScaleReferences
	if content.get_child_count() > 0:
		return
	var neutral := _material(Color(0.72, 0.77, 0.82), 0.9)
	var accent := _material(Color(0.96, 0.62, 0.12), 0.84)
	for metre in 4:
		_add_visual_box(
			content,
			"Ruler%d" % metre,
			Vector3(-6.0, float(metre) + 0.5, -5.5),
			Vector3(0.12, 1.0, 0.12),
			accent if metre % 2 == 0 else neutral
		)
	_add_static_box(
		content,
		"DoorLeft",
		Vector3(-3.0 - SCALE.MINIMUM_PASSAGE_WIDTH * 0.5, SCALE.MINIMUM_DOOR_HEIGHT * 0.5, -5.5),
		Vector3(0.16, SCALE.MINIMUM_DOOR_HEIGHT, 0.22),
		neutral
	)
	_add_static_box(
		content,
		"DoorRight",
		Vector3(-3.0 + SCALE.MINIMUM_PASSAGE_WIDTH * 0.5, SCALE.MINIMUM_DOOR_HEIGHT * 0.5, -5.5),
		Vector3(0.16, SCALE.MINIMUM_DOOR_HEIGHT, 0.22),
		neutral
	)
	_add_static_box(
		content,
		"DoorTop",
		Vector3(-3.0, SCALE.MINIMUM_DOOR_HEIGHT + 0.12, -5.5),
		Vector3(SCALE.MINIMUM_PASSAGE_WIDTH + 0.16, 0.24, 0.22),
		neutral
	)
	_add_static_box(
		content,
		"StandardPlatform",
		Vector3(1.5, SCALE.STANDARD_PLATFORM_HEIGHT * 0.5, -5.5),
		Vector3(3.0, SCALE.STANDARD_PLATFORM_HEIGHT, 2.4),
		accent
	)


func _build_test_course_once() -> void:
	var content := $World/TestCourse
	if content.get_child_count() > 0:
		return
	var structure := _material(Color(0.22, 0.34, 0.48), 0.88)
	var object_material := _material(Color(0.88, 0.42, 0.12), 0.82)
	_add_static_box(
		content,
		"Wall",
		Vector3(8.0, 1.0, 1.5),
		Vector3(5.0, 2.0, 0.35),
		structure
	)
	var slope := _add_static_box(
		content,
		"Slope",
		Vector3(-7.0, 0.72, 3.0),
		Vector3(5.0, 0.35, 3.0),
		structure
	)
	slope.rotation_degrees.z = -14.0
	_add_moving_platform(content, structure)
	_add_rigid_box(
		content,
		"SmallBox",
		Vector3(3.0, SCALE.SMALL_OBJECT_SIZE * 0.5, 3.0),
		Vector3.ONE * SCALE.SMALL_OBJECT_SIZE,
		0.7,
		object_material
	)
	_add_rigid_box(
		content,
		"MediumBox",
		Vector3(4.5, SCALE.MEDIUM_OBJECT_SIZE * 0.5, 3.0),
		Vector3.ONE * SCALE.MEDIUM_OBJECT_SIZE,
		4.0,
		object_material
	)
	_add_rigid_box(
		content,
		"LargeBox",
		Vector3(7.0, SCALE.LARGE_OBJECT_SIZE * 0.5, 4.0),
		Vector3.ONE * SCALE.LARGE_OBJECT_SIZE,
		18.0,
		object_material
	)


func _add_grid(parent: Node3D) -> void:
	var grid_material := _material(Color(0.7, 0.9, 0.84, 0.18), 1.0)
	grid_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	grid_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var half := SCALE.ISLAND_SIZE * 0.5
	for coordinate in range(-60, 61, 5):
		_add_visual_box(
			parent,
			"GridX%d" % coordinate,
			Vector3(float(coordinate), 0.006, 0.0),
			Vector3(0.025, 0.012, half * 2.0),
			grid_material
		)
		_add_visual_box(
			parent,
			"GridZ%d" % coordinate,
			Vector3(0.0, 0.007, float(coordinate)),
			Vector3(half * 2.0, 0.012, 0.025),
			grid_material
		)


func _add_static_box(
	parent: Node3D,
	node_name: String,
	position_value: Vector3,
	size: Vector3,
	material: StandardMaterial3D
) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = node_name
	body.position = position_value
	body.collision_layer = 1
	body.collision_mask = 1
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
	parent.add_child(body)
	return body


func _add_visual_box(
	parent: Node3D,
	node_name: String,
	position_value: Vector3,
	size: Vector3,
	material: StandardMaterial3D
) -> MeshInstance3D:
	var mesh := MeshInstance3D.new()
	mesh.name = node_name
	mesh.position = position_value
	var box := BoxMesh.new()
	box.size = size
	mesh.mesh = box
	mesh.material_override = material
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mesh)
	return mesh


func _add_rigid_box(
	parent: Node3D,
	node_name: String,
	position_value: Vector3,
	size: Vector3,
	mass_value: float,
	material: StandardMaterial3D
) -> RigidBody3D:
	var body := RigidBody3D.new()
	body.name = node_name
	body.position = position_value
	body.mass = mass_value
	body.collision_layer = 1
	body.collision_mask = 3
	body.add_to_group(&"local_test_object")
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
	parent.add_child(body)
	body.set_meta(&"initial_transform", body.global_transform)
	return body


func _add_moving_platform(
	parent: Node3D,
	material: StandardMaterial3D
) -> AnimatableBody3D:
	var platform := AnimatableBody3D.new()
	platform.name = "MovingPlatform"
	platform.position = Vector3(-2.0, 0.55, 5.5)
	platform.set_script(load("res://scripts/local/moving_platform.gd"))
	platform.set("travel", Vector3(4.0, 0.0, 0.0))
	platform.add_to_group(&"local_moving_platform")
	platform.collision_layer = 1
	var size := Vector3(2.6, 0.3, 2.6)
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	collision.shape = shape
	platform.add_child(collision)
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mesh.mesh = box
	mesh.material_override = material
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	platform.add_child(mesh)
	parent.add_child(platform)
	return platform


func _material(color: Color, roughness: float) -> StandardMaterial3D:
	var result := StandardMaterial3D.new()
	result.albedo_color = color
	result.roughness = roughness
	return result
