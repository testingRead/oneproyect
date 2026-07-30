extends Control

const NET := preload("res://shared/net_constants.gd")
const CHARACTER_CATALOG := preload("res://scripts/characters/character_catalog.gd")
const REMOTE_AVATAR_SCENE := preload("res://scenes/components/remote_avatar.tscn")
const LOADING_SCENE := preload("res://scenes/loading_screen.tscn")
const GAME_SCENE := "res://scenes/main.tscn"
const PROFILE_PATH := "user://profile.cfg"

@onready var network: OneProjectNetwork = get_node("/root/Network")

var _main_screen: VBoxContainer
var _lobby_screen: VBoxContainer
var _waiting_screen: VBoxContainer
var _name_input: LineEdit
var _profile_summary: Label
var _lobby_status: Label
var _empty_rooms: Label
var _create_button: Button
var _refresh_button: Button
var _waiting_title: Label
var _waiting_detail: Label
var _character_button: OptionButton
var _character_preview: RemoteAvatar
var _character_viewport: SubViewport
var _ready_button: Button
var _start_button: Button
var _rounds_button: OptionButton
var _exclusion_button: OptionButton
var _room_buttons: Array[Button] = []
var _room_ids := PackedInt32Array()
var _room_count := 0
var _maximum_rooms := NET.MAX_ROOMS
var _loading_game := false
var _local_ready := false
var _is_host := false
var _total_victories := 0
var _multiplayer_experience := 0
var _multiplayer_matches := 0
var _multiplayer_rounds := 0
var _multiplayer_survivals := 0


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_build_interface()
	_connect_network()
	_load_name()
	if network.is_in_waiting_room():
		if not network.replay_waiting_room():
			_show_screen(_waiting_screen)
			_waiting_detail.text = "Recuperando estado de la sala…"
	elif network.is_in_lobby():
		_show_screen(_lobby_screen)
		_on_lobby_ready(NET.MAX_ROOMS, NET.MAX_PLAYERS_PER_ROOM)
	else:
		_show_screen(_main_screen)


func _build_interface() -> void:
	var background := ColorRect.new()
	background.name = "Background"
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.color = Color(0.025, 0.035, 0.055, 1.0)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)

	var accent := ColorRect.new()
	accent.name = "Accent"
	accent.anchor_right = 1.0
	accent.offset_bottom = 8.0
	accent.color = Color(0.12, 0.72, 0.76, 1.0)
	accent.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(accent)

	var panel := PanelContainer.new()
	panel.name = "MenuPanel"
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.position = Vector2(-390.0, -350.0)
	panel.size = Vector2(780.0, 700.0)
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.055, 0.075, 0.11, 0.98)
	panel_style.border_color = Color(0.18, 0.45, 0.52, 0.9)
	panel_style.set_border_width_all(2)
	panel_style.set_corner_radius_all(18)
	panel_style.content_margin_left = 36.0
	panel_style.content_margin_right = 36.0
	panel_style.content_margin_top = 28.0
	panel_style.content_margin_bottom = 28.0
	panel.add_theme_stylebox_override("panel", panel_style)
	add_child(panel)

	var screens := Control.new()
	screens.name = "Screens"
	screens.custom_minimum_size = Vector2(708.0, 644.0)
	panel.add_child(screens)
	_main_screen = _build_main_screen(screens)
	_lobby_screen = _build_lobby_screen(screens)
	_waiting_screen = _build_waiting_screen(screens)


func _build_main_screen(parent: Control) -> VBoxContainer:
	var screen := _new_screen("Main")
	parent.add_child(screen)
	screen.add_child(_title("ONE PROYECT", 42, Color(0.35, 0.95, 0.9)))
	var subtitle := _label("Sobrevive, empuja y supera el desastre", 19)
	subtitle.modulate = Color(0.76, 0.86, 1.0)
	screen.add_child(subtitle)
	_profile_summary = _label("PERFIL MULTIJUGADOR", 16)
	_profile_summary.name = "ProfileSummary"
	_profile_summary.modulate = Color(0.45, 0.95, 0.78)
	screen.add_child(_profile_summary)
	screen.add_child(_spacer(8.0))
	var name_label := _label("NOMBRE DEL JUGADOR", 16)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	screen.add_child(name_label)
	_name_input = LineEdit.new()
	_name_input.name = "PlayerName"
	_name_input.custom_minimum_size = Vector2(0.0, 50.0)
	_name_input.max_length = 16
	_name_input.placeholder_text = "Jugador"
	_name_input.add_theme_font_size_override("font_size", 20)
	screen.add_child(_name_input)
	screen.add_child(_spacer(10.0))
	var local_button := _button("JUGAR LOCAL", "PlayLocal")
	local_button.pressed.connect(_play_local)
	screen.add_child(local_button)
	var multiplayer_button := _button("MULTIJUGADOR", "Multiplayer")
	multiplayer_button.pressed.connect(_open_multiplayer)
	screen.add_child(multiplayer_button)
	screen.add_child(_spacer(8.0))
	var hint := _label(
		"Local funciona sin servidor · Multijugador: 2–5 jugadores",
		15
	)
	hint.modulate = Color(0.64, 0.74, 0.86)
	screen.add_child(hint)
	return screen


func _build_lobby_screen(parent: Control) -> VBoxContainer:
	var screen := _new_screen("Lobby")
	parent.add_child(screen)
	screen.add_child(_title("SALAS MULTIJUGADOR", 30, Color(0.35, 0.95, 0.9)))
	_lobby_status = _label("Conectando al servidor…", 17)
	screen.add_child(_lobby_status)
	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 10)
	_create_button = _button("CREAR SALA", "CreateRoom")
	_create_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_create_button.disabled = true
	_create_button.pressed.connect(_create_room)
	actions.add_child(_create_button)
	_refresh_button = _button("ACTUALIZAR", "RefreshRooms")
	_refresh_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_refresh_button.disabled = true
	_refresh_button.pressed.connect(network.request_room_list)
	actions.add_child(_refresh_button)
	screen.add_child(actions)
	_empty_rooms = _label("No hay salas. Crea la primera.", 18)
	_empty_rooms.custom_minimum_size.y = 42.0
	screen.add_child(_empty_rooms)
	for index in NET.MAX_ROOMS:
		var room_button := _button("SALA %d" % (index + 1), "Room%d" % (index + 1))
		room_button.visible = false
		room_button.pressed.connect(_join_room.bind(index))
		_room_buttons.append(room_button)
		screen.add_child(room_button)
	var back := _button("VOLVER", "Back")
	back.pressed.connect(_leave_multiplayer)
	screen.add_child(back)
	return screen


func _build_waiting_screen(parent: Control) -> VBoxContainer:
	var screen := _new_screen("WaitingRoom")
	screen.add_theme_constant_override("separation", 7)
	parent.add_child(screen)
	_waiting_title = _title("SALA", 34, Color(0.35, 0.95, 0.9))
	_waiting_title.name = "WaitingTitle"
	screen.add_child(_waiting_title)
	_waiting_detail = _label("Esperando jugadores…", 18)
	_waiting_detail.name = "WaitingPlayers"
	_waiting_detail.custom_minimum_size.y = 115.0
	_waiting_detail.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	screen.add_child(_waiting_detail)
	var character_row := HBoxContainer.new()
	character_row.add_theme_constant_override("separation", 12)
	_character_button = OptionButton.new()
	_character_button.name = "RoomCharacter"
	_character_button.custom_minimum_size = Vector2(0.0, 52.0)
	_character_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_character_button.add_theme_font_size_override("font_size", 18)
	for index in CHARACTER_CATALOG.NAMES.size():
		var suffix := (
			" · BLOQUEADO"
			if index == CHARACTER_CATALOG.GOLDEN_INDEX
			else ""
		)
		_character_button.add_item(
			"%s%s" % [CHARACTER_CATALOG.NAMES[index], suffix],
			index
		)
	_character_button.item_selected.connect(_on_character_selected)
	character_row.add_child(_character_button)
	character_row.add_child(_build_character_preview())
	screen.add_child(character_row)
	var rule := _label(
		"El personaje queda bloqueado al marcar LISTO.",
		15
	)
	rule.modulate = Color(0.72, 0.82, 0.94)
	screen.add_child(rule)
	_rounds_button = OptionButton.new()
	_rounds_button.name = "MatchRounds"
	_rounds_button.custom_minimum_size = Vector2(0.0, 48.0)
	_rounds_button.add_theme_font_size_override("font_size", 18)
	for rounds: int in NET.MATCH_ROUND_OPTIONS:
		_rounds_button.add_item("PARTIDA: %d RONDAS" % rounds, rounds)
	_rounds_button.select(NET.MATCH_ROUND_OPTIONS.find(NET.DEFAULT_MATCH_ROUNDS))
	_rounds_button.item_selected.connect(_on_round_count_selected)
	screen.add_child(_rounds_button)
	_exclusion_button = OptionButton.new()
	_exclusion_button.name = "ModeExclusion"
	_exclusion_button.custom_minimum_size = Vector2(0.0, 48.0)
	_exclusion_button.add_theme_font_size_override("font_size", 17)
	_exclusion_button.add_item("VETO: NINGUNO", -1)
	_exclusion_button.add_item("VETO: METEORITOS", NET.ModeId.METEORS)
	_exclusion_button.add_item("VETO: ONDA", NET.ModeId.SHOCKWAVE)
	_exclusion_button.add_item("VETO: INUNDACIÓN", NET.ModeId.FLOOD)
	_exclusion_button.add_item("VETO: SHOOTER", NET.ModeId.SHOOTER)
	_exclusion_button.add_item("VETO: DOMINIO", NET.ModeId.DOMAIN)
	_exclusion_button.add_item("VETO: DRONES", NET.ModeId.DRONE_HUNT)
	_exclusion_button.item_selected.connect(_on_exclusion_selected)
	screen.add_child(_exclusion_button)
	var veto_rule := _label(
		"Un voto por jugador · siempre quedan al menos 3 modos válidos.",
		14
	)
	veto_rule.modulate = Color(0.62, 0.78, 0.9)
	screen.add_child(veto_rule)
	_ready_button = _button("MARCAR LISTO", "ReadyRoom")
	_ready_button.pressed.connect(_toggle_ready)
	screen.add_child(_ready_button)
	_start_button = _button("INICIAR PARTIDA", "StartRoom")
	_start_button.visible = false
	_start_button.disabled = true
	_start_button.pressed.connect(network.start_room)
	screen.add_child(_start_button)
	var leave := _button("SALIR DE LA SALA", "LeaveRoom")
	leave.pressed.connect(network.leave_room)
	screen.add_child(leave)
	return screen


func _connect_network() -> void:
	network.status_changed.connect(_on_network_status)
	network.lobby_ready.connect(_on_lobby_ready)
	network.room_list_updated.connect(_on_room_list)
	network.room_waiting_updated.connect(_on_room_waiting)
	network.room_started.connect(_on_room_started)
	network.room_action_failed.connect(_on_room_error)
	network.returned_to_lobby.connect(_on_returned_to_lobby)


func _play_local() -> void:
	_save_name()
	network.disconnect_session()
	_loading_game = true
	_show_loading("PREPARANDO PARTIDA LOCAL")


func _open_multiplayer() -> void:
	_save_name()
	_show_screen(_lobby_screen)
	_lobby_status.text = "Conectando al servidor…"
	_create_button.disabled = true
	_refresh_button.disabled = true
	var error := network.connect_to_lobby()
	if error != OK:
		_lobby_status.text = "No se pudo iniciar la conexión"


func _leave_multiplayer() -> void:
	network.disconnect_session()
	_show_screen(_main_screen)


func _create_room() -> void:
	_create_button.disabled = true
	_lobby_status.text = "Creando sala…"
	network.create_room()


func _join_room(index: int) -> void:
	if index < 0 or index >= _room_ids.size():
		return
	for button in _room_buttons:
		button.disabled = true
	_lobby_status.text = "Entrando a sala %d…" % _room_ids[index]
	network.join_room(_room_ids[index])


func _on_network_status(text: String, _online: bool) -> void:
	if _lobby_screen.visible:
		_lobby_status.text = text


func _on_lobby_ready(maximum_rooms: int, _maximum_players: int) -> void:
	_maximum_rooms = maximum_rooms
	_create_button.disabled = false
	_refresh_button.disabled = false
	_lobby_status.text = "Elige una sala o crea una nueva"
	network.request_room_list()


func _on_room_list(
	room_ids: PackedInt32Array,
	player_counts: PackedInt32Array,
	phases: PackedInt32Array,
	host_names: PackedStringArray
) -> void:
	_room_ids = room_ids
	_room_count = room_ids.size()
	_empty_rooms.visible = _room_count == 0
	_create_button.disabled = _room_count >= _maximum_rooms
	for index in _room_buttons.size():
		var button := _room_buttons[index]
		button.visible = index < _room_count
		if not button.visible:
			continue
		var waiting := phases[index] == NET.RoomPhase.WAITING
		var host := host_names[index] if not host_names[index].is_empty() else "Sin anfitrión"
		button.text = "SALA %d  ·  %d/5  ·  %s" % [
			room_ids[index],
			player_counts[index],
			host if waiting else "EN PARTIDA",
		]
		button.disabled = not waiting or player_counts[index] >= NET.MAX_PLAYERS_PER_ROOM
	_lobby_status.text = "Salas disponibles: %d/%d" % [_room_count, _maximum_rooms]


func _on_room_waiting(
	room_id: int,
	player_count: int,
	is_host: bool,
	ready_count: int,
	local_ready: bool,
	all_ready: bool,
	player_names: PackedStringArray,
	ready_flags: PackedByteArray,
	character_indices: PackedByteArray,
	victory_counts: PackedInt32Array,
	experience_values: PackedInt32Array,
	total_rounds: int
) -> void:
	_show_screen(_waiting_screen)
	_is_host = is_host
	_local_ready = local_ready
	_waiting_title.text = (
		"SALA %d · ERES ANFITRIÓN" % room_id
		if is_host
		else "SALA %d" % room_id
	)
	var player_states := PackedStringArray()
	var visible_count := mini(player_names.size(), ready_flags.size())
	visible_count = mini(visible_count, character_indices.size())
	visible_count = mini(visible_count, victory_counts.size())
	visible_count = mini(visible_count, experience_values.size())
	for index in visible_count:
		var character_index := CHARACTER_CATALOG.sanitize_index(character_indices[index])
		player_states.append(
			"%s  %s · %s · %d victorias · %d XP" % [
				"✓" if ready_flags[index] != 0 else "○",
				player_names[index],
				CHARACTER_CATALOG.NAMES[character_index],
				victory_counts[index],
				experience_values[index],
			]
		)
	_waiting_detail.text = "%d/5 JUGADORES · %d LISTOS\n%s" % [
		player_count,
		ready_count,
		"\n".join(player_states),
	]
	_character_button.disabled = local_ready
	_exclusion_button.disabled = local_ready
	_rounds_button.disabled = not is_host
	var rounds_index := NET.MATCH_ROUND_OPTIONS.find(total_rounds)
	if rounds_index >= 0:
		_rounds_button.select(rounds_index)
	_ready_button.disabled = false
	_ready_button.text = "CANCELAR LISTO" if local_ready else "MARCAR LISTO"
	_start_button.visible = is_host
	_start_button.disabled = (
		player_count < NET.MIN_PLAYERS_TO_START
		or not all_ready
	)
	_start_button.text = (
		"INICIAR PARTIDA"
		if all_ready
		else "ESPERANDO JUGADORES LISTOS"
	)


func _on_room_started(_room_id: int) -> void:
	if _loading_game:
		return
	_loading_game = true
	_character_button.disabled = true
	_exclusion_button.disabled = true
	_ready_button.disabled = true
	_start_button.disabled = true
	_waiting_detail.text = "Iniciando partida…"
	_show_loading("SINCRONIZANDO MINIJUEGO")


func _show_loading(status: String) -> void:
	var loading := LOADING_SCENE.instantiate() as OneProjectLoadingScreen
	get_tree().root.add_child(loading)
	loading.begin(GAME_SCENE, status)


func _on_room_error(reason: String) -> void:
	var messages := {
		"room_limit": "Ya existen cinco salas.",
		"room_full": "La sala está llena.",
		"room_missing": "La sala ya no existe.",
		"room_unavailable": "La partida ya comenzó.",
		"need_two_players": "Se necesitan al menos dos jugadores.",
		"players_not_ready": "Todos deben marcar LISTO antes de iniciar.",
		"host_only": "Sólo el anfitrión puede iniciar.",
	}
	_lobby_status.text = str(messages.get(reason, "No se pudo completar la acción."))
	_create_button.disabled = _room_count >= _maximum_rooms
	for index in _room_buttons.size():
		if index < _room_count:
			_room_buttons[index].disabled = false


func _on_returned_to_lobby() -> void:
	_show_screen(_lobby_screen)
	_create_button.disabled = false
	_refresh_button.disabled = false
	network.request_room_list()
	_local_ready = false
	_is_host = false


func _show_screen(screen: Control) -> void:
	_main_screen.visible = screen == _main_screen
	_lobby_screen.visible = screen == _lobby_screen
	_waiting_screen.visible = screen == _waiting_screen


func _load_name() -> void:
	var config := ConfigFile.new()
	if config.load(PROFILE_PATH) == OK:
		var saved := str(config.get_value("player", "name", "")).strip_edges().substr(0, 16)
		if not saved.is_empty():
			network.display_name = saved
		network.color_index = CHARACTER_CATALOG.sanitize_index(
			int(config.get_value("player", "character", network.color_index))
		)
		_total_victories = maxi(
			0,
			int(config.get_value("player", "total_victories", 0))
		)
		_multiplayer_experience = maxi(
			0,
			int(config.get_value("player", "multiplayer_experience", 0))
		)
		_multiplayer_matches = maxi(
			0,
			int(config.get_value("player", "multiplayer_matches", 0))
		)
		_multiplayer_rounds = maxi(
			0,
			int(config.get_value("player", "multiplayer_rounds", 0))
		)
		_multiplayer_survivals = maxi(
			0,
			int(config.get_value("player", "multiplayer_survivals", 0))
		)
	network.profile_victories = _total_victories
	network.profile_experience = _multiplayer_experience
	_name_input.text = network.display_name
	_profile_summary.text = (
		"%d VICTORIAS · %d XP · %d PARTIDAS · %d/%d RONDAS SOBREVIVIDAS"
		% [
			_total_victories,
			_multiplayer_experience,
			_multiplayer_matches,
			_multiplayer_survivals,
			_multiplayer_rounds,
		]
	)
	_character_button.select(network.color_index)
	_update_character_preview()


func _save_name() -> void:
	var safe_name := _name_input.text.strip_edges().substr(0, 16)
	if safe_name.is_empty():
		safe_name = network.display_name
	_name_input.text = safe_name
	network.display_name = safe_name
	var config := ConfigFile.new()
	config.load(PROFILE_PATH)
	config.set_value("player", "name", safe_name)
	config.save(PROFILE_PATH)


func _on_character_selected(index: int) -> void:
	if _local_ready or _loading_game:
		_character_button.select(network.color_index)
		return
	var next_index := CHARACTER_CATALOG.sanitize_index(index)
	if (
		next_index == CHARACTER_CATALOG.GOLDEN_INDEX
		and _total_victories < CHARACTER_CATALOG.GOLDEN_CHARACTER_COST
	):
		_character_button.select(network.color_index)
		_waiting_detail.text = (
			"DORADO requiere %d victorias multijugador"
			% CHARACTER_CATALOG.GOLDEN_CHARACTER_COST
		)
		return
	network.color_index = next_index
	_save_character()
	_update_character_preview()
	if network.is_online():
		network.set_room_profile(false)


func _toggle_ready() -> void:
	if not network.is_online() or _loading_game:
		return
	_ready_button.disabled = true
	network.set_room_profile(not _local_ready)


func _on_round_count_selected(index: int) -> void:
	if not _is_host or _loading_game:
		return
	network.set_room_rules(_rounds_button.get_item_id(index))


func _on_exclusion_selected(index: int) -> void:
	if _local_ready or _loading_game:
		return
	network.excluded_mode_id = _exclusion_button.get_item_id(index)
	if network.is_online():
		network.set_room_profile(false, network.excluded_mode_id)


func _save_character() -> void:
	var config := ConfigFile.new()
	config.load(PROFILE_PATH)
	config.set_value("player", "character", network.color_index)
	config.save(PROFILE_PATH)


func _build_character_preview() -> SubViewportContainer:
	var container := SubViewportContainer.new()
	container.custom_minimum_size = Vector2(112.0, 84.0)
	container.stretch = true
	var viewport := SubViewport.new()
	viewport.size = Vector2i(224, 192)
	viewport.transparent_bg = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	_character_viewport = viewport
	container.add_child(viewport)
	var camera := Camera3D.new()
	camera.position = Vector3(0.0, 0.55, 4.0)
	camera.current = true
	viewport.add_child(camera)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-35.0, -25.0, 0.0)
	light.shadow_enabled = false
	viewport.add_child(light)
	_character_preview = REMOTE_AVATAR_SCENE.instantiate()
	_character_preview.position = Vector3(0.0, -0.25, 0.0)
	viewport.add_child(_character_preview)
	return container


func _update_character_preview() -> void:
	if _character_preview == null:
		return
	_character_preview.configure("", network.color_index, Vector3(0.0, -0.25, 0.0))
	_character_preview.get_node("Name").visible = false
	_character_preview.set_process(false)
	_character_preview.set_shadow_quality(false)
	_character_preview.set_texture_detail(false)
	_character_preview.set_model_quality(true)
	_character_preview.set_detail_quality(2)
	_character_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE


func _new_screen(screen_name: String) -> VBoxContainer:
	var screen := VBoxContainer.new()
	screen.name = screen_name
	screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	screen.add_theme_constant_override("separation", 10)
	return screen


func _title(text_value: String, size: int, color: Color) -> Label:
	var result := _label(text_value, size)
	result.add_theme_color_override("font_color", color)
	return result


func _label(text_value: String, size: int) -> Label:
	var result := Label.new()
	result.text = text_value
	result.add_theme_font_size_override("font_size", size)
	result.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	result.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return result


func _button(text_value: String, node_name: String) -> Button:
	var result := Button.new()
	result.name = node_name
	result.text = text_value
	result.custom_minimum_size = Vector2(0.0, 52.0)
	result.add_theme_font_size_override("font_size", 20)
	return result


func _spacer(height: float) -> Control:
	var result := Control.new()
	result.custom_minimum_size.y = height
	return result
