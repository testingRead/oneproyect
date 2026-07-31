class_name LocalDevelopmentLab
extends Node3D

const SCALE := preload("res://shared/gameplay_scale.gd")
const LAB_MAP: MinigameMapDefinition = preload("res://data/maps/campo_futbol_local.tres")
const MENU_SCENE := "res://scenes/menu.tscn"
const CROWN_HOST_SCRIPT := preload("res://scripts/local/local_crown_host.gd")

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
@onready var round_button: TouchActionButton = $HUD/Round
@onready var crosshair: Label = $HUD/Crosshair
@onready var map_host: LocalMapHost = $World/RoundContent/MapHost
@onready var football_host = $FootballHost
@onready var round_controller: LocalRoundController = $RoundController

var _area_index := 1
var _last_metrics: Dictionary = {}
var _penalty_buttons: Array[TouchActionButton] = []
var _launched_from_room := false
var _match_has_started := false
var _selected_map: MinigameMapDefinition = LAB_MAP
var _selected_minigame_id: StringName = &"futbol_rebote"
var crown_host


func _ready() -> void:
	set_meta(&"runtime_mode", &"LOCAL_DEVELOPMENT")
	var network := get_node_or_null("/root/Network")
	if network != null and network.has_method("disconnect_session"):
		player.set_meta("display_name", str(network.get("display_name")))
		network.call("disconnect_session")
	_build_island_once()
	_load_room_content()
	crown_host = CROWN_HOST_SCRIPT.new()
	crown_host.name = "CrownHost"
	add_child(crown_host)
	$HUD/DiagnosticsPanel.hide()
	hand_button.hide()
	_create_penalty_buttons()
	round_button.set_label("JUGAR")
	joystick.value_changed.connect(player.set_touch_move)
	look_pad.look_delta.connect(player.add_touch_look)
	jump_button.action_pressed.connect(player.request_jump)
	foot_button.action_pressed.connect(player.request_foot_action)
	round_button.action_pressed.connect(_on_round_button_pressed)
	player.metrics_changed.connect(_on_player_metrics)
	playable_area.area_changed.connect(_on_area_changed)
	round_controller.configure(
		_selected_map,
		map_host,
		football_host,
		crown_host,
		_selected_minigame_id,
		player,
		playable_area
	)
	round_controller.phase_changed.connect(_on_round_phase_changed)
	football_host.score_changed.connect(_on_football_score_changed)
	football_host.goal_scored.connect(_on_goal_scored)
	football_host.kickoff_ready.connect(_on_kickoff_ready)
	football_host.penalty_choice_requested.connect(_on_penalty_choice_requested)
	football_host.penalty_cinematic.connect(_on_penalty_cinematic)
	football_host.penalty_score_changed.connect(_on_penalty_score_changed)
	crown_host.crown_holder_changed.connect(_on_crown_holder_changed)
	crown_host.match_completed.connect(_on_crown_match_completed)
	playable_area.set_area_index(_area_index)
	playable_area.set_physical_walls_enabled(false)
	_on_player_metrics(player.get_diagnostics())
	_on_round_phase_changed(LocalRoundController.Phase.IDLE, "IDLE", 0.0)
	_launched_from_room = bool(ProjectSettings.get_setting("oneproyect/session_auto_start", false))
	ProjectSettings.set_setting("oneproyect/session_auto_start", false)
	if _launched_from_room:
		round_button.hide()
		call_deferred("start_reference_round")


func _load_room_content() -> void:
	var minigame_path := str(ProjectSettings.get_setting("oneproyect/session_minigame_path", ""))
	var minigame: Variant = null
	if not minigame_path.is_empty():
		minigame = load(minigame_path)
	if minigame != null and minigame.map_definition != null:
		_selected_map = minigame.map_definition
		_selected_minigame_id = minigame.minigame_id
	var character_path := str(ProjectSettings.get_setting("oneproyect/session_character_path", ""))
	if not character_path.is_empty():
		player.set_meta("character_definition_path", character_path)


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
	_match_has_started = true
	var selected_seed := seed
	if selected_seed == 0:
		selected_seed = int(Time.get_ticks_msec())
	return round_controller.start_round(selected_seed)


func _on_round_button_pressed() -> void:
	if _launched_from_room and _match_has_started:
		ProjectSettings.set_setting("oneproyect/reopen_room", true)
		get_tree().change_scene_to_file(MENU_SCENE)
		return
	start_reference_round()


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
	foot_button.visible = not _is_crown_game()
	match next_phase:
		LocalRoundController.Phase.IDLE:
			if _launched_from_room and _match_has_started:
				round_button.set_label("VOLVER A LA SALA")
				round_button.show()
			else:
				round_button.set_label("JUGAR")
				round_button.show()
			crosshair.hide()
			banner_title.text = "FÚTBOL DE REBOTE"
			banner_detail.text = (
				"La partida terminó. Vuelve a la sala para elegir de nuevo."
				if _launched_from_room and _match_has_started
				else "Pulsa JUGAR para entrar a la cancha"
			)
			banner_progress.text = "Dos arcos · paredes · primero a 3"
			_on_player_metrics(player.get_diagnostics())
		LocalRoundController.Phase.PREPARE:
			round_button.hide()
			crosshair.show()
			banner_title.text = "PREPARANDO %s" % _minigame_title()
			banner_detail.text = "La corona espera en el centro" if _is_crown_game() else "El balón caerá en el centro"
			banner_progress.text = "Todos corren a la misma velocidad" if _is_crown_game() else "La patada sigue al cuerpo, no a la cámara"
		LocalRoundController.Phase.RULES:
			banner_title.text = "CORONA CENTRAL" if _is_crown_game() else "FÚTBOL · DOS ARCOS"
			banner_detail.text = "Toma la corona y evita que te la quiten" if _is_crown_game() else "Marca en el arco rival y defiende el tuyo"
			banner_progress.text = "El contacto roba la corona" if _is_crown_game() else "La pelota rebota en las paredes"
		LocalRoundController.Phase.COUNTDOWN:
			banner_title.text = "CORONA · 3" if _is_crown_game() else "SAQUE · 3"
			banner_detail.text = "Corre hacia el círculo central" if _is_crown_game() else "Muévete para colocarte detrás del balón"
			banner_progress.text = "La corona aparece al centro" if _is_crown_game() else "La mira es orientativa; el pie usa tu orientación"
		LocalRoundController.Phase.ACTIVE:
			banner_title.text = "¡CORONA!" if _is_crown_game() else "¡JUGAR!"
			banner_detail.text = "Consigue la corona" if _is_crown_game() else "PATEA al arco rival · protege el tuyo"
			banner_progress.text = "CORONA: %s" % crown_host.get_holder_name() if _is_crown_game() else _score_text()
		LocalRoundController.Phase.RESULT:
			crosshair.hide()
			var winner: int = crown_host.get_winner() if _is_crown_game() else football_host.get_winner()
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


func _on_kickoff_ready() -> void:
	if round_controller.phase != LocalRoundController.Phase.ACTIVE:
		return
	player.set_spawn_transform(map_host.get_spawn_transform(0))
	player.set_facing_direction(Vector3(0.0, 0.0, -1.0))
	banner_detail.text = "Saque desde el centro"


func _on_crown_holder_changed(holder_name: String) -> void:
	if _is_crown_game():
		banner_detail.text = "%s tiene la corona" % holder_name
		banner_progress.text = "CORONA: %s" % holder_name


func _on_crown_match_completed(holder_name: String) -> void:
	if _is_crown_game():
		banner_detail.text = "%s conserva la corona" % holder_name


func _is_crown_game() -> bool:
	return _selected_minigame_id == &"corona_central"


func _minigame_title() -> String:
	return "CORONA CENTRAL" if _is_crown_game() else "FÚTBOL"


func _create_penalty_buttons() -> void:
	var labels := ["IZQUIERDA", "CENTRO", "DERECHA"]
	for index in 3:
		var button := TouchActionButton.new()
		button.name = "Penalty%s" % labels[index]
		button.label = labels[index]
		button.accent = Color(0.72, 0.31, 0.12, 0.94)
		button.visible = false
		button.z_index = 40
		button.anchor_left = 0.5
		button.anchor_right = 0.5
		button.anchor_top = 1.0
		button.anchor_bottom = 1.0
		button.offset_left = -180.0 + index * 120.0
		button.offset_right = -70.0 + index * 120.0
		button.offset_top = -140.0
		button.offset_bottom = -30.0
		button.action_pressed.connect(_on_penalty_direction.bind(index - 1))
		$HUD.add_child(button)
		_penalty_buttons.append(button)


func _on_penalty_choice_requested(attempt: int, _seconds: float) -> void:
	player.set_first_person(false)
	player.global_position = Vector3(0.0, 0.02, -6.2)
	player.set_facing_direction(Vector3(0.0, 0.0, -1.0))
	banner_title.text = "PENALES · TIRO %d DE 5" % attempt
	banner_detail.text = "Elige la dirección del disparo"
	banner_progress.text = "El arquero bot elegirá una dirección"
	for button in _penalty_buttons:
		button.show()


func _on_penalty_direction(direction: int) -> void:
	for button in _penalty_buttons:
		button.hide()
	football_host.submit_penalty_choice(direction)


func _on_penalty_cinematic(shot_direction: int, save_direction: int, scored: bool) -> void:
	banner_title.text = "CINEMÁTICA DE PENAL"
	banner_detail.text = "Balón %s · arquero %s" % [
		["IZQUIERDA", "CENTRO", "DERECHA"][shot_direction + 1],
		["IZQUIERDA", "CENTRO", "DERECHA"][save_direction + 1],
	]
	banner_progress.text = "¡GOL!" if scored else "¡ATAJADA!"


func _on_penalty_score_changed(home: int, away: int, attempt: int) -> void:
	banner_progress.text = "PENALES  TÚ %d · RIVAL %d · TIRO %d/5" % [home, away, attempt]


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
