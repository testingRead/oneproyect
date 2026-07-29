extends Node3D

const REMOTE_AVATAR_SCENE := preload("res://scenes/components/remote_avatar.tscn")
const SNAPSHOT_INTERVAL := 0.1
const PROFILE_PATH := "user://profile.cfg"

@onready var player: GrayboxPlayer = $World/Player
@onready var disaster: DisasterController = $World/DisasterController
@onready var remote_players: Node3D = $World/RemotePlayers
@onready var network: Variant = get_node("/root/Network")
@onready var sounds: SoundBank = $SoundBank
@onready var fps_label: Label = $HUD/TopBar/FPS
@onready var health_label: Label = $HUD/TopBar/Health
@onready var round_title: Label = $HUD/RoundPanel/Title
@onready var round_detail: Label = $HUD/RoundPanel/Detail
@onready var round_clock: Label = $HUD/RoundPanel/Clock
@onready var pause_panel: Control = $HUD/PausePanel
@onready var pause_button: Button = $HUD/TopBar/Pause
@onready var restart_button: Button = $HUD/TopBar/Restart
@onready var online_button: Button = $HUD/TopBar/Online
@onready var network_status: Label = $HUD/TopBar/NetworkStatus
@onready var name_input: LineEdit = $HUD/PausePanel/Center/NameInput
@onready var pause_title: Label = $HUD/PausePanel/Center/Title
@onready var pause_restart: Button = $HUD/PausePanel/Center/Restart
@onready var touch_debug: Label = $HUD/TouchDebug

var _stats_elapsed := 0.0
var _snapshot_elapsed := 0.0
var _remote_avatars: Dictionary = {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	$HUD/Joystick.value_changed.connect(_on_touch_move)
	$HUD/LookPad.look_delta.connect(player.add_touch_look)
	$HUD/Jump.action_pressed.connect(player.request_jump)
	$HUD/TopBar/Pause.pressed.connect(toggle_pause)
	$HUD/TopBar/Restart.pressed.connect(restart_level)
	online_button.pressed.connect(_toggle_online)
	$HUD/PausePanel/Center/Resume.pressed.connect(toggle_pause)
	$HUD/PausePanel/Center/Restart.pressed.connect(restart_level)
	player.health_changed.connect(_on_health_changed)
	player.defeated.connect(_on_player_defeated)
	disaster.state_changed.connect(_on_disaster_state_changed)
	disaster.clock_changed.connect(_on_disaster_clock_changed)
	disaster.round_survived.connect(_on_round_survived)
	disaster.meteor_warning.connect(sounds.play_warning)
	disaster.meteor_impact.connect(sounds.play_impact)
	disaster.shockwave_warning.connect(sounds.play_warning)
	disaster.shockwave_started.connect(sounds.play_shockwave)
	network.status_changed.connect(_on_network_status_changed)
	network.remote_player_joined.connect(_on_remote_player_joined)
	network.remote_player_left.connect(_on_remote_player_left)
	network.remote_snapshot.connect(_on_remote_snapshot)
	network.meteor_received.connect(disaster.spawn_network_meteor)
	network.shockwave_received.connect(disaster.spawn_network_shockwave)
	network.round_state_received.connect(disaster.apply_network_state)
	network.simulation_host_changed.connect(_on_simulation_host_changed)
	_load_profile()
	_on_health_changed(100, 100)
	_on_network_status_changed("MODO LOCAL", false)


func _process(delta: float) -> void:
	_stats_elapsed += delta
	if _stats_elapsed >= 0.25:
		var fps := Engine.get_frames_per_second()
		var frame_ms := 1000.0 / maxf(float(fps), 1.0)
		fps_label.text = "%d FPS  %.1f ms" % [fps, frame_ms]
		_stats_elapsed = 0.0
	if network.is_online():
		_snapshot_elapsed += delta
		if _snapshot_elapsed >= SNAPSHOT_INTERVAL:
			network.send_snapshot(player.global_position, player.get_visual_yaw())
			_snapshot_elapsed = 0.0


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		toggle_pause()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("restart"):
		restart_level()
		get_viewport().set_input_as_handled()


func toggle_pause() -> void:
	if network.is_online():
		var menu_open := not pause_panel.visible
		pause_panel.visible = menu_open
		pause_title.text = "MENÚ EN LÍNEA"
		pause_button.text = "CERRAR" if menu_open else "MENÚ"
		player.set_controls_enabled(not menu_open)
		if not OS.has_feature("mobile"):
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if menu_open else Input.MOUSE_MODE_CAPTURED
		return
	get_tree().paused = not get_tree().paused
	pause_panel.visible = get_tree().paused
	pause_title.text = "EN PAUSA"
	pause_button.text = "SEGUIR" if get_tree().paused else "PAUSA"
	if not OS.has_feature("mobile"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if get_tree().paused else Input.MOUSE_MODE_CAPTURED


func restart_level() -> void:
	get_tree().paused = false
	pause_panel.visible = false
	pause_button.text = "MENÚ" if network.is_online() else "PAUSA"
	pause_title.text = "EN PAUSA"
	$HUD/PausePanel/Center/Resume.visible = true
	player.set_controls_enabled(true)
	player.reset_to_spawn()
	if not network.is_online():
		disaster.restart_cycle()
	if not OS.has_feature("mobile"):
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _on_touch_move(value: Vector2) -> void:
	player.set_touch_move(value)
	touch_debug.text = "JOY  %.2f  %.2f" % [value.x, value.y]


func _on_health_changed(current: int, maximum: int) -> void:
	health_label.text = "VIDA  %d/%d" % [current, maximum]
	if current <= 35:
		health_label.modulate = Color(1.0, 0.4, 0.32)
	else:
		health_label.modulate = Color.WHITE


func _on_player_defeated() -> void:
	round_detail.text = "¡Te derribaron! Regresas a la plaza"
	player.reset_to_spawn()


func _on_disaster_state_changed(title: String, detail: String) -> void:
	round_title.text = title
	round_detail.text = detail


func _on_disaster_clock_changed(seconds_left: int) -> void:
	round_clock.text = "%02d" % seconds_left


func _on_round_survived(_round_number: int) -> void:
	sounds.play_success()
	player.heal_full()


func _toggle_online() -> void:
	if network.is_online():
		network.disconnect_session()
		_clear_remote_players()
		online_button.text = "CONECTAR"
		disaster.restart_cycle()
		return
	var requested_name := name_input.text.strip_edges().substr(0, 16)
	if not requested_name.is_empty():
		network.display_name = requested_name
	_save_profile()
	online_button.disabled = true
	var error: int = network.connect_to_server()
	if error != OK:
		online_button.disabled = false


func _on_network_status_changed(text: String, online: bool) -> void:
	network_status.text = text
	network_status.modulate = Color(0.4, 1.0, 0.62) if online else Color(0.76, 0.87, 1.0)
	online_button.disabled = text.begins_with("Conectando")
	online_button.text = "SALIR" if online else "CONECTAR"
	pause_button.text = "MENÚ" if online else "PAUSA"
	restart_button.text = "REAPARECER" if online else "REINICIAR"
	pause_restart.text = "REAPARECER" if online else "REINICIAR"
	name_input.editable = not online
	if not online and not network.is_online():
		if pause_panel.visible and not get_tree().paused:
			pause_panel.visible = false
			player.set_controls_enabled(true)
			if not OS.has_feature("mobile"):
				Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		_clear_remote_players()


func _on_remote_player_joined(peer_id: int, player_name: String, player_color: int) -> void:
	if _remote_avatars.has(peer_id):
		return
	var avatar: RemoteAvatar = REMOTE_AVATAR_SCENE.instantiate()
	avatar.name = "Peer%d" % peer_id
	remote_players.add_child(avatar)
	avatar.configure(player_name, player_color, Vector3(0.0, 1.2, 8.0))
	_remote_avatars[peer_id] = avatar


func _on_remote_player_left(peer_id: int) -> void:
	var avatar: RemoteAvatar = _remote_avatars.get(peer_id)
	if avatar != null:
		avatar.queue_free()
	_remote_avatars.erase(peer_id)


func _on_remote_snapshot(peer_id: int, position: Vector3, facing_yaw: float) -> void:
	var avatar: RemoteAvatar = _remote_avatars.get(peer_id)
	if avatar != null:
		avatar.set_snapshot(position, facing_yaw)


func _on_simulation_host_changed(peer_id: int) -> void:
	if peer_id == multiplayer.get_unique_id():
		disaster.sync_as_host()


func _clear_remote_players() -> void:
	for avatar: RemoteAvatar in _remote_avatars.values():
		avatar.queue_free()
	_remote_avatars.clear()


func _load_profile() -> void:
	var config := ConfigFile.new()
	if config.load(PROFILE_PATH) == OK:
		var saved_name := str(config.get_value("player", "name", "")).strip_edges().substr(0, 16)
		if not saved_name.is_empty():
			network.display_name = saved_name
	name_input.text = network.display_name


func _save_profile() -> void:
	var config := ConfigFile.new()
	config.set_value("player", "name", network.display_name)
	var error := config.save(PROFILE_PATH)
	if error != OK:
		push_warning("No se pudo guardar el nombre del jugador: %s" % error)
