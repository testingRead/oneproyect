class_name LocalDevelopmentLab
extends Node3D

const SCALE := preload("res://shared/gameplay_scale.gd")
const LAB_MAP: MinigameMapDefinition = preload("res://data/maps/campo_futbol_local.tres")

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
@onready var hand_button: TouchActionButton = $HUD/HandAction
@onready var foot_button: TouchActionButton = $HUD/FootAction
@onready var goalkeeper_left_high: TouchActionButton = $HUD/GoalkeeperLeftHigh
@onready var goalkeeper_left_mid: TouchActionButton = $HUD/GoalkeeperLeftMid
@onready var goalkeeper_left_low: TouchActionButton = $HUD/GoalkeeperLeftLow
@onready var goalkeeper_right_high: TouchActionButton = $HUD/GoalkeeperRightHigh
@onready var goalkeeper_right_mid: TouchActionButton = $HUD/GoalkeeperRightMid
@onready var goalkeeper_right_low: TouchActionButton = $HUD/GoalkeeperRightLow
@onready var round_button: TouchActionButton = $HUD/Round
@onready var crosshair: Label = $HUD/Crosshair
@onready var map_host: LocalMapHost = $World/RoundContent/MapHost
@onready var football_host = $FootballHost
@onready var round_controller: LocalRoundController = $RoundController

var _area_index := 1
var _last_metrics: Dictionary = {}


func _ready() -> void:
	set_meta(&"runtime_mode", &"LOCAL_DEVELOPMENT")
	var network := get_node_or_null("/root/Network")
	if network != null and network.has_method("disconnect_session"):
		network.call("disconnect_session")
	_build_island_once()
	$HUD/DiagnosticsPanel.hide()
	hand_button.hide()
	round_button.set_label("JUGAR")
	joystick.value_changed.connect(player.set_touch_move)
	look_pad.look_delta.connect(player.add_touch_look)
	jump_button.action_pressed.connect(player.request_jump)
	foot_button.action_pressed.connect(player.request_foot_action)
	goalkeeper_left_high.action_pressed.connect(_on_goalkeeper_dive.bind(-1, 2))
	goalkeeper_left_mid.action_pressed.connect(_on_goalkeeper_dive.bind(-1, 1))
	goalkeeper_left_low.action_pressed.connect(_on_goalkeeper_dive.bind(-1, 0))
	goalkeeper_right_high.action_pressed.connect(_on_goalkeeper_dive.bind(1, 2))
	goalkeeper_right_mid.action_pressed.connect(_on_goalkeeper_dive.bind(1, 1))
	goalkeeper_right_low.action_pressed.connect(_on_goalkeeper_dive.bind(1, 0))
	round_button.action_pressed.connect(start_reference_round)
	player.metrics_changed.connect(_on_player_metrics)
	playable_area.area_changed.connect(_on_area_changed)
	round_controller.configure(
		LAB_MAP,
		map_host,
		football_host,
		player,
		playable_area
	)
	round_controller.phase_changed.connect(_on_round_phase_changed)
	football_host.score_changed.connect(_on_football_score_changed)
	football_host.goal_scored.connect(_on_goal_scored)
	football_host.kickoff_ready.connect(_on_kickoff_ready)
	football_host.goalkeeper_zone_changed.connect(_on_goalkeeper_zone_changed)
	football_host.goalkeeper_save.connect(_on_goalkeeper_save)
	playable_area.set_area_index(_area_index)
	playable_area.set_physical_walls_enabled(false)
	_on_player_metrics(player.get_diagnostics())
	_on_round_phase_changed(LocalRoundController.Phase.IDLE, "IDLE", 0.0)


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_pressed():
		return
	if event is InputEventKey:
		match event.physical_keycode:
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
	player.set_facing_direction(Vector3(0.0, 0.0, -1.0))
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
		"initial_dynamic_objects": 0,
		"round_phase": round_controller.get_phase_name(),
		"round_seed": round_controller.round_seed,
		"mounted_map_nodes": map_host.get_mounted_node_count(),
		"football_home_score": football_host.score,
		"football_away_score": football_host.opponent_score,
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
		"SAQUE",
		"JUGANDO",
		"RESULTADO",
		"LIMPIANDO",
	]
	round_label.text = (
		"FÚTBOL  %s  ·  %.1f s"
		% [phase_labels[next_phase], seconds]
	)
	if next_phase != LocalRoundController.Phase.ACTIVE:
		_on_goalkeeper_zone_changed(false, &"")
	match next_phase:
		LocalRoundController.Phase.IDLE:
			round_button.show()
			crosshair.hide()
			banner_title.text = "FÚTBOL DE REBOTE"
			banner_detail.text = "Pulsa JUGAR para entrar a la cancha"
			banner_progress.text = "Dos arcos · paredes · primero a 3"
			_on_player_metrics(player.get_diagnostics())
		LocalRoundController.Phase.PREPARE:
			round_button.hide()
			crosshair.show()
			banner_title.text = "PREPARANDO LA CANCHA"
			banner_detail.text = "El balón caerá en el centro"
			banner_progress.text = "La patada sigue al cuerpo, no a la cámara"
		LocalRoundController.Phase.RULES:
			banner_title.text = "FÚTBOL · DOS ARCOS"
			banner_detail.text = "Marca en el arco rival y defiende el tuyo"
			banner_progress.text = "La pelota rebota en las paredes"
		LocalRoundController.Phase.COUNTDOWN:
			banner_title.text = "SAQUE · 3"
			banner_detail.text = "Muévete para colocarte detrás del balón"
			banner_progress.text = "La mira es orientativa; el pie usa tu orientación"
		LocalRoundController.Phase.ACTIVE:
			banner_title.text = "¡JUGAR!"
			banner_detail.text = "PATEA al arco rival · protege el tuyo"
			banner_progress.text = _score_text()
		LocalRoundController.Phase.RESULT:
			crosshair.hide()
			var winner: int = football_host.get_winner()
			banner_title.text = (
				"¡GANASTE!" if winner > 0
				else "GANÓ EL RIVAL" if winner < 0
				else "EMPATE"
			)
			banner_detail.text = "La cancha se limpiará y volverás a la isla"
			banner_progress.text = _score_text()
		LocalRoundController.Phase.CLEANUP:
			banner_title.text = "REINICIANDO CANCHA"
			banner_detail.text = "Restaurando balón, jugadores y cámara"
			banner_progress.text = "La siguiente ronda parte del centro"


func _score_text() -> String:
	return "TÚ %d  ·  RIVAL %d  ·  PRIMERO A %d" % [
		football_host.score,
		football_host.opponent_score,
		football_host.target_score,
	]


func _on_football_score_changed(
	_home_score: int,
	_away_score: int,
	_target: int
) -> void:
	banner_progress.text = _score_text()


func _on_goal_scored(scoring_side: StringName) -> void:
	banner_detail.text = (
		"¡GOL TUYO! El balón vuelve al centro"
		if scoring_side == &"home"
		else "¡GOL DEL RIVAL! El balón vuelve al centro"
	)


func _on_goalkeeper_dive(side: int, level: int) -> void:
	if football_host.is_goalkeeper_in_zone():
		player.request_goalkeeper_dive(side, level)


func _on_goalkeeper_zone_changed(active: bool, _side: StringName) -> void:
	active = active and _side == football_host.get_player_goal_side()
	for button in [
		goalkeeper_left_high,
		goalkeeper_left_mid,
		goalkeeper_left_low,
		goalkeeper_right_high,
		goalkeeper_right_mid,
		goalkeeper_right_low,
	]:
		button.visible = active and round_controller.phase == LocalRoundController.Phase.ACTIVE


func _on_goalkeeper_save(_side: StringName, level: int) -> void:
	banner_detail.text = "¡ATAJADA! %s · brazos extendidos" % [
		["abajo", "al centro", "arriba"][level]
	]


func _on_kickoff_ready() -> void:
	if round_controller.phase != LocalRoundController.Phase.ACTIVE:
		return
	player.set_spawn_transform(map_host.get_spawn_transform(0))
	player.set_facing_direction(Vector3(0.0, 0.0, -1.0))
	banner_detail.text = "Saque desde el centro"


func _on_player_metrics(metrics: Dictionary) -> void:
	_last_metrics = metrics
	var position: Vector3 = metrics.position
	var velocity: Vector3 = metrics.velocity
	metrics_label.text = (
		"POS  %6.2f  %5.2f  %6.2f\n"
		+ "VEL  %5.2f m/s  SUELO %s  MOV %4.2f\n"
		+ "PIE VIS %+.3f  CÁPSULA %+.3f"
	) % [
		position.x,
		position.y,
		position.z,
		Vector2(velocity.x, velocity.z).length(),
		"SÍ" if bool(metrics.on_floor) else "NO",
		float(metrics.movement_ratio),
		float(metrics.visual_foot),
		float(metrics.collision_bottom),
	]


func _on_area_changed(size: float, _bounds: Rect2) -> void:
	area_label.text = "ISLA %d × %d m  ·  CANCHA 26 × 40 m" % [
		int(SCALE.ISLAND_SIZE),
		int(SCALE.ISLAND_SIZE),
	]


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
