extends Control

const NET := preload("res://shared/net_constants.gd")
const CHARACTER_CATALOG := preload("res://scripts/characters/character_catalog.gd")
const CONTENT_REGISTRY := preload("res://scripts/content/content_registry.gd")
const REMOTE_AVATAR_SCENE := preload("res://scenes/components/remote_avatar.tscn")
const LOADING_SCENE := preload("res://scenes/loading_screen.tscn")
const GAME_SCENE := "res://scenes/main.tscn"
const LOCAL_LAB_SCENE := "res://scenes/local/local_lab.tscn"
const PROFILE_PATH := "user://profile.cfg"
const LAN_SESSION_SCRIPT := preload("res://scripts/network/lan_session.gd")
const ISLAND_THEME := preload("res://scripts/ui/island_theme.gd")
const ISLAND_ART := preload("res://scripts/ui/island_art.gd")

@onready var network: OneProjectNetwork = get_node("/root/Network")
var lan

var _main_screen: VBoxContainer
var _lan_screen: VBoxContainer
var _lan_room_screen: VBoxContainer
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
var _waiting_roster: HBoxContainer
var _character_button: OptionButton
var _character_preview: RemoteAvatar
var _character_viewport: SubViewport
var _ready_button: Button
var _start_button: Button
var _online_mode_button: OptionButton
var _online_mode_art: Control
var _online_mode_title: Label
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
var _lan_mode_button: OptionButton
var _lan_status: Label
var _lan_start_button: Button
var _lan_address_input: LineEdit
var _lan_room_title: Label
var _lan_room_detail: Label
var _lan_room_roster: HBoxContainer
var _lan_room_character: OptionButton
var _lan_room_mode: OptionButton
var _lan_room_ready: Button
var _lan_room_start: Button
var _lan_mode_art: Control
var _lan_mode_title: Label
var _lan_mode_description: Label
var _lan_host_badge: Label
var _lan_room_capacity: Label
var _lan_room_is_local := false
var _lan_room_ready_state := false
var _lan_room_is_host := false
var _local_characters: Array = []
var _local_minigames: Array = []


func _ready() -> void:
	lan = get_node_or_null("/root/LanSession")
	if lan == null:
		lan = LAN_SESSION_SCRIPT.new()
		lan.name = "LanSession"
		get_tree().root.add_child(lan)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_local_characters = CONTENT_REGISTRY.load_characters()
	_local_minigames = CONTENT_REGISTRY.load_minigames()
	_build_interface()
	_connect_network()
	_load_name()
	if bool(ProjectSettings.get_setting("oneproyect/reopen_room", false)):
		ProjectSettings.set_setting("oneproyect/reopen_room", false)
		call_deferred("_reopen_room_setup")
		return
	if network.is_in_waiting_room():
		if not network.replay_waiting_room():
			_show_screen(_waiting_screen)
			_waiting_detail.text = "Recuperando estado de la sala…"
	elif network.is_in_lobby():
		_show_screen(_lobby_screen)
		_on_lobby_ready(NET.MAX_ROOMS, NET.MAX_PLAYERS_PER_ROOM)
	else:
		_show_screen(_main_screen)


func _reopen_room_setup() -> void:
	var local_only: bool = ProjectSettings.get_setting("oneproyect/session_mode", "local") == "local"
	if not local_only and lan.is_active():
		_enter_lan_room(false, lan.is_host)
	else:
		_enter_lan_room(true)


func _build_interface() -> void:
	theme = ISLAND_THEME.create()
	var background := ISLAND_ART.new()
	background.name = "Background"
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.configure(ISLAND_ART.Kind.BACKDROP)
	add_child(background)
	var panel := MarginContainer.new()
	panel.name = "SafeArea"
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.add_theme_constant_override("margin_left", 26)
	panel.add_theme_constant_override("margin_top", 22)
	panel.add_theme_constant_override("margin_right", 26)
	panel.add_theme_constant_override("margin_bottom", 22)
	add_child(panel)
	var screens := Control.new()
	screens.name = "Screens"
	panel.add_child(screens)
	_main_screen = _build_main_screen(screens)
	_lobby_screen = _build_lobby_screen(screens)
	_waiting_screen = _build_waiting_screen(screens)
	_lan_screen = _build_lan_screen(screens)
	_lan_room_screen = _build_lan_room_screen(screens)


func _build_main_screen(parent: Control) -> VBoxContainer:
	var screen := _new_screen("Main")
	parent.add_child(screen)
	screen.add_child(_build_brand_header("ONE PROYECT", "ISLA DE MINIJUEGOS"))
	var content := HBoxContainer.new()
	content.name = "MainContent"
	content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 18)
	var hero := _panel("MainHero", Color(0.012, 0.07, 0.12, 0.92), ISLAND_THEME.CYAN)
	hero.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hero.size_flags_stretch_ratio = 1.35
	var hero_row := HBoxContainer.new()
	hero_row.add_theme_constant_override("separation", 18)
	hero.add_child(hero_row)
	var logo := ISLAND_ART.new()
	logo.custom_minimum_size = Vector2(210.0, 210.0)
	logo.configure(ISLAND_ART.Kind.LOGO)
	hero_row.add_child(logo)
	var hero_copy := VBoxContainer.new()
	hero_copy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hero_copy.alignment = BoxContainer.ALIGNMENT_CENTER
	var hero_title := _title("LA ISLA TE ESPERA", 34, ISLAND_THEME.WHITE)
	hero_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	hero_copy.add_child(hero_title)
	var subtitle := _label("Física, caos y partidas cortas con amigos.", 18)
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	subtitle.modulate = ISLAND_THEME.MUTED
	hero_copy.add_child(subtitle)
	_profile_summary = _label("PERFIL MULTIJUGADOR", 15)
	_profile_summary.name = "ProfileSummary"
	_profile_summary.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_profile_summary.modulate = Color(0.42, 0.95, 0.7)
	hero_copy.add_child(_profile_summary)
	hero_row.add_child(hero_copy)
	content.add_child(hero)
	var access := _panel("AccessPanel", Color(0.015, 0.075, 0.125, 0.96), Color(0.12, 0.48, 0.64, 0.9))
	access.custom_minimum_size.x = 390.0
	var access_rows := VBoxContainer.new()
	access_rows.add_theme_constant_override("separation", 10)
	access.add_child(access_rows)
	var name_label := _label("TU NOMBRE", 15)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	name_label.modulate = ISLAND_THEME.ORANGE
	access_rows.add_child(name_label)
	_name_input = LineEdit.new()
	_name_input.name = "PlayerName"
	_name_input.theme_type_variation = &"IslandInput"
	_name_input.custom_minimum_size = Vector2(0.0, 54.0)
	_name_input.max_length = 16
	_name_input.placeholder_text = "Jugador"
	_name_input.add_theme_font_size_override("font_size", 18)
	access_rows.add_child(_name_input)
	var local_button := _button("▶  JUGAR LOCAL", "PlayLocal", &"IslandPrimaryButton")
	local_button.pressed.connect(_open_local_room)
	access_rows.add_child(local_button)
	var lan_button := _button("⌁  JUGAR EN LAN", "PlayLan", &"IslandGreenButton")
	lan_button.pressed.connect(_open_lan)
	access_rows.add_child(lan_button)
	var multiplayer_button := _button("★  MULTIJUGADOR", "Multiplayer", &"IslandOrangeButton")
	multiplayer_button.pressed.connect(_open_multiplayer)
	access_rows.add_child(multiplayer_button)
	var hint := _label(
		"LOCAL SIN RED · LAN EN EL MISMO WI-FI · INTERNET",
		12
	)
	hint.modulate = ISLAND_THEME.MUTED
	access_rows.add_child(hint)
	content.add_child(access)
	screen.add_child(content)
	return screen


func _build_lan_screen(parent: Control) -> VBoxContainer:
	var screen := _new_screen("Lan")
	parent.add_child(screen)
	screen.add_child(_build_brand_header("SALA LAN", "MISMO WI-FI · SIN VPS"))
	_lan_status = _label(
		"CREA UNA ISLA O ENCUENTRA LA DE TUS AMIGOS",
		15
	)
	_lan_status.modulate = ISLAND_THEME.MUTED
	screen.add_child(_lan_status)
	var cards := HBoxContainer.new()
	cards.size_flags_vertical = Control.SIZE_EXPAND_FILL
	cards.add_theme_constant_override("separation", 18)
	var host_card := _panel("LanHostCard", Color(0.015, 0.08, 0.13, 0.96), ISLAND_THEME.GREEN)
	host_card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var host_rows := VBoxContainer.new()
	host_rows.alignment = BoxContainer.ALIGNMENT_CENTER
	host_rows.add_theme_constant_override("separation", 12)
	host_card.add_child(host_rows)
	host_rows.add_child(_title("CREAR SALA", 28, ISLAND_THEME.GREEN))
	host_rows.add_child(_label("Tu POCO será el anfitrión de la partida local.", 16))
	_lan_start_button = _button("CREAR SALA LAN", "LanCreateRoom", &"IslandGreenButton")
	_lan_start_button.pressed.connect(_create_lan_room)
	host_rows.add_child(_lan_start_button)
	cards.add_child(host_card)
	var join_card := _panel("LanJoinCard", Color(0.015, 0.08, 0.13, 0.96), ISLAND_THEME.CYAN)
	join_card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var join_rows := VBoxContainer.new()
	join_rows.alignment = BoxContainer.ALIGNMENT_CENTER
	join_rows.add_theme_constant_override("separation", 12)
	join_card.add_child(join_rows)
	join_rows.add_child(_title("UNIRSE", 28, ISLAND_THEME.CYAN_BRIGHT))
	_lan_address_input = LineEdit.new()
	_lan_address_input.name = "LanHostAddress"
	_lan_address_input.theme_type_variation = &"IslandInput"
	_lan_address_input.placeholder_text = "IP del anfitrión (ej. 192.168.1.25)"
	_lan_address_input.custom_minimum_size = Vector2(0.0, 56.0)
	_lan_address_input.add_theme_font_size_override("font_size", 18)
	join_rows.add_child(_lan_address_input)
	var join := _button("BUSCAR / UNIRSE", "LanJoinRoom", &"IslandPrimaryButton")
	join.pressed.connect(_join_lan_room)
	join_rows.add_child(join)
	cards.add_child(join_card)
	screen.add_child(cards)
	var back := _button("←  VOLVER", "LanBack", &"IslandBackButton")
	back.custom_minimum_size.x = 240.0
	back.pressed.connect(_leave_lan_to_main)
	screen.add_child(back)
	return screen


func _build_lan_room_screen(parent: Control) -> VBoxContainer:
	var screen := _new_screen("LanRoom")
	screen.add_theme_constant_override("separation", 10)
	parent.add_child(screen)
	var header := _panel("RoomHeader", Color(0.015, 0.075, 0.125, 0.96), ISLAND_THEME.CYAN)
	header.custom_minimum_size.y = 76.0
	var header_row := HBoxContainer.new()
	header_row.add_theme_constant_override("separation", 14)
	header.add_child(header_row)
	var logo := ISLAND_ART.new()
	logo.custom_minimum_size = Vector2(58.0, 58.0)
	logo.configure(ISLAND_ART.Kind.LOGO)
	header_row.add_child(logo)
	_lan_room_title = _title("SALA ISLA", 29, ISLAND_THEME.WHITE)
	_lan_room_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_lan_room_title.autowrap_mode = TextServer.AUTOWRAP_OFF
	_lan_room_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header_row.add_child(_lan_room_title)
	_lan_host_badge = _label("★ ANFITRIÓN", 15)
	_lan_host_badge.autowrap_mode = TextServer.AUTOWRAP_OFF
	_lan_host_badge.custom_minimum_size.x = 190.0
	_lan_host_badge.add_theme_color_override("font_color", ISLAND_THEME.ORANGE)
	_lan_host_badge.add_theme_stylebox_override("normal", ISLAND_THEME.style(Color(1.0, 0.91, 0.88, 1.0), ISLAND_THEME.ORANGE, 2, 9, 8))
	header_row.add_child(_lan_host_badge)
	_lan_room_detail = _label("★  0 PTS", 18)
	_lan_room_detail.autowrap_mode = TextServer.AUTOWRAP_OFF
	_lan_room_detail.custom_minimum_size.x = 190.0
	_lan_room_detail.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_lan_room_detail.modulate = ISLAND_THEME.WHITE
	header_row.add_child(_lan_room_detail)
	_lan_room_capacity = _label("● 1/1", 17)
	_lan_room_capacity.autowrap_mode = TextServer.AUTOWRAP_OFF
	_lan_room_capacity.custom_minimum_size.x = 90.0
	_lan_room_capacity.add_theme_color_override("font_color", ISLAND_THEME.INK)
	_lan_room_capacity.add_theme_stylebox_override(
		"normal",
		ISLAND_THEME.style(Color(0.93, 0.95, 0.96), ISLAND_THEME.LINE, 2, 12, 7)
	)
	header_row.add_child(_lan_room_capacity)
	screen.add_child(header)
	var selection_panel := _panel("SelectionPanel", ISLAND_THEME.PAPER, ISLAND_THEME.ORANGE)
	selection_panel.custom_minimum_size.y = 190.0
	var selection := VBoxContainer.new()
	selection.add_theme_constant_override("separation", 5)
	selection_panel.add_child(selection)
	var mode_showcase := HBoxContainer.new()
	mode_showcase.size_flags_vertical = Control.SIZE_EXPAND_FILL
	mode_showcase.add_theme_constant_override("separation", 14)
	_lan_mode_art = ISLAND_ART.new()
	_lan_mode_art.custom_minimum_size = Vector2(170.0, 142.0)
	_lan_mode_art.configure(ISLAND_ART.Kind.MINIGAME, ISLAND_THEME.CYAN, &"futbol_rebote")
	mode_showcase.add_child(_lan_mode_art)
	var mode_copy := VBoxContainer.new()
	mode_copy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mode_copy.alignment = BoxContainer.ALIGNMENT_CENTER
	_lan_mode_title = _title("MINIJUEGO", 30, ISLAND_THEME.INK)
	_lan_mode_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	mode_copy.add_child(_lan_mode_title)
	var divider := HSeparator.new()
	divider.modulate = ISLAND_THEME.ORANGE
	mode_copy.add_child(divider)
	_lan_mode_description = _label("Selecciona una partida.", 15)
	_lan_mode_description.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_lan_mode_description.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_lan_mode_description.modulate = ISLAND_THEME.MUTED
	mode_copy.add_child(_lan_mode_description)
	mode_showcase.add_child(mode_copy)
	var selectors := VBoxContainer.new()
	selectors.custom_minimum_size.x = 310.0
	selectors.alignment = BoxContainer.ALIGNMENT_CENTER
	selectors.add_theme_constant_override("separation", 7)
	_lan_room_mode = OptionButton.new()
	_lan_room_mode.name = "SelectedMinigame"
	_lan_room_mode.theme_type_variation = &"IslandSelector"
	_lan_room_mode.custom_minimum_size = Vector2(0.0, 52.0)
	_lan_room_mode.add_theme_font_size_override("font_size", 15)
	for index in _local_minigames.size():
		_lan_room_mode.add_item("MINIJUEGO: %s" % _local_minigames[index].display_name, index)
	_lan_room_mode.item_selected.connect(_on_lan_mode_selected)
	selectors.add_child(_lan_room_mode)
	_lan_room_character = OptionButton.new()
	_lan_room_character.name = "SelectedCharacter"
	_lan_room_character.theme_type_variation = &"IslandSelector"
	_lan_room_character.custom_minimum_size = Vector2(0.0, 52.0)
	_lan_room_character.add_theme_font_size_override("font_size", 15)
	for index in _local_characters.size():
		_lan_room_character.add_item("TU PERSONAJE: %s" % _local_characters[index].display_name, index)
	_lan_room_character.item_selected.connect(_on_lan_character_selected)
	selectors.add_child(_lan_room_character)
	mode_showcase.add_child(selectors)
	selection.add_child(mode_showcase)
	screen.add_child(selection_panel)
	var roster_panel := _panel("RosterPanel", ISLAND_THEME.PAPER, Color(0.82, 0.85, 0.88))
	roster_panel.custom_minimum_size.y = 105.0
	var roster_layout := VBoxContainer.new()
	roster_layout.add_theme_constant_override("separation", 4)
	roster_panel.add_child(roster_layout)
	var roster_title := _title("JUGADORES DE LA SALA", 14, ISLAND_THEME.INK)
	roster_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	roster_layout.add_child(roster_title)
	var roster_scroll := ScrollContainer.new()
	roster_scroll.name = "PlayerRosterScroll"
	roster_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	roster_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	roster_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	roster_layout.add_child(roster_scroll)
	_lan_room_roster = HBoxContainer.new()
	_lan_room_roster.name = "PlayerRoster"
	_lan_room_roster.add_theme_constant_override("separation", 8)
	roster_scroll.add_child(_lan_room_roster)
	screen.add_child(roster_panel)
	var room_spacer := Control.new()
	room_spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	screen.add_child(room_spacer)
	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 12)
	var leave := _button("←  VOLVER", "LanLeave", &"IslandBackButton")
	leave.custom_minimum_size.x = 200.0
	leave.pressed.connect(_leave_lan_to_main)
	actions.add_child(leave)
	var chat := _button("☷  CHAT", "LanChat", &"IslandGhostButton")
	chat.custom_minimum_size.x = 150.0
	chat.disabled = true
	chat.tooltip_text = "El panel quedará listo para el chat de salas remotas."
	actions.add_child(chat)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	actions.add_child(spacer)
	_lan_room_ready = _button("✓  LISTO", "LanReady", &"IslandPrimaryButton")
	_lan_room_ready.custom_minimum_size.x = 330.0
	_lan_room_ready.custom_minimum_size.y = 66.0
	_lan_room_ready.add_theme_font_size_override("font_size", 27)
	_lan_room_ready.pressed.connect(_toggle_lan_ready)
	actions.add_child(_lan_room_ready)
	_lan_room_start = _button("INICIAR", "LanStart", &"IslandGreenButton")
	_lan_room_start.custom_minimum_size.x = 190.0
	_lan_room_start.custom_minimum_size.y = 66.0
	_lan_room_start.disabled = true
	_lan_room_start.pressed.connect(_start_lan_room)
	actions.add_child(_lan_room_start)
	screen.add_child(actions)
	return screen


func _build_lobby_screen(parent: Control) -> VBoxContainer:
	var screen := _new_screen("Lobby")
	parent.add_child(screen)
	screen.add_child(_build_brand_header("MULTIJUGADOR", "HASTA 5 SALAS"))
	_lobby_status = _label("Conectando al servidor…", 17)
	_lobby_status.add_theme_color_override("font_color", ISLAND_THEME.ORANGE)
	screen.add_child(_lobby_status)
	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 10)
	_create_button = _button("＋  CREAR SALA", "CreateRoom", &"IslandPrimaryButton")
	_create_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_create_button.disabled = true
	_create_button.pressed.connect(_create_room)
	actions.add_child(_create_button)
	_refresh_button = _button("↻  ACTUALIZAR", "RefreshRooms", &"IslandButton")
	_refresh_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_refresh_button.disabled = true
	_refresh_button.pressed.connect(network.request_room_list)
	actions.add_child(_refresh_button)
	screen.add_child(actions)
	var room_list := _panel("RoomList", Color(0.01, 0.055, 0.095, 0.9), Color(0.1, 0.42, 0.58, 0.7))
	room_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var room_rows := VBoxContainer.new()
	room_rows.add_theme_constant_override("separation", 7)
	room_list.add_child(room_rows)
	_empty_rooms = _label("NO HAY SALAS · CREA LA PRIMERA ISLA", 18)
	_empty_rooms.custom_minimum_size.y = 42.0
	room_rows.add_child(_empty_rooms)
	for index in NET.MAX_ROOMS:
		var room_button := _button("SALA %d" % (index + 1), "Room%d" % (index + 1), &"IslandButton")
		room_button.visible = false
		room_button.pressed.connect(_join_room.bind(index))
		_room_buttons.append(room_button)
		room_rows.add_child(room_button)
	screen.add_child(room_list)
	var back := _button("←  VOLVER", "Back", &"IslandBackButton")
	back.custom_minimum_size.x = 220.0
	back.pressed.connect(_leave_multiplayer)
	screen.add_child(back)
	return screen


func _build_waiting_screen(parent: Control) -> VBoxContainer:
	var screen := _new_screen("WaitingRoom")
	screen.add_theme_constant_override("separation", 9)
	parent.add_child(screen)
	var header := _build_brand_header("SALA ISLA", "MULTIJUGADOR")
	screen.add_child(header)
	_waiting_title = _title("SALA", 22, ISLAND_THEME.ORANGE)
	_waiting_title.name = "WaitingTitle"
	screen.add_child(_waiting_title)
	var selection_panel := _panel("OnlineSelectionPanel", ISLAND_THEME.PAPER, ISLAND_THEME.ORANGE)
	selection_panel.custom_minimum_size.y = 142.0
	var selection_row := HBoxContainer.new()
	selection_row.add_theme_constant_override("separation", 14)
	selection_panel.add_child(selection_row)
	_online_mode_art = ISLAND_ART.new()
	_online_mode_art.custom_minimum_size = Vector2(142.0, 112.0)
	_online_mode_art.configure(ISLAND_ART.Kind.MINIGAME, ISLAND_THEME.ORANGE, &"meteors")
	selection_row.add_child(_online_mode_art)
	var mode_copy := VBoxContainer.new()
	mode_copy.alignment = BoxContainer.ALIGNMENT_CENTER
	mode_copy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_online_mode_title = _title("METEORITOS", 28, ISLAND_THEME.INK)
	_online_mode_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	mode_copy.add_child(_online_mode_title)
	var mode_hint := _label("El anfitrión elige un único minijuego para esta partida.", 13)
	mode_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	mode_hint.modulate = ISLAND_THEME.MUTED
	mode_copy.add_child(mode_hint)
	_online_mode_button = OptionButton.new()
	_online_mode_button.name = "OnlineMinigame"
	_online_mode_button.theme_type_variation = &"IslandSelector"
	_online_mode_button.custom_minimum_size = Vector2(0.0, 46.0)
	_online_mode_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_online_mode_button.add_theme_font_size_override("font_size", 15)
	for mode_id in NET.ModeId.size():
		_online_mode_button.add_item("CAMBIAR: %s" % NET.mode_display_name(mode_id), mode_id)
	_online_mode_button.item_selected.connect(_on_online_mode_selected)
	mode_copy.add_child(_online_mode_button)
	selection_row.add_child(mode_copy)
	var character_box := VBoxContainer.new()
	character_box.custom_minimum_size.x = 330.0
	character_box.alignment = BoxContainer.ALIGNMENT_CENTER
	var character_title := _title("TU PERSONAJE", 14, ISLAND_THEME.CYAN)
	character_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	character_box.add_child(character_title)
	_character_button = OptionButton.new()
	_character_button.name = "RoomCharacter"
	_character_button.theme_type_variation = &"IslandSelector"
	_character_button.custom_minimum_size = Vector2(0.0, 52.0)
	_character_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_character_button.add_theme_font_size_override("font_size", 16)
	_character_button.add_item("PERSONAJE: %s" % CHARACTER_CATALOG.NAMES[0], 0)
	_character_button.item_selected.connect(_on_character_selected)
	character_box.add_child(_character_button)
	var rule := _label("EL PERSONAJE SE BLOQUEA AL MARCAR LISTO", 12)
	rule.modulate = ISLAND_THEME.MUTED
	character_box.add_child(rule)
	selection_row.add_child(character_box)
	screen.add_child(selection_panel)
	var roster_panel := _panel("OnlineRosterPanel", ISLAND_THEME.PAPER, Color(0.82, 0.85, 0.88))
	roster_panel.custom_minimum_size.y = 112.0
	var roster_rows := VBoxContainer.new()
	roster_rows.add_theme_constant_override("separation", 4)
	roster_panel.add_child(roster_rows)
	_waiting_detail = _label("Esperando jugadores…", 14)
	_waiting_detail.name = "WaitingPlayers"
	_waiting_detail.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_waiting_detail.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_waiting_detail.add_theme_color_override("font_color", ISLAND_THEME.INK)
	roster_rows.add_child(_waiting_detail)
	var waiting_scroll := ScrollContainer.new()
	waiting_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	waiting_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	waiting_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	roster_rows.add_child(waiting_scroll)
	_waiting_roster = HBoxContainer.new()
	_waiting_roster.name = "OnlinePlayerRoster"
	_waiting_roster.add_theme_constant_override("separation", 8)
	waiting_scroll.add_child(_waiting_roster)
	screen.add_child(roster_panel)
	var waiting_spacer := Control.new()
	waiting_spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	screen.add_child(waiting_spacer)
	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 10)
	var leave := _button("←  SALIR", "LeaveRoom", &"IslandBackButton")
	leave.custom_minimum_size.x = 190.0
	leave.pressed.connect(network.leave_room)
	actions.add_child(leave)
	_ready_button = _button("✓  LISTO", "ReadyRoom", &"IslandPrimaryButton")
	_ready_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_ready_button.pressed.connect(_toggle_ready)
	actions.add_child(_ready_button)
	_start_button = _button("INICIAR PARTIDA", "StartRoom", &"IslandGreenButton")
	_start_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_start_button.visible = false
	_start_button.disabled = true
	_start_button.pressed.connect(network.start_room)
	actions.add_child(_start_button)
	screen.add_child(actions)
	return screen


func _connect_network() -> void:
	network.status_changed.connect(_on_network_status)
	network.lobby_ready.connect(_on_lobby_ready)
	network.room_list_updated.connect(_on_room_list)
	network.room_waiting_updated.connect(_on_room_waiting)
	network.room_started.connect(_on_room_started)
	network.room_action_failed.connect(_on_room_error)
	network.returned_to_lobby.connect(_on_returned_to_lobby)
	lan.status_changed.connect(_on_lan_status_changed)
	lan.lobby_changed.connect(_on_lan_lobby_changed)
	lan.game_started.connect(_on_lan_game_started)


func _open_local_room() -> void:
	_save_name()
	lan.leave_room()
	lan.reset_local_session_points()
	network.disconnect_session()
	_enter_lan_room(true)


func _open_lan() -> void:
	_save_name()
	lan.leave_room()
	network.disconnect_session()
	_lan_status.text = "Crea una sala o únete a una sala de tu Wi-Fi."
	_lan_address_input.text = ""
	_show_screen(_lan_screen)


func _create_lan_room() -> void:
	var error: Error = lan.host_room(network.display_name, _selected_local_character_path())
	if error == OK:
		if not _local_minigames.is_empty():
			lan.set_minigame(_local_minigames[_lan_room_mode.selected].resource_path)
		_enter_lan_room(false, true)


func _join_lan_room() -> void:
	var address := _lan_address_input.text.strip_edges()
	if address.is_empty():
		address = lan.get_discovered_address()
	if address.is_empty():
		lan.begin_discovery()
		_lan_status.text = "Buscando… pulsa otra vez cuando aparezca una sala, o escribe su IP."
		return
	_lan_address_input.text = address
	lan.join_room(address, network.display_name, _selected_local_character_path())


func _enter_lan_room(local_only: bool, host := true) -> void:
	_lan_room_is_local = local_only
	_lan_room_is_host = host
	_lan_room_ready_state = false if local_only else bool(lan.players.get(lan.get_local_peer_id(), {}).get("ready", false))
	_lan_room_title.text = "SALA ISLA · LOCAL" if local_only else "SALA ISLA · LAN"
	_lan_host_badge.text = "★ SOLO" if local_only else "★ ANFITRIÓN: %s" % network.display_name if host else "INVITADO"
	_lan_host_badge.modulate = Color.WHITE if local_only or host else ISLAND_THEME.MUTED
	_lan_room_detail.text = "★  %d PTS" % lan.local_session_points if local_only else "CONECTANDO…"
	_lan_room_capacity.text = "● 1/1" if local_only else "● %d/%d" % [lan.players.size(), NET.MAX_PLAYERS_PER_ROOM]
	_lan_room_character.select(CHARACTER_CATALOG.sanitize_index(network.color_index))
	_lan_room_character.disabled = false
	_lan_room_mode.disabled = not local_only and not host
	_lan_room_ready.text = "✓  LISTO"
	_lan_room_start.visible = local_only or host
	_lan_room_start.disabled = true
	_show_screen(_lan_room_screen)
	_update_selected_minigame_showcase()
	_refresh_local_room_roster()
	if not local_only:
		_refresh_lan_room()


func _toggle_lan_ready() -> void:
	_lan_room_ready_state = not _lan_room_ready_state
	_lan_room_character.disabled = _lan_room_ready_state
	_lan_room_mode.disabled = _lan_room_ready_state or (not _lan_room_is_local and not _lan_room_is_host)
	_lan_room_ready.text = "×  CANCELAR" if _lan_room_ready_state else "✓  LISTO"
	if _lan_room_is_local:
		_lan_room_start.disabled = not _lan_room_ready_state
		_refresh_local_room_roster()
	else:
		lan.set_ready(_lan_room_ready_state)


func _on_lan_character_selected(index: int) -> void:
	if index < 0 or index >= _local_characters.size():
		return
	ProjectSettings.set_setting(
		"oneproyect/session_character_path",
		_local_characters[index].resource_path
	)
	network.color_index = 0
	_save_character()
	if _lan_room_is_local:
		_refresh_local_room_roster()
	if not _lan_room_is_local and lan.is_active():
		lan.set_character(_local_characters[index].resource_path)


func _on_lan_mode_selected(index: int) -> void:
	_update_selected_minigame_showcase()
	if _lan_room_is_local or not _lan_room_is_host or index < 0 or index >= _local_minigames.size():
		return
	lan.set_minigame(_local_minigames[index].resource_path)


func _start_lan_room() -> void:
	if not _lan_room_ready_state:
		return
	if not _lan_room_is_local:
		lan.start_game()
		return
	_start_selected_local_game()


func _start_selected_local_game() -> void:
	ProjectSettings.set_setting("oneproyect/session_auto_start", true)
	ProjectSettings.set_setting(
		"oneproyect/session_mode",
		"local" if _lan_room_is_local else "lan"
	)
	var selected_mode := _lan_room_mode.selected
	if selected_mode >= 0 and selected_mode < _local_minigames.size():
		ProjectSettings.set_setting(
			"oneproyect/session_minigame_path",
			_local_minigames[selected_mode].resource_path
		)
	_loading_game = true
	_show_loading(
		LOCAL_LAB_SCENE,
		"PREPARANDO PARTIDA LOCAL" if _lan_room_is_local else "PREPARANDO SALA LAN"
	)


func _on_lan_status_changed(text: String) -> void:
	_lan_status.text = text
	var discovered: String = lan.get_discovered_address()
	if not discovered.is_empty() and _lan_address_input.text.is_empty():
		_lan_address_input.text = discovered


func _on_lan_lobby_changed() -> void:
	if not lan.is_active():
		return
	var local_id: int = lan.get_local_peer_id()
	if lan.players.has(local_id) and not _lan_room_screen.visible:
		_enter_lan_room(false, lan.is_host)
	_refresh_lan_room()


func _refresh_lan_room() -> void:
	if _lan_room_is_local or not lan.is_active():
		return
	var ids := PackedInt32Array(lan.players.keys())
	ids.sort()
	var ready_count := 0
	_clear_roster()
	for peer_id in ids:
		var profile: Dictionary = lan.players[peer_id]
		var ready := bool(profile.get("ready", false))
		ready_count += 1 if ready else 0
		_lan_room_roster.add_child(_build_room_player_card(
			str(profile.get("name", "Jugador")),
			_character_name_for_path(str(profile.get("character", ""))),
			int(profile.get("points", 0)),
			ready,
			lan.get_peer_slot(peer_id),
			peer_id == lan.get_local_peer_id()
		))
	var local_points := int(lan.players.get(lan.get_local_peer_id(), {}).get("points", 0))
	_lan_room_detail.text = "★  %d PTS" % local_points
	_lan_room_capacity.text = "● %d/%d" % [ids.size(), NET.MAX_PLAYERS_PER_ROOM]
	var local_profile: Dictionary = lan.players.get(lan.get_local_peer_id(), {})
	_lan_room_ready_state = bool(local_profile.get("ready", false))
	_lan_room_ready.text = "×  CANCELAR" if _lan_room_ready_state else "✓  LISTO"
	_lan_room_character.disabled = _lan_room_ready_state
	_lan_room_mode.disabled = not _lan_room_is_host or _lan_room_ready_state
	_lan_room_start.disabled = not lan.can_start()
	if not lan.selected_minigame_path.is_empty():
		for index in _local_minigames.size():
			if _local_minigames[index].resource_path == lan.selected_minigame_path:
				_lan_room_mode.select(index)
				_update_selected_minigame_showcase()
				break


func _refresh_local_room_roster() -> void:
	if not _lan_room_is_local or _lan_room_roster == null:
		return
	_clear_roster()
	_lan_room_roster.add_child(_build_room_player_card(
		network.display_name,
		_character_name_for_path(_selected_local_character_path()),
		lan.local_session_points,
		_lan_room_ready_state,
		0,
		true
	))
	_lan_room_detail.text = "★  %d PTS" % lan.local_session_points
	_lan_room_capacity.text = "● 1/1"


func _update_selected_minigame_showcase() -> void:
	if _lan_room_mode == null or _local_minigames.is_empty():
		return
	var index := clampi(_lan_room_mode.selected, 0, _local_minigames.size() - 1)
	var definition = _local_minigames[index]
	_lan_mode_title.text = str(definition.display_name)
	_lan_mode_description.text = str(definition.description)
	_lan_mode_art.minigame_id = definition.minigame_id
	_lan_mode_art.queue_redraw()


func _clear_roster() -> void:
	_clear_container(_lan_room_roster)


func _clear_container(container: Control) -> void:
	if container == null:
		return
	for child in container.get_children():
		child.queue_free()


func _build_room_player_card(
	player_name: String,
	character_name: String,
	points: int,
	ready: bool,
	slot: int,
	is_local: bool,
	profile_note := ""
) -> PanelContainer:
	var accent := _slot_color(slot)
	var panel := _panel(
		"PlayerCard%d" % slot,
		ISLAND_THEME.PAPER,
		accent if is_local else Color(0.78, 0.81, 0.85, 1.0)
	)
	panel.add_theme_stylebox_override(
		"panel",
		ISLAND_THEME.style(
			ISLAND_THEME.PAPER,
			accent if is_local else Color(0.78, 0.81, 0.85, 1.0),
			2,
			16,
			7
		)
	)
	panel.custom_minimum_size = Vector2(228.0, 88.0)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 7)
	panel.add_child(row)
	var avatar := ISLAND_ART.new()
	avatar.custom_minimum_size = Vector2(62.0, 66.0)
	avatar.configure(ISLAND_ART.Kind.PLAYER, accent)
	row.add_child(avatar)
	var identity := VBoxContainer.new()
	identity.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	identity.add_theme_constant_override("separation", 1)
	var slot_label := _label(
		"JUGADOR %d%s" % [slot + 1, " · ANFITRIÓN" if is_local else ""],
		10
	)
	slot_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	slot_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	slot_label.clip_text = true
	slot_label.add_theme_color_override("font_color", accent.darkened(0.14))
	identity.add_child(slot_label)
	var name_label := _label(player_name.to_upper(), 16)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	name_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	name_label.clip_text = true
	name_label.add_theme_color_override("font_color", ISLAND_THEME.INK)
	identity.add_child(name_label)
	var character_text := character_name.to_upper()
	if not profile_note.is_empty():
		character_text += " · " + profile_note
	var character_label := _label(character_text, 9)
	character_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	character_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	character_label.clip_text = true
	character_label.add_theme_color_override("font_color", accent)
	identity.add_child(character_label)
	var stats := HBoxContainer.new()
	stats.add_theme_constant_override("separation", 4)
	var points_label := _label("★ %d" % maxi(0, points), 12)
	points_label.custom_minimum_size.x = 52.0
	points_label.add_theme_color_override("font_color", accent.darkened(0.18))
	points_label.add_theme_stylebox_override("normal", ISLAND_THEME.style(Color(accent.r, accent.g, accent.b, 0.12), Color(accent.r, accent.g, accent.b, 0.28), 1, 10, 5))
	stats.add_child(points_label)
	var state := _label("✓ LISTO" if ready else "ESPERA", 10)
	state.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	state.add_theme_color_override("font_color", Color.WHITE if ready else ISLAND_THEME.ORANGE)
	state.add_theme_stylebox_override("normal", ISLAND_THEME.style(ISLAND_THEME.GREEN if ready else Color(1.0, 0.93, 0.9, 1.0), ISLAND_THEME.GREEN if ready else ISLAND_THEME.ORANGE, 1, 10, 5))
	stats.add_child(state)
	identity.add_child(stats)
	row.add_child(identity)
	return panel


func _character_name_for_path(character_path: String) -> String:
	for definition in _local_characters:
		if definition.resource_path == character_path:
			return str(definition.display_name)
	return str(_local_characters[0].display_name) if not _local_characters.is_empty() else "BASE"


func _slot_color(slot: int) -> Color:
	var colors := [
		Color(0.18, 0.78, 1.0), Color(0.66, 0.4, 1.0), Color(1.0, 0.72, 0.18),
		Color(0.35, 0.94, 0.5), Color(1.0, 0.38, 0.66),
	]
	return colors[posmod(slot, colors.size())]


func _on_lan_game_started(minigame_path: String, round_seed: int) -> void:
	ProjectSettings.set_setting("oneproyect/session_auto_start", true)
	ProjectSettings.set_setting("oneproyect/session_mode", "lan")
	ProjectSettings.set_setting("oneproyect/session_minigame_path", minigame_path)
	ProjectSettings.set_setting("oneproyect/session_round_seed", round_seed)
	ProjectSettings.set_setting("oneproyect/session_character_path", _selected_local_character_path())
	_loading_game = true
	_show_loading(LOCAL_LAB_SCENE, "ENTRANDO A PARTIDA LAN")


func _selected_local_character_path() -> String:
	var index := _lan_room_character.selected if _lan_room_character != null else 0
	if index >= 0 and index < _local_characters.size():
		return _local_characters[index].resource_path
	return ""


func _leave_lan_to_main() -> void:
	lan.leave_room()
	_show_screen(_main_screen)


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
		button.text = "SALA %d  ·  %d/%d  ·  %s" % [
			room_ids[index],
			player_counts[index],
			NET.MAX_PLAYERS_PER_ROOM,
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
	session_scores: PackedInt32Array,
	selected_mode_id: int
) -> void:
	_show_screen(_waiting_screen)
	_is_host = is_host
	_local_ready = local_ready
	var local_score := 0
	var local_name_index := player_names.find(network.display_name)
	if local_name_index >= 0 and local_name_index < session_scores.size():
		local_score = session_scores[local_name_index]
	_waiting_title.text = "SALA %d · %s · %d/%d · ★ %d PTS" % [
		room_id,
		"ANFITRIÓN" if is_host else "INVITADO",
		player_count,
		NET.MAX_PLAYERS_PER_ROOM,
		local_score,
	]
	var visible_count := mini(player_names.size(), ready_flags.size())
	visible_count = mini(visible_count, character_indices.size())
	visible_count = mini(visible_count, victory_counts.size())
	visible_count = mini(visible_count, experience_values.size())
	visible_count = mini(visible_count, session_scores.size())
	_clear_container(_waiting_roster)
	for index in visible_count:
		var character_index := CHARACTER_CATALOG.sanitize_index(character_indices[index])
		_waiting_roster.add_child(_build_room_player_card(
			player_names[index],
			CHARACTER_CATALOG.NAMES[character_index],
			session_scores[index],
			ready_flags[index] != 0,
			index,
			player_names[index] == network.display_name,
			"%dV · %dXP" % [victory_counts[index], experience_values[index]]
		))
	_waiting_detail.text = "%d/%d JUGADORES · %d LISTOS · PUNTOS DE ESTA SALA" % [
		player_count,
		NET.MAX_PLAYERS_PER_ROOM,
		ready_count,
	]
	_character_button.disabled = local_ready
	_online_mode_button.select(clampi(selected_mode_id, 0, _online_mode_button.item_count - 1))
	_online_mode_title.text = NET.mode_display_name(selected_mode_id)
	_online_mode_art.minigame_id = StringName(NET.mode_name(selected_mode_id))
	_online_mode_art.queue_redraw()
	_online_mode_button.disabled = not is_host or local_ready
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
	_online_mode_button.disabled = true
	_ready_button.disabled = true
	_start_button.disabled = true
	_waiting_detail.text = "Iniciando partida…"
	_show_loading(GAME_SCENE, "SINCRONIZANDO MINIJUEGO")


func _show_loading(target_path: String, status: String) -> void:
	var loading := LOADING_SCENE.instantiate() as OneProjectLoadingScreen
	get_tree().root.add_child(loading)
	loading.begin(target_path, status)


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
	_lan_screen.visible = screen == _lan_screen
	_lan_room_screen.visible = screen == _lan_room_screen
	_lobby_screen.visible = screen == _lobby_screen
	_waiting_screen.visible = screen == _waiting_screen


func _load_name() -> void:
	var config := ConfigFile.new()
	if config.load(PROFILE_PATH) == OK:
		var saved := str(config.get_value("player", "name", "")).strip_edges().substr(0, 16)
		if not saved.is_empty():
			network.display_name = saved
		# Until there are distinct playable local models, expose one honest base body.
		network.color_index = 0
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
		"%d VICTORIAS · %d XP · %d PARTIDAS · %d/%d MINIJUEGOS SUPERADOS"
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


func _on_online_mode_selected(index: int) -> void:
	if not _is_host or _local_ready or _loading_game:
		return
	if network.is_online():
		network.set_room_mode(_online_mode_button.get_item_id(index))


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


func _panel(node_name: String, background: Color, border: Color) -> PanelContainer:
	var result := PanelContainer.new()
	result.name = node_name
	var surface := ISLAND_THEME.PAPER if background.get_luminance() < 0.45 else background
	result.add_theme_stylebox_override("panel", ISLAND_THEME.style(surface, border, 2, 18, 14))
	return result


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


func _button(
	text_value: String,
	node_name: String,
	variation: StringName = &""
) -> Button:
	var result := Button.new()
	result.name = node_name
	result.text = text_value
	result.custom_minimum_size = Vector2(0.0, 52.0)
	result.add_theme_font_size_override("font_size", 18)
	if variation.is_empty():
		if "Ready" in node_name:
			variation = &"IslandGreenButton"
		elif "Leave" in node_name or "Back" in node_name:
			variation = &"IslandBackButton"
		else:
			variation = &"IslandButton"
	result.theme_type_variation = variation
	return result


func _button_style(background: Color, border: Color, width: int) -> StyleBoxFlat:
	return ISLAND_THEME.style(background, border, width, 13, 12)


func _build_brand_header(title_text: String, badge_text: String) -> PanelContainer:
	var header := _panel("BrandHeader", ISLAND_THEME.PAPER, Color(0.86, 0.88, 0.9))
	header.custom_minimum_size.y = 78.0
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 15)
	header.add_child(row)
	var logo := ISLAND_ART.new()
	logo.custom_minimum_size = Vector2(58.0, 58.0)
	logo.configure(ISLAND_ART.Kind.LOGO)
	row.add_child(logo)
	var title_label := _title(title_text, 31, ISLAND_THEME.WHITE)
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	title_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(title_label)
	var badge := _label(badge_text, 14)
	badge.autowrap_mode = TextServer.AUTOWRAP_OFF
	badge.custom_minimum_size.x = 240.0
	badge.add_theme_color_override("font_color", ISLAND_THEME.ORANGE)
	badge.add_theme_stylebox_override("normal", ISLAND_THEME.style(Color(1.0, 0.91, 0.88, 1.0), ISLAND_THEME.ORANGE, 2, 12, 8))
	row.add_child(badge)
	return header


func _spacer(height: float) -> Control:
	var result := Control.new()
	result.custom_minimum_size.y = height
	return result
