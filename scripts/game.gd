extends Node3D

const REMOTE_AVATAR_SCENE := preload("res://scenes/components/remote_avatar.tscn")
const CHARACTER_CATALOG := preload("res://scripts/characters/character_catalog.gd")
const NET := preload("res://shared/net_constants.gd")
const MOVING_STATE_SEND_INTERVAL := 1.0 / float(NET.STATE_SEND_RATE)
const IDLE_STATE_SEND_INTERVAL := 1.0 / float(NET.IDLE_STATE_SEND_RATE)
const PROFILE_PATH := "user://profile.cfg"
const MENU_SCENE := "res://scenes/menu.tscn"
const PUSH_RANGE := 2.8
const PUSH_MIN_DOT := 0.62
const QUALITY_NAMES := ["BAJA", "MEDIA", "ALTA"]
const FPS_LIMITS := [30, 45, 60]

@onready var player: GrayboxPlayer = $World/Player
@onready var disaster: DisasterController = $World/DisasterController
@onready var remote_players: Node3D = $World/RemotePlayers
@onready var detached_parts: Node3D = $World/DetachedParts
@onready var mode_map_host: Node3D = $World/ModeMapHost
@onready var feature_host: Node = $ExperienceFeatureHost
@onready var network: Variant = get_node("/root/Network")
@onready var sounds: SoundBank = $SoundBank
@onready var sun: DirectionalLight3D = $World/Sun
@onready var world_environment: WorldEnvironment = $World/Environment
@onready var fps_label: Label = $HUD/TopBar/FPS
@onready var health_label: Label = $HUD/TopBar/Health
@onready var round_title: Label = $HUD/RoundPanel/Title
@onready var round_detail: Label = $HUD/RoundPanel/Detail
@onready var round_clock: Label = $HUD/RoundPanel/Clock
@onready var score_label: Label = $HUD/RoundPanel/Score
@onready var damage_flash: ColorRect = $HUD/DamageFlash
@onready var pause_panel: Control = $HUD/PausePanel
@onready var pause_button: Button = $HUD/TopBar/Pause
@onready var restart_button: Button = $HUD/TopBar/Restart
@onready var online_button: Button = $HUD/TopBar/Online
@onready var network_status: Label = $HUD/TopBar/NetworkStatus
@onready var name_input: LineEdit = $HUD/PausePanel/Center/NameInput
@onready var sound_toggle: CheckButton = $HUD/PausePanel/Center/SettingsRow/Sound
@onready var vibration_toggle: CheckButton = $HUD/PausePanel/Center/SettingsRow/Vibration
@onready var camera_button: Button = $HUD/PausePanel/Center/Camera
@onready var sensitivity_slider: HSlider = $HUD/PausePanel/Center/SensitivityRow/Slider
@onready var sensitivity_value: Label = $HUD/PausePanel/Center/SensitivityRow/Value
@onready var quality_button: OptionButton = $HUD/PausePanel/Center/Quality
@onready var fps_button: OptionButton = $HUD/PausePanel/Center/FPSLimit
@onready var character_button: OptionButton = $HUD/PausePanel/PreviewPanel/Character
@onready var preview_avatar: RemoteAvatar = $HUD/PausePanel/PreviewPanel/ViewportContainer/Viewport/Avatar
@onready var pause_title: Label = $HUD/PausePanel/Center/Title
@onready var pause_restart: Button = $HUD/PausePanel/Center/Restart
@onready var touch_debug: Label = $HUD/TouchDebug
@onready var match_result: ColorRect = $HUD/MatchResult
@onready var result_title: Label = $HUD/MatchResult/Content/Title
@onready var result_standings: Label = $HUD/MatchResult/Content/Standings
@onready var result_reward: Label = $HUD/MatchResult/Content/Reward
@onready var return_room_button: Button = $HUD/MatchResult/Content/Actions/ReturnRoom
@onready var exit_match_button: Button = $HUD/MatchResult/Content/Actions/Exit

var _stats_elapsed := 0.0
var _state_send_elapsed := 0.0
var _remote_avatars: Dictionary = {}
var _damage_flash_strength := 0.0
var _completed_rounds := 0
var _best_rounds := 0
var _vibration_enabled := true
var _first_person_enabled := false
var _quality_level := 0
var _fps_limit_index := 2
var _total_victories := 0
var _multiplayer_experience := 0
var _multiplayer_matches := 0
var _multiplayer_rounds := 0
var _multiplayer_survivals := 0
var _last_reward_match_id := 0
var _last_reward_round := 0
var _last_completed_match_id := 0
var _install_id := ""
var _defeated_this_round := false
var _participating_round := false
var _returning_to_menu := false
var _last_sent_health := -1
var _last_sent_limb_mask := -1
var _network_status_base := "MODO LOCAL"
var _match_total_rounds := NET.DEFAULT_MATCH_ROUNDS
var _match_finished := false
var _match_victory_awarded := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	$HUD/Joystick.value_changed.connect(_on_touch_move)
	$HUD/LookPad.look_delta.connect(player.add_touch_look)
	$HUD/Jump.action_pressed.connect(player.request_jump)
	$HUD/Push.action_pressed.connect(player.request_push)
	$HUD/TopBar/Pause.pressed.connect(toggle_pause)
	$HUD/TopBar/Restart.pressed.connect(restart_level)
	online_button.pressed.connect(_toggle_online)
	$HUD/PausePanel/Center/Resume.pressed.connect(toggle_pause)
	$HUD/PausePanel/Center/Restart.pressed.connect(restart_level)
	sound_toggle.toggled.connect(_on_sound_toggled)
	vibration_toggle.toggled.connect(_on_vibration_toggled)
	camera_button.pressed.connect(_toggle_camera_mode)
	sensitivity_slider.value_changed.connect(_on_sensitivity_changed)
	_populate_option_lists()
	character_button.item_selected.connect(_on_character_selected)
	quality_button.item_selected.connect(_on_quality_selected)
	fps_button.item_selected.connect(_on_fps_limit_selected)
	name_input.text_submitted.connect(_on_name_submitted)
	player.health_changed.connect(_on_health_changed)
	player.damaged.connect(_on_player_damaged)
	player.defeated.connect(_on_player_defeated)
	player.push_requested.connect(_on_push_requested)
	player.limb_detached.connect(detached_parts.spawn_part)
	disaster.state_changed.connect(_on_disaster_state_changed)
	disaster.clock_changed.connect(_on_disaster_clock_changed)
	disaster.round_survived.connect(_on_round_survived)
	disaster.round_started.connect(_on_round_started)
	disaster.meteor_warning.connect(sounds.play_warning)
	disaster.meteor_impact.connect(sounds.play_impact)
	disaster.shockwave_warning.connect(sounds.play_warning)
	disaster.shockwave_started.connect(sounds.play_shockwave)
	disaster.experience_selected.connect(_on_experience_selected)
	disaster.experience_ended.connect(feature_host.clear_experience)
	mode_map_host.map_activated.connect(_on_mode_map_activated)
	network.status_changed.connect(_on_network_status_changed)
	network.remote_player_joined.connect(_on_remote_player_joined)
	network.remote_player_left.connect(_on_remote_player_left)
	network.remote_snapshot.connect(_on_remote_snapshot)
	network.meteor_received.connect(disaster.spawn_network_meteor)
	network.shockwave_received.connect(disaster.spawn_network_shockwave)
	network.round_state_received.connect(disaster.apply_network_state)
	network.simulation_host_changed.connect(_on_simulation_host_changed)
	network.push_received.connect(_on_push_received)
	network.shot_received.connect(_on_shot_received)
	network.standings_received.connect(_on_standings_received)
	network.room_reopened.connect(_on_room_reopened)
	return_room_button.pressed.connect(_return_to_same_room)
	exit_match_button.pressed.connect(_exit_match_to_lobby)
	_load_profile()
	_on_health_changed(100, 100)
	if network.is_online():
		var spawn_position: Vector3 = network.get_local_spawn_position()
		player.global_position = spawn_position
		player.velocity = Vector3.ZERO
		network.replay_remote_players()
		_on_network_status_changed(
			"EN LÍNEA · SALA %d" % network.get_room_id(),
			true
		)
	else:
		_on_network_status_changed("MODO LOCAL", false)


func _process(delta: float) -> void:
	_stats_elapsed += delta
	if _stats_elapsed >= 0.25:
		var fps := Engine.get_frames_per_second()
		var frame_ms := 1000.0 / maxf(float(fps), 1.0)
		fps_label.text = "%d FPS  %.1f ms" % [fps, frame_ms]
		_update_network_metrics()
		_stats_elapsed = 0.0
	if _damage_flash_strength > 0.0:
		_damage_flash_strength = maxf(0.0, _damage_flash_strength - delta * 1.7)
		damage_flash.color.a = _damage_flash_strength * 0.34
		damage_flash.visible = _damage_flash_strength > 0.0
	if pause_panel.visible:
		preview_avatar.rotation.y = fmod(preview_avatar.rotation.y + delta * 0.55, TAU)


func _physics_process(delta: float) -> void:
	if not network.is_online():
		return
	_state_send_elapsed += delta
	var moving := player.velocity.length_squared() > 0.01
	var send_interval := (
		MOVING_STATE_SEND_INTERVAL if moving else IDLE_STATE_SEND_INTERVAL
	)
	var health := player.get_health()
	var limb_mask := player.get_limb_mask()
	var state_changed := (
		health != _last_sent_health
		or limb_mask != _last_sent_limb_mask
	)
	if state_changed or _state_send_elapsed >= send_interval:
		_state_send_elapsed = 0.0
		network.submit_owned_state(
			player.global_position,
			player.velocity,
			player.get_visual_yaw(),
			health,
			limb_mask
		)
		_last_sent_health = health
		_last_sent_limb_mask = limb_mask


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		toggle_pause()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("restart"):
		restart_level()
		get_viewport().set_input_as_handled()


func toggle_pause() -> void:
	if pause_panel.visible:
		_apply_name_setting()
	if network.is_online():
		var menu_open := not pause_panel.visible
		pause_panel.visible = menu_open
		pause_title.text = "AJUSTES EN LÍNEA"
		pause_button.text = "CERRAR" if menu_open else "MENÚ"
		player.set_controls_enabled(not menu_open and not player.is_defeated())
		$HUD/Joystick.set_input_enabled(not menu_open and not player.is_defeated())
		if not OS.has_feature("mobile"):
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if menu_open else Input.MOUSE_MODE_CAPTURED
		return
	get_tree().paused = not get_tree().paused
	pause_panel.visible = get_tree().paused
	pause_title.text = "MENÚ Y AJUSTES"
	pause_button.text = "SEGUIR" if get_tree().paused else "PAUSA"
	$HUD/Joystick.set_input_enabled(not get_tree().paused)
	if not OS.has_feature("mobile"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if get_tree().paused else Input.MOUSE_MODE_CAPTURED


func restart_level() -> void:
	if network.is_online() and (_participating_round or player.is_defeated()):
		round_detail.text = "No puedes reaparecer hasta terminar la ronda"
		return
	get_tree().paused = false
	pause_panel.visible = false
	pause_button.text = "MENÚ" if network.is_online() else "PAUSA"
	pause_title.text = "MENÚ Y AJUSTES"
	$HUD/PausePanel/Center/Resume.visible = true
	player.set_controls_enabled(true)
	$HUD/Joystick.set_input_enabled(true)
	player.reset_to_spawn()
	_reset_streak()
	if network.is_online():
		_defeated_this_round = true
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
	round_title.text = "ELIMINADO"
	round_detail.text = "Observa desde arriba hasta que termine la ronda"
	_defeated_this_round = true
	_reset_streak()
	player.enter_spectator()
	$HUD/Joystick.set_input_enabled(false)
	restart_button.disabled = true
	pause_restart.disabled = true


func _on_disaster_state_changed(title: String, detail: String) -> void:
	round_title.text = title
	round_detail.text = detail


func _on_disaster_clock_changed(seconds_left: int) -> void:
	round_clock.text = "%02d" % seconds_left


func _on_round_survived(_round_number: int) -> void:
	_participating_round = false
	player.reset_to_spawn()
	player.set_controls_enabled(not _match_finished)
	$HUD/Joystick.set_input_enabled(not _match_finished)
	restart_button.disabled = _match_finished
	pause_restart.disabled = _match_finished
	if network.is_online():
		if not _defeated_this_round:
			sounds.play_success()
		return
	if _defeated_this_round:
		return
	sounds.play_success()
	_completed_rounds += 1
	if _completed_rounds > _best_rounds:
		_best_rounds = _completed_rounds
		_save_profile()
	_update_score()


func _on_round_started(_round_number: int) -> void:
	if _round_number == 1:
		_match_victory_awarded = false
	_defeated_this_round = false
	_participating_round = true
	_match_finished = false
	match_result.visible = false
	player.reset_to_spawn()
	player.set_controls_enabled(true)
	$HUD/Joystick.set_input_enabled(true)
	restart_button.disabled = false
	pause_restart.disabled = false
	if network.is_online():
		score_label.text = "RONDA %d/%d" % [_round_number, _match_total_rounds]


func _on_experience_selected(plan: Dictionary) -> void:
	mode_map_host.activate_selection(
		StringName(plan.get("mode_id", &"")),
		StringName(plan.get("map_id", &""))
	)
	feature_host.apply_experience(plan)


func _on_mode_map_activated(
	_mode_id: StringName,
	_map_id: StringName,
	spawn_transform: Transform3D,
	has_spawn: bool
) -> void:
	if has_spawn:
		player.set_spawn_transform(spawn_transform)


func _on_player_damaged(_amount: int, _current: int) -> void:
	_damage_flash_strength = 1.0
	damage_flash.visible = true
	damage_flash.color.a = 0.34
	if OS.has_feature("mobile") and _vibration_enabled:
		Input.vibrate_handheld(70, 0.28)


func _on_push_requested() -> void:
	if not network.is_online():
		return
	var origin := player.global_position
	var forward := player.get_aim_forward()
	var closest_peer := -1
	var closest_distance := PUSH_RANGE + 1.0
	for peer_id: int in _remote_avatars:
		var avatar: RemoteAvatar = _remote_avatars[peer_id]
		var offset := avatar.global_position - origin
		if absf(offset.y) > 1.4:
			continue
		offset.y = 0.0
		var distance := offset.length()
		if distance < 0.2 or distance > PUSH_RANGE:
			continue
		if forward.dot(offset / distance) < PUSH_MIN_DOT:
			continue
		if distance < closest_distance:
			closest_distance = distance
			closest_peer = peer_id
	if closest_peer != -1:
		network.send_push(closest_peer, forward)


func _on_push_received(_sender_id: int, direction: Vector3, force: float) -> void:
	player.apply_external_push(direction, force)


func _on_shot_received(
	_shooter_player_id: int,
	target_player_id: int,
	origin: Vector3,
	hit_position: Vector3,
	damage: int,
	weapon_id: int
) -> void:
	disaster.spawn_network_shot(origin, hit_position, weapon_id)
	sounds.play_weapon_shot(weapon_id)
	var shooter_avatar: RemoteAvatar = _remote_avatars.get(_shooter_player_id)
	if shooter_avatar != null:
		shooter_avatar.play_shoot_animation(weapon_id)
	if target_player_id == network.get_local_player_id() and damage > 0:
		player.apply_shot_damage(damage, hit_position)


func _toggle_online() -> void:
	if _returning_to_menu:
		return
	_returning_to_menu = true
	_apply_name_setting()
	_save_profile()
	if network.is_online():
		network.returned_to_lobby.connect(_finish_return_to_menu, CONNECT_ONE_SHOT)
		network.leave_room()
		get_tree().create_timer(0.75, true, false, true).timeout.connect(
			_finish_return_to_menu
		)
		return
	_finish_return_to_menu()


func _finish_return_to_menu() -> void:
	if not _returning_to_menu:
		return
	_returning_to_menu = false
	network.disconnect_session()
	get_tree().paused = false
	get_tree().change_scene_to_file(MENU_SCENE)


func _on_network_status_changed(text: String, online: bool) -> void:
	_network_status_base = text
	network_status.text = text
	network_status.modulate = Color(0.4, 1.0, 0.62) if online else Color(0.76, 0.87, 1.0)
	online_button.disabled = (
		not online
		and (
			text.to_upper().begins_with("CONECT")
			or text.to_upper().begins_with("VALIDANDO")
		)
	)
	online_button.text = "SALIR" if online else "MENÚ"
	pause_button.text = "MENÚ" if online else "PAUSA"
	restart_button.text = "REAPARECER" if online else "REINICIAR"
	pause_restart.text = "REAPARECER" if online else "REINICIAR"
	name_input.editable = not online
	character_button.disabled = online
	if not online and not network.is_online():
		if pause_panel.visible and not get_tree().paused:
			pause_panel.visible = false
			player.set_controls_enabled(true)
			$HUD/Joystick.set_input_enabled(true)
			if not OS.has_feature("mobile"):
				Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		_clear_remote_players()


func _update_network_metrics() -> void:
	if not network.is_online():
		network_status.text = _network_status_base
		return
	var latency: int = int(network.get_latency_msec())
	var loss_percent: float = float(network.get_packet_loss_ratio()) * 100.0
	network_status.text = "%s · PING %d ms" % [_network_status_base, maxi(0, latency)]
	if loss_percent >= 1.0:
		network_status.text += " · PÉRDIDA %.1f%%" % loss_percent


func _on_standings_received(
	player_ids: PackedInt32Array,
	player_names: PackedStringArray,
	health_values: PackedByteArray,
	round_points: PackedByteArray,
	total_scores: PackedInt32Array,
	round_number: int,
	total_rounds: int,
	match_finished: bool,
	winner_player_id: int,
	match_id: int
) -> void:
	_match_total_rounds = total_rounds
	_match_finished = match_finished
	if round_number <= 0:
		return
	var rows := PackedStringArray()
	var count := player_ids.size()
	count = mini(count, player_names.size())
	count = mini(count, health_values.size())
	count = mini(count, round_points.size())
	count = mini(count, total_scores.size())
	for index in count:
		rows.append(
			"%d. %s · %d vida · +%d · %d pts"
			% [
				index + 1,
				player_names[index],
				health_values[index],
				round_points[index],
				total_scores[index],
			]
		)
	score_label.text = "\n".join(rows)
	var local_index := player_ids.find(network.get_local_player_id())
	var local_round_points := (
		int(round_points[local_index])
		if local_index >= 0 and local_index < round_points.size()
		else 0
	)
	var local_survived := (
		local_index >= 0
		and local_index < health_values.size()
		and health_values[local_index] > 0
	)
	if (
		match_id > 0
		and (
			match_id != _last_reward_match_id
			or round_number > _last_reward_round
		)
	):
		_last_reward_match_id = match_id
		_last_reward_round = round_number
		_multiplayer_experience += local_round_points
		_multiplayer_rounds += 1
		_multiplayer_survivals += int(local_survived)
		_save_profile()
	if match_finished:
		player.set_controls_enabled(false)
		$HUD/Joystick.set_input_enabled(false)
		restart_button.disabled = true
		pause_restart.disabled = true
		var winner_index := player_ids.find(winner_player_id)
		var winner_name := (
			player_names[winner_index]
			if winner_index >= 0
			else "Sin ganador"
		)
		round_title.text = "GANADOR: %s" % winner_name
		round_detail.text = "Clasificación final tras %d rondas" % total_rounds
		if match_id > 0 and match_id != _last_completed_match_id:
			_last_completed_match_id = match_id
			_multiplayer_matches += 1
			if winner_player_id == network.get_local_player_id():
				_match_victory_awarded = true
				_total_victories += 1
		network.profile_victories = _total_victories
		network.profile_experience = _multiplayer_experience
		_save_profile()
		result_title.text = "GANADOR: %s" % winner_name
		result_standings.text = "\n".join(rows)
		result_reward.text = (
			"+%d XP esta ronda · %d XP total · %d victorias"
			% [local_round_points, _multiplayer_experience, _total_victories]
		)
		return_room_button.disabled = false
		exit_match_button.disabled = false
		match_result.visible = true


func _on_remote_player_joined(peer_id: int, player_name: String, player_color: int) -> void:
	if _remote_avatars.has(peer_id):
		return
	var avatar: RemoteAvatar = REMOTE_AVATAR_SCENE.instantiate()
	avatar.name = "Peer%d" % peer_id
	remote_players.add_child(avatar)
	avatar.configure(player_name, player_color, Vector3(0.0, 1.2, 8.0))
	avatar.set_shadow_quality(_quality_level >= 1)
	avatar.set_texture_detail(_quality_level >= 1)
	avatar.set_model_quality(_quality_level >= 2)
	avatar.set_detail_quality(_quality_level)
	_remote_avatars[peer_id] = avatar


func _on_remote_player_left(peer_id: int) -> void:
	var avatar: RemoteAvatar = _remote_avatars.get(peer_id)
	if avatar != null:
		avatar.queue_free()
	_remote_avatars.erase(peer_id)


func _on_remote_snapshot(
	peer_id: int,
	position: Vector3,
	velocity: Vector3,
	facing_yaw: float,
	limb_mask: int,
	health: int
) -> void:
	var avatar: RemoteAvatar = _remote_avatars.get(peer_id)
	if avatar != null:
		avatar.set_snapshot(position, velocity, facing_yaw)
		avatar.set_limb_mask(limb_mask)
		avatar.set_health(health)


func _return_to_same_room() -> void:
	if not network.is_online():
		return
	return_room_button.disabled = true
	exit_match_button.disabled = true
	result_reward.text = "Volviendo a la sala…"
	network.reopen_room()


func _on_room_reopened(_room_id: int) -> void:
	_save_profile()
	get_tree().paused = false
	get_tree().change_scene_to_file(MENU_SCENE)


func _exit_match_to_lobby() -> void:
	if _returning_to_menu:
		return
	_returning_to_menu = true
	_save_profile()
	return_room_button.disabled = true
	exit_match_button.disabled = true
	network.returned_to_lobby.connect(_finish_leave_to_lobby, CONNECT_ONE_SHOT)
	network.leave_room()


func _finish_leave_to_lobby() -> void:
	if not _returning_to_menu:
		return
	_returning_to_menu = false
	get_tree().paused = false
	get_tree().change_scene_to_file(MENU_SCENE)


func _on_simulation_host_changed(peer_id: int) -> void:
	if peer_id == multiplayer.get_unique_id():
		disaster.sync_as_host()


func _clear_remote_players() -> void:
	for avatar: RemoteAvatar in _remote_avatars.values():
		avatar.queue_free()
	_remote_avatars.clear()


func _load_profile() -> void:
	var config := ConfigFile.new()
	network.color_index = 0
	if config.load(PROFILE_PATH) == OK:
		var saved_name := str(config.get_value("player", "name", "")).strip_edges().substr(0, 16)
		if not saved_name.is_empty():
			network.display_name = saved_name
		_best_rounds = maxi(0, int(config.get_value("player", "best_rounds", 0)))
		_total_victories = maxi(0, int(config.get_value("player", "total_victories", 0)))
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
		_last_reward_match_id = int(
			config.get_value("player", "last_reward_match_id", 0)
		)
		_last_reward_round = maxi(
			0,
			int(config.get_value("player", "last_reward_round", 0))
		)
		_last_completed_match_id = int(
			config.get_value("player", "last_completed_match_id", 0)
		)
		_install_id = str(config.get_value("player", "install_id", ""))
		network.color_index = CHARACTER_CATALOG.sanitize_index(
			int(config.get_value("player", "character", 0))
		)
		sounds.set_enabled(bool(config.get_value("settings", "sound", true)))
		_vibration_enabled = bool(config.get_value("settings", "vibration", true))
		_first_person_enabled = bool(config.get_value("settings", "first_person", false))
		player.set_look_sensitivity_scale(
			float(config.get_value("settings", "look_sensitivity", 1.0))
		)
		_quality_level = clampi(
			int(config.get_value("settings", "quality", 0)),
			0,
			QUALITY_NAMES.size() - 1
		)
		var saved_fps := int(config.get_value("settings", "fps_limit", 60))
		_fps_limit_index = FPS_LIMITS.find(saved_fps)
		if _fps_limit_index == -1:
			_fps_limit_index = 2
	if _install_id.is_empty():
		_install_id = Crypto.new().generate_random_bytes(16).hex_encode()
	network.profile_victories = _total_victories
	network.profile_experience = _multiplayer_experience
	name_input.text = network.display_name
	sound_toggle.button_pressed = sounds.is_enabled()
	vibration_toggle.button_pressed = _vibration_enabled
	player.set_first_person(_first_person_enabled)
	player.set_character_variant(network.color_index)
	sensitivity_slider.value = player.get_look_sensitivity_scale()
	_update_camera_button()
	_update_character_button()
	_apply_quality()
	_apply_fps_limit()
	_update_sensitivity_label()
	_update_score()
	_save_profile()


func _save_profile() -> void:
	var config := ConfigFile.new()
	config.set_value("player", "name", network.display_name)
	config.set_value("player", "best_rounds", _best_rounds)
	config.set_value("player", "total_victories", _total_victories)
	config.set_value("player", "multiplayer_experience", _multiplayer_experience)
	config.set_value("player", "multiplayer_matches", _multiplayer_matches)
	config.set_value("player", "multiplayer_rounds", _multiplayer_rounds)
	config.set_value("player", "multiplayer_survivals", _multiplayer_survivals)
	config.set_value("player", "last_reward_match_id", _last_reward_match_id)
	config.set_value("player", "last_reward_round", _last_reward_round)
	config.set_value("player", "last_completed_match_id", _last_completed_match_id)
	config.set_value("player", "install_id", _install_id)
	config.set_value("player", "character", network.color_index)
	config.set_value("settings", "sound", sounds.is_enabled())
	config.set_value("settings", "vibration", _vibration_enabled)
	config.set_value("settings", "first_person", _first_person_enabled)
	config.set_value("settings", "look_sensitivity", player.get_look_sensitivity_scale())
	config.set_value("settings", "quality", _quality_level)
	config.set_value("settings", "fps_limit", FPS_LIMITS[_fps_limit_index])
	var error := config.save(PROFILE_PATH)
	if error != OK:
		push_warning("No se pudo guardar el perfil del jugador: %s" % error)


func _reset_streak() -> void:
	_completed_rounds = 0
	_update_score()


func _update_score() -> void:
	score_label.text = "RONDAS %d · RÉCORD %d · VICTORIAS %d" % [
		_completed_rounds,
		_best_rounds,
		_total_victories,
	]


func _on_sound_toggled(enabled: bool) -> void:
	sounds.set_enabled(enabled)
	_save_profile()


func _on_vibration_toggled(enabled: bool) -> void:
	_vibration_enabled = enabled
	_save_profile()


func _toggle_camera_mode() -> void:
	_first_person_enabled = not _first_person_enabled
	player.set_first_person(_first_person_enabled)
	_update_camera_button()
	_save_profile()


func _update_camera_button() -> void:
	camera_button.text = (
		"CÁMARA: PRIMERA PERSONA" if _first_person_enabled
		else "CÁMARA: TERCERA PERSONA"
	)


func _on_name_submitted(_new_text: String) -> void:
	_apply_name_setting()


func _apply_name_setting() -> void:
	if network.is_online():
		return
	var safe_name := name_input.text.strip_edges().substr(0, 16)
	if safe_name.is_empty():
		safe_name = network.display_name
	name_input.text = safe_name
	network.display_name = safe_name
	_save_profile()


func _on_sensitivity_changed(value: float) -> void:
	player.set_look_sensitivity_scale(value)
	_update_sensitivity_label()
	_save_profile()


func _update_sensitivity_label() -> void:
	sensitivity_value.text = "%.1fx" % player.get_look_sensitivity_scale()


func _on_quality_selected(index: int) -> void:
	_quality_level = clampi(index, 0, QUALITY_NAMES.size() - 1)
	_apply_quality()
	_save_profile()


func _apply_quality() -> void:
	var viewport := get_viewport()
	match _quality_level:
		0:
			viewport.msaa_3d = Viewport.MSAA_DISABLED
			sun.shadow_enabled = false
			world_environment.environment.fog_enabled = false
			world_environment.environment.ambient_light_energy = 0.78
		1:
			viewport.msaa_3d = Viewport.MSAA_4X
			sun.shadow_enabled = true
			sun.directional_shadow_max_distance = 42.0
			world_environment.environment.fog_enabled = false
			world_environment.environment.ambient_light_energy = 0.88
		_:
			viewport.msaa_3d = Viewport.MSAA_4X
			sun.shadow_enabled = true
			sun.directional_shadow_max_distance = 72.0
			world_environment.environment.fog_enabled = true
			world_environment.environment.fog_light_color = Color(0.31, 0.42, 0.52)
			world_environment.environment.fog_light_energy = 0.72
			world_environment.environment.fog_density = 0.012
			world_environment.environment.fog_height = 1.0
			world_environment.environment.fog_height_density = 0.08
			world_environment.environment.ambient_light_energy = 1.0
	for mesh in get_tree().get_nodes_in_group("quality_shadow"):
		var geometry := mesh as GeometryInstance3D
		if geometry != null:
			geometry.cast_shadow = (
				GeometryInstance3D.SHADOW_CASTING_SETTING_ON
				if _quality_level >= 1
				else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			)
	for avatar: RemoteAvatar in _remote_avatars.values():
		avatar.set_shadow_quality(_quality_level >= 1)
		avatar.set_texture_detail(_quality_level >= 1)
		avatar.set_model_quality(_quality_level >= 2)
		avatar.set_detail_quality(_quality_level)
	player.set_texture_detail(_quality_level >= 1)
	player.set_model_quality(_quality_level >= 2)
	player.set_detail_quality(_quality_level)
	preview_avatar.set_texture_detail(_quality_level >= 1)
	preview_avatar.set_model_quality(_quality_level >= 2)
	preview_avatar.set_detail_quality(_quality_level)
	for receiver in get_tree().get_nodes_in_group(&"quality_receiver"):
		if receiver.has_method("set_quality_level"):
			receiver.call("set_quality_level", _quality_level)
	quality_button.select(_quality_level)


func _on_fps_limit_selected(index: int) -> void:
	_fps_limit_index = clampi(index, 0, FPS_LIMITS.size() - 1)
	_apply_fps_limit()
	_save_profile()


func _apply_fps_limit() -> void:
	var limit: int = FPS_LIMITS[_fps_limit_index]
	Engine.max_fps = limit
	fps_button.select(_fps_limit_index)


func _on_character_selected(index: int) -> void:
	var next_index := CHARACTER_CATALOG.sanitize_index(index)
	if (
		next_index == CHARACTER_CATALOG.GOLDEN_INDEX
		and _total_victories < CHARACTER_CATALOG.GOLDEN_CHARACTER_COST
	):
		character_button.select(int(network.color_index))
		round_detail.text = (
			"Dorado requiere %d victorias multijugador"
			% CHARACTER_CATALOG.GOLDEN_CHARACTER_COST
		)
		return
	network.color_index = next_index
	player.set_character_variant(next_index)
	_update_character_button()
	_save_profile()


func _update_character_button() -> void:
	character_button.select(int(network.color_index))
	preview_avatar.configure("", int(network.color_index), Vector3(0.0, -0.15, 0.0))
	preview_avatar.get_node("Name").visible = false
	preview_avatar.set_process(false)
	preview_avatar.set_shadow_quality(false)
	preview_avatar.set_texture_detail(_quality_level >= 1)
	preview_avatar.set_model_quality(_quality_level >= 2)


func _populate_option_lists() -> void:
	quality_button.clear()
	for quality_name in QUALITY_NAMES:
		quality_button.add_item("CALIDAD: %s" % quality_name)
	fps_button.clear()
	for limit in FPS_LIMITS:
		fps_button.add_item("LÍMITE: %d FPS" % limit)
	character_button.clear()
	for index in CHARACTER_CATALOG.NAMES.size():
		var suffix := (
			" · BLOQUEADO (%d)" % CHARACTER_CATALOG.GOLDEN_CHARACTER_COST
			if index == CHARACTER_CATALOG.GOLDEN_INDEX
			else ""
		)
		character_button.add_item("%s%s" % [CHARACTER_CATALOG.NAMES[index], suffix])
