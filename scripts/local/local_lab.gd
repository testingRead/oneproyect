class_name LocalDevelopmentLab
extends Node3D

const SCALE := preload("res://shared/gameplay_scale.gd")
const LAB_MAP: MinigameMapDefinition = preload("res://data/maps/isla_laboratorio.tres")

@onready var player: LocalBaseCharacter = $World/CharacterRoot
@onready var playable_area: LocalPlayableArea = $World/PlayableArea
@onready var metrics_label: Label = $HUD/DiagnosticsPanel/Margin/Rows/Metrics
@onready var area_label: Label = $HUD/DiagnosticsPanel/Margin/Rows/Area
@onready var round_label: Label = $HUD/DiagnosticsPanel/Margin/Rows/Round
@onready var banner_title: Label = $HUD/RoundBanner/Margin/Rows/Title
@onready var banner_detail: Label = $HUD/RoundBanner/Margin/Rows/Detail
@onready var banner_progress: Label = $HUD/RoundBanner/Margin/Rows/Progress
@onready var joystick: GrayboxVirtualJoystick = $HUD/Joystick
@onready var look_pad: LookPad = $HUD/LookPad
@onready var jump_button: TouchActionButton = $HUD/Jump
@onready var push_button: TouchActionButton = $HUD/Push
@onready var round_button: TouchActionButton = $HUD/Round
@onready var map_host: LocalMapHost = $World/RoundContent/MapHost
@onready var event_host: LocalEventHost = $World/RoundContent/EventHost
@onready var round_controller: LocalRoundController = $RoundController

var _area_index := 1
var _initial_dynamic_count := 0
var _last_metrics: Dictionary = {}
var _round_warning_count := 0
var _round_impact_count := 0


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
	push_button.action_pressed.connect(player.request_push)
	round_button.action_pressed.connect(start_reference_round)
	player.push_performed.connect(_on_push_performed)
	player.metrics_changed.connect(_on_player_metrics)
	playable_area.area_changed.connect(_on_area_changed)
	round_controller.configure(
		LAB_MAP,
		map_host,
		event_host,
		player,
		playable_area
	)
	round_controller.phase_changed.connect(_on_round_phase_changed)
	event_host.event_warning.connect(_on_event_warning)
	event_host.event_impact.connect(_on_event_impact)
	playable_area.set_area_index(_area_index)
	playable_area.set_physical_walls_enabled(false)
	_on_player_metrics(player.get_diagnostics())
	_on_round_phase_changed(LocalRoundController.Phase.IDLE, "IDLE", 0.0)


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
			KEY_ENTER:
				start_reference_round()
			KEY_ESCAPE:
				Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func set_playable_area_index(index: int) -> void:
	_area_index = clampi(index, 0, 2)
	playable_area.set_area_index(_area_index)


func reset_lab() -> void:
	round_controller.stop_and_clean()
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
	_on_player_metrics(player.get_diagnostics())


func start_reference_round(seed := 0) -> bool:
	var selected_seed := seed
	if selected_seed == 0:
		selected_seed = int(Time.get_ticks_msec())
	return round_controller.start_round(selected_seed)


func get_active_dynamic_object_count() -> int:
	var count := 0
	for object in get_tree().get_nodes_in_group(&"local_test_object"):
		if is_instance_valid(object):
			count += 1
	return count


func get_interaction_counts() -> Dictionary:
	return {
		"static": get_tree().get_nodes_in_group(&"interaction_static").size(),
		"mobile": get_tree().get_nodes_in_group(&"interaction_mobile").size(),
		"movable": get_tree().get_nodes_in_group(&"interaction_movable").size(),
	}


func get_diagnostics() -> Dictionary:
	return {
		"runtime_mode": get_meta(&"runtime_mode", &""),
		"player": player.get_diagnostics(),
		"playable_area": playable_area.get_playable_bounds(),
		"playable_area_size": playable_area.get_area_size(),
		"boundary_count": playable_area.get_wall_count(),
		"dynamic_objects": get_active_dynamic_object_count(),
		"initial_dynamic_objects": _initial_dynamic_count,
		"round_phase": round_controller.get_phase_name(),
		"round_seed": round_controller.round_seed,
		"mounted_map_nodes": map_host.get_mounted_node_count(),
		"event_pool": event_host.get_pool_size(),
		"active_event_objects": event_host.get_active_count(),
		"event_impacts": event_host.get_impact_count(),
		"interaction_counts": get_interaction_counts(),
		"shore_boundaries": get_tree().get_nodes_in_group(
			&"island_shore_boundary"
		).size(),
	}


func save_capture(capture_name: String) -> Error:
	if DisplayServer.get_name() == "headless":
		return ERR_UNAVAILABLE
	var safe_name := capture_name.validate_filename()
	var directory := "user://local_base_captures"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(directory))
	var image := get_viewport().get_texture().get_image()
	return image.save_png("%s/%s.png" % [directory, safe_name])


func _on_round_phase_changed(
	next_phase: LocalRoundController.Phase,
	_label: String,
	seconds: float
) -> void:
	var phase_labels := [
		"LISTA",
		"PREPARANDO",
		"REGLAS",
		"CUENTA REGRESIVA",
		"ACTIVA",
		"RESULTADO",
		"LIMPIANDO",
	]
	round_label.text = (
		"RONDA %s  ·  %.1f s  ·  semilla %d"
		% [phase_labels[next_phase], seconds, round_controller.round_seed]
	)
	match next_phase:
		LocalRoundController.Phase.IDLE:
			banner_title.text = "LABORATORIO LOCAL"
			banner_detail.text = (
				"Choca o usa EMPUJAR sobre los objetos · "
				+ "RONDA inicia la prueba"
			)
			banner_progress.text = (
				"Objetivo: evita las 3 zonas rojas de meteorito"
			)
			_on_player_metrics(player.get_diagnostics())
		LocalRoundController.Phase.PREPARE:
			_round_warning_count = 0
			_round_impact_count = 0
			banner_title.text = "MONTANDO ARENA"
			banner_detail.text = "Trasladando al personaje al escenario de prueba"
			banner_progress.text = "Los objetos de la ronda se limpiarán al terminar"
		LocalRoundController.Phase.RULES:
			banner_title.text = "METEORITOS"
			banner_detail.text = "Muévete y sal de los círculos rojos antes del impacto"
			banner_progress.text = "Tres impactos · sin red · física local"
		LocalRoundController.Phase.COUNTDOWN:
			banner_title.text = "PREPÁRATE · 3"
			banner_detail.text = "Mira hacia la arena y localiza las advertencias"
			banner_progress.text = "Los controles se activan al comenzar"
		LocalRoundController.Phase.ACTIVE:
			banner_title.text = "¡SOBREVIVE!"
			banner_detail.text = "Evita cada círculo rojo"
			banner_progress.text = "Advertencias 0/3 · impactos 0/3"
		LocalRoundController.Phase.RESULT:
			banner_title.text = "PRUEBA COMPLETADA"
			banner_detail.text = "La física y los impactos se resolvieron localmente"
			banner_progress.text = "Impactos observados %d/3" % _round_impact_count
		LocalRoundController.Phase.CLEANUP:
			banner_title.text = "LIMPIANDO ESCENARIO"
			banner_detail.text = "Eliminando mapa y restaurando objetos"
			banner_progress.text = "La siguiente ronda parte del mismo estado"


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
		"EVENTOS %d × %d m  ·  ISLA %d × %d m  ·  COSTA FÍSICA"
		% [
			int(size),
			int(size),
			int(SCALE.ISLAND_SIZE),
			int(SCALE.ISLAND_SIZE),
		]
	)


func _on_push_performed(hit: bool) -> void:
	if round_controller.phase != LocalRoundController.Phase.IDLE:
		return
	banner_progress.text = (
		"EMPUJE: objeto alcanzado"
		if hit
		else "EMPUJE: acércate y mira hacia un objeto"
	)


func _on_event_warning(_position: Vector3, _index: int) -> void:
	_round_warning_count += 1
	banner_progress.text = (
		"Advertencias %d/3 · impactos %d/3"
		% [_round_warning_count, _round_impact_count]
	)


func _on_event_impact(_position: Vector3) -> void:
	_round_impact_count += 1
	banner_progress.text = (
		"Advertencias %d/3 · impactos %d/3"
		% [_round_warning_count, _round_impact_count]
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
	_add_shore_boundaries(content)
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
	content.get_node("Wall").add_to_group(&"interaction_static")
	var slope := _add_static_box(
		content,
		"Slope",
		Vector3(-7.0, 0.72, 3.0),
		Vector3(5.0, 0.35, 3.0),
		structure
	)
	slope.rotation_degrees.z = -14.0
	var moving_platform := _add_moving_platform(content, structure)
	_add_object_label(moving_platform, "PLATAFORMA MÓVIL", 0.45, Color(0.5, 0.85, 1.0))
	var small_box := _add_rigid_box(
		content,
		"SmallBox",
		Vector3(3.0, SCALE.SMALL_OBJECT_SIZE * 0.5, 3.0),
		Vector3.ONE * SCALE.SMALL_OBJECT_SIZE,
		0.7,
		object_material
	)
	_add_object_label(small_box, "CAJA LIGERA · 0.7 kg", 0.65, Color(1.0, 0.78, 0.28))
	var ball := _add_rigid_sphere(
		content,
		"Ball",
		Vector3(-3.5, 0.46, 5.0),
		0.45,
		0.55,
		_material(Color(0.92, 0.9, 0.78), 0.68),
		Vector3.ONE
	)
	_add_object_label(ball, "BALÓN · 0.55 kg · EMPÚJALO", 1.05, Color(1.0, 0.96, 0.72))
	var rock := _add_rigid_sphere(
		content,
		"Rock",
		Vector3(-5.0, 0.56, 5.0),
		0.55,
		3.5,
		_material(Color(0.36, 0.38, 0.4), 0.98),
		Vector3.ONE
	)
	_add_object_label(rock, "PIEDRA · 3.5 kg · PESADA", 1.18, Color(0.86, 0.9, 0.95))
	var medium_box := _add_rigid_box(
		content,
		"MediumBox",
		Vector3(4.5, SCALE.MEDIUM_OBJECT_SIZE * 0.5, 3.0),
		Vector3.ONE * SCALE.MEDIUM_OBJECT_SIZE,
		4.0,
		object_material
	)
	_add_object_label(medium_box, "CAJA MEDIA · 4 kg", 1.05, Color(1.0, 0.68, 0.22))
	var large_box := _add_rigid_box(
		content,
		"LargeBox",
		Vector3(7.0, SCALE.LARGE_OBJECT_SIZE * 0.5, 4.0),
		Vector3.ONE * SCALE.LARGE_OBJECT_SIZE,
		18.0,
		object_material
	)
	_add_object_label(large_box, "CAJA PESADA · 18 kg", 1.65, Color(1.0, 0.5, 0.16))


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
	body.add_to_group(&"interaction_movable")
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


func _add_rigid_sphere(
	parent: Node3D,
	node_name: String,
	position_value: Vector3,
	radius: float,
	mass_value: float,
	material: StandardMaterial3D,
	visual_scale: Vector3
) -> RigidBody3D:
	var body := RigidBody3D.new()
	body.name = node_name
	body.position = position_value
	body.mass = mass_value
	body.collision_layer = 1
	body.collision_mask = 3
	body.add_to_group(&"local_test_object")
	body.add_to_group(&"interaction_movable")
	var physics_material := PhysicsMaterial.new()
	physics_material.friction = 0.72
	physics_material.bounce = 0.18 if node_name == "Ball" else 0.04
	body.physics_material_override = physics_material
	var collision := CollisionShape3D.new()
	var shape := SphereShape3D.new()
	shape.radius = radius
	collision.shape = shape
	body.add_child(collision)
	var mesh := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = radius
	sphere.height = radius * 2.0
	sphere.radial_segments = 16
	sphere.rings = 8
	mesh.mesh = sphere
	mesh.scale = visual_scale
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
	platform.add_to_group(&"interaction_mobile")
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


func _add_object_label(
	parent: Node3D,
	text_value: String,
	height: float,
	color: Color
) -> void:
	var label := Label3D.new()
	label.name = "ObjectLabel"
	label.position.y = height
	label.text = text_value
	label.font_size = 28
	label.pixel_size = 0.009
	label.modulate = color
	label.outline_modulate = Color(0.015, 0.025, 0.04, 0.95)
	label.outline_size = 7
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.render_priority = 2
	parent.add_child(label)


func _add_shore_boundaries(parent: Node3D) -> void:
	var half := SCALE.ISLAND_SIZE * 0.5 - 0.35
	var length := SCALE.ISLAND_SIZE
	var positions := [
		Vector3(0.0, 1.5, -half),
		Vector3(0.0, 1.5, half),
		Vector3(-half, 1.5, 0.0),
		Vector3(half, 1.5, 0.0),
	]
	var sizes := [
		Vector3(length, 3.0, 0.5),
		Vector3(length, 3.0, 0.5),
		Vector3(0.5, 3.0, length),
		Vector3(0.5, 3.0, length),
	]
	for index in 4:
		var body := StaticBody3D.new()
		body.name = "ShoreBoundary%d" % (index + 1)
		body.position = positions[index]
		body.collision_layer = 1
		body.add_to_group(&"island_shore_boundary")
		var collision := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = sizes[index]
		collision.shape = shape
		body.add_child(collision)
		parent.add_child(body)


func _material(color: Color, roughness: float) -> StandardMaterial3D:
	var result := StandardMaterial3D.new()
	result.albedo_color = color
	result.roughness = roughness
	return result
