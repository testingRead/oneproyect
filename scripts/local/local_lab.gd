class_name LocalDevelopmentLab
extends Node3D

const SCALE := preload("res://shared/gameplay_scale.gd")
const LAB_MAP: MinigameMapDefinition = preload("res://data/maps/campo_futbol_local.tres")
const MENU_SCENE := "res://scenes/menu.tscn"
const CROWN_HOST_SCRIPT := preload("res://scripts/local/local_crown_host.gd")
const BOMB_HOST_SCRIPT := preload("res://scripts/local/local_bomb_host.gd")
const TORNADO_HOST_SCRIPT := preload("res://scripts/local/local_tornado_host.gd")
const BATEBALL_HOST_SCRIPT := preload("res://scripts/local/local_bateball_host.gd")
const SHOOTER_HOST_SCRIPT := preload("res://scripts/local/local_shooter_host.gd")
const BASE_CHARACTER_SCENE := preload("res://scenes/local/base_character.tscn")
const LAN_EVENT := preload("res://shared/lan_round_event.gd")
const WEAPONS := preload("res://shared/weapon_profiles.gd")

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
@onready var shoot_button: TouchActionButton = $HUD/Shoot
@onready var reload_button: TouchActionButton = $HUD/Reload
@onready var crosshair: Label = $HUD/Crosshair
@onready var damage_flash: ColorRect = $HUD/DamageFlash
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
var bomb_host
var tornado_host
var bateball_host
var shooter_host
var lan_session
var _lan_remotes: Dictionary = {}
var _lan_targets: Dictionary = {}
var _lan_send_elapsed := 0.0
var _lan_physics_elapsed := 0.0
var _aim_value := Vector2(0.0, -1.0)
var _aim_active := false
var _last_local_health := 100
var _damage_tween: Tween
var _aim_line: Line2D
var _aim_fill: Polygon2D
var _pending_crown_holder_peer := -1
var _pending_bomb_holder_peer := -1
var _pending_bomb_remaining_msec := 0
var _pending_bateball_holder_peer := -1


func _ready() -> void:
	set_meta(&"runtime_mode", &"LOCAL_DEVELOPMENT")
	var session_mode := str(ProjectSettings.get_setting("oneproyect/session_mode", "local"))
	var network := get_node_or_null("/root/Network")
	if network != null:
		player.set_meta("display_name", str(network.get("display_name")))
	if session_mode != "lan" and network != null and network.has_method("disconnect_session"):
		network.call("disconnect_session")
	_build_island_once()
	_load_room_content()
	crown_host = CROWN_HOST_SCRIPT.new()
	crown_host.name = "CrownHost"
	add_child(crown_host)
	bomb_host = BOMB_HOST_SCRIPT.new()
	bomb_host.name = "BombHost"
	add_child(bomb_host)
	tornado_host = TORNADO_HOST_SCRIPT.new()
	tornado_host.name = "TornadoHost"
	add_child(tornado_host)
	bateball_host = BATEBALL_HOST_SCRIPT.new()
	bateball_host.name = "BateballHost"
	add_child(bateball_host)
	shooter_host = SHOOTER_HOST_SCRIPT.new()
	shooter_host.name = "ShooterHost"
	add_child(shooter_host)
	$HUD/DiagnosticsPanel.hide()
	hand_button.hide()
	shoot_button.hide()
	reload_button.hide()
	_create_penalty_buttons()
	round_button.set_label("JUGAR")
	joystick.value_changed.connect(player.set_touch_move)
	look_pad.look_delta.connect(player.add_touch_look)
	look_pad.aim_changed.connect(_on_aim_changed)
	look_pad.aim_released.connect(_on_aim_released)
	jump_button.action_pressed.connect(player.request_jump)
	hand_button.action_pressed.connect(_on_hand_action)
	foot_button.action_pressed.connect(_on_foot_action)
	round_button.action_pressed.connect(_on_round_button_pressed)
	shoot_button.action_pressed.connect(_on_shooter_shoot)
	shoot_button.action_released.connect(_on_shooter_shoot_released)
	reload_button.action_pressed.connect(_on_shooter_reload)
	player.metrics_changed.connect(_on_player_metrics)
	player.object_impulse_requested.connect(_on_local_object_impulse)
	playable_area.area_changed.connect(_on_area_changed)
	round_controller.configure(
		_selected_map,
		map_host,
		football_host,
		crown_host,
		bomb_host,
		tornado_host,
		bateball_host,
		shooter_host,
		_selected_minigame_id,
		player,
		playable_area
	)
	round_controller.phase_changed.connect(_on_round_phase_changed)
	round_controller.phase_time_changed.connect(_on_round_phase_time_changed)
	football_host.score_changed.connect(_on_football_score_changed)
	football_host.goal_scored.connect(_on_goal_scored)
	football_host.kickoff_ready.connect(_on_kickoff_ready)
	football_host.penalty_choice_requested.connect(_on_penalty_choice_requested)
	football_host.penalty_cinematic.connect(_on_penalty_cinematic)
	football_host.penalty_score_changed.connect(_on_penalty_score_changed)
	crown_host.crown_holder_changed.connect(_on_crown_holder_changed)
	crown_host.crown_holder_peer_changed.connect(_on_local_crown_holder_peer_changed)
	crown_host.match_completed.connect(_on_crown_match_completed)
	bomb_host.bomb_holder_changed.connect(_on_bomb_holder_changed)
	bomb_host.bomb_timer_changed.connect(_on_bomb_timer_changed)
	bomb_host.bomb_exploded.connect(_on_bomb_exploded)
	bomb_host.bomb_holder_peer_changed.connect(_on_local_bomb_holder_peer_changed)
	bomb_host.bomb_explosion_authorized.connect(_on_local_bomb_explosion_authorized)
	tornado_host.timer_changed.connect(_on_tornado_timer_changed)
	tornado_host.health_changed.connect(_on_tornado_health_changed)
	tornado_host.player_captured.connect(_on_tornado_player_captured)
	tornado_host.character_health_authorized.connect(_on_tornado_character_health_authorized)
	tornado_host.round_completed_authorized.connect(_on_tornado_round_completed_authorized)
	bateball_host.score_changed.connect(_on_bateball_score_changed)
	bateball_host.ball_holder_changed.connect(_on_bateball_holder_changed)
	bateball_host.goal_scored.connect(_on_bateball_goal_scored)
	bateball_host.ball_holder_peer_changed.connect(_on_local_bateball_holder_peer_changed)
	bateball_host.character_health_authorized.connect(_on_bateball_character_health_authorized)
	bateball_host.bat_impact_authorized.connect(_on_bateball_impact_authorized)
	shooter_host.score_changed.connect(_on_shooter_score_changed)
	shooter_host.ammo_changed.connect(_on_shooter_ammo_changed)
	shooter_host.combat_message.connect(_on_shooter_combat_message)
	shooter_host.hit_confirmed.connect(_on_shooter_hit_confirmed)
	shooter_host.shot_requested.connect(_on_local_shooter_shot_requested)
	shooter_host.reload_requested.connect(_on_local_shooter_reload_requested)
	shooter_host.shot_authorized.connect(_on_shooter_shot_authorized)
	shooter_host.weapon_state_authorized.connect(_on_shooter_weapon_state_authorized)
	shooter_host.hit_authorized.connect(_on_shooter_hit_authorized)
	shooter_host.character_health_authorized.connect(_on_shooter_health_authorized)
	shooter_host.classification_authorized.connect(_on_shooter_classification_authorized)
	player.bat_charge_changed.connect(_on_bat_charge_changed)
	player.bat_swing_started.connect(_on_local_bat_swing)
	player.local_health_changed.connect(_on_local_player_health_changed)
	player.foot_action_changed.connect(_on_foot_action_changed)
	player.hand_action_availability_changed.connect(_on_hand_action_availability_changed)
	player.character_push_requested.connect(_on_local_character_push)
	_build_aim_guide()
	look_pad.set_aim_mode(_is_bateball_game())
	playable_area.set_area_index(_area_index)
	playable_area.set_physical_walls_enabled(false)
	_on_player_metrics(player.get_diagnostics())
	_on_round_phase_changed(LocalRoundController.Phase.IDLE, "IDLE", 0.0)
	if session_mode == "lan":
		_setup_lan_session()
	_launched_from_room = bool(ProjectSettings.get_setting("oneproyect/session_auto_start", false))
	ProjectSettings.set_setting("oneproyect/session_auto_start", false)
	if _launched_from_room:
		round_button.hide()
		call_deferred("_start_session_round")


func _process(_delta: float) -> void:
	_update_aim_guide()


func _start_session_round() -> void:
	var seed := int(ProjectSettings.get_setting("oneproyect/session_round_seed", 0))
	if lan_session != null and lan_session.is_active():
		lan_session.set_round_context(seed)
	start_reference_round(seed)


func _physics_process(delta: float) -> void:
	if lan_session == null or not lan_session.is_active():
		return
	_lan_send_elapsed -= delta
	if _lan_send_elapsed <= 0.0:
		_lan_send_elapsed = 0.05
		lan_session.send_player_state(
			player.global_position,
			player.velocity,
			player.visual_root.rotation.y,
			player.get_look_pitch(),
			player.get_local_health()
		)
	if lan_session.is_host:
		_lan_physics_elapsed -= delta
		if _lan_physics_elapsed <= 0.0:
			_lan_physics_elapsed = 1.0 / 15.0
			_send_lan_physics_state()
	for peer_id in _lan_targets:
		var remote: LocalBaseCharacter = _lan_remotes.get(peer_id)
		if not is_instance_valid(remote):
			continue
		var target: Dictionary = _lan_targets[peer_id]
		remote.global_position = remote.global_position.lerp(target.position, minf(1.0, delta * 14.0))
		remote.update_remote_presentation(delta, target.velocity, float(target.yaw))
		remote.update_remote_look_pitch(
			float(target.look_pitch)
			if _selected_minigame_id in [&"futbol_rebote", &"shooter_local"]
			else 0.0
		)


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


func _setup_lan_session() -> void:
	lan_session = get_node_or_null("/root/LanSession")
	if lan_session == null or not lan_session.is_active():
		return
	round_controller.player_slot = lan_session.get_local_slot()
	player.set_meta(&"lan_slot", round_controller.player_slot)
	player.set_meta(&"lan_peer_id", lan_session.get_local_peer_id())
	lan_session.player_state_received.connect(_on_lan_player_state)
	lan_session.physics_state_received.connect(_on_lan_physics_state)
	lan_session.hazard_state_received.connect(_on_lan_hazard_state)
	lan_session.object_impulse_peer_received.connect(_on_lan_object_impulse)
	lan_session.action_received.connect(_on_lan_action)
	lan_session.action_request_received.connect(_on_lan_action_request)
	lan_session.bat_swing_received.connect(_on_lan_bat_swing)
	lan_session.bateball_shot_received.connect(_on_lan_bateball_shot)
	lan_session.round_event_received.connect(_on_lan_round_event)
	bateball_host.set_session_authority(lan_session.is_host)
	crown_host.set_session_authority(lan_session.is_host)
	bomb_host.set_session_authority(lan_session.is_host)
	football_host.set_session_authority(lan_session.is_host)
	tornado_host.set_session_authority(lan_session.is_host)
	shooter_host.set_session_authority(lan_session.is_host)
	lan_session.lobby_changed.connect(_sync_lan_players)
	_sync_lan_players()


func _sync_lan_players() -> void:
	if lan_session == null:
		return
	var local_id: int = lan_session.get_local_peer_id()
	for peer_id in lan_session.players:
		if int(peer_id) == local_id or _lan_remotes.has(peer_id):
			continue
		var remote := BASE_CHARACTER_SCENE.instantiate() as LocalBaseCharacter
		remote.name = "LanPlayer%d" % int(peer_id)
		remote.controls_enabled = false
		remote.emit_metrics = false
		remote.set_meta("display_name", lan_session.get_player_name(int(peer_id)))
		var remote_slot: int = int(lan_session.get_peer_slot(int(peer_id)))
		remote.set_meta(&"lan_slot", remote_slot)
		remote.set_meta(&"lan_peer_id", int(peer_id))
		var camera := remote.get_node("CameraPivot/SpringArm/Camera") as Camera3D
		camera.current = false
		$World.add_child(remote)
		remote.set_physics_process(false)
		var remote_spawn := map_host.get_spawn_transform(remote_slot)
		remote.global_transform = remote_spawn
		_lan_remotes[peer_id] = remote
	for peer_id in _lan_remotes.keys():
		if not lan_session.players.has(peer_id):
			var remote: LocalBaseCharacter = _lan_remotes[peer_id]
			if is_instance_valid(remote):
				remote.queue_free()
			_lan_remotes.erase(peer_id)
			_lan_targets.erase(peer_id)


func _on_lan_player_state(peer_id: int, position: Vector3, velocity: Vector3, facing_yaw: float, look_pitch: float, health: int) -> void:
	if not _lan_remotes.has(peer_id):
		_sync_lan_players()
	_lan_targets[peer_id] = {
		"position": position,
		"velocity": velocity,
		"yaw": facing_yaw,
		"look_pitch": look_pitch,
		"health": health,
	}


func _send_lan_physics_state() -> void:
	var names := PackedStringArray()
	var positions := PackedVector3Array()
	var rotations := PackedVector3Array()
	var velocities := PackedVector3Array()
	for object in get_tree().get_nodes_in_group(&"local_round_object"):
		if object is RigidBody3D and map_host.is_ancestor_of(object):
			var body := object as RigidBody3D
			names.append(body.name)
			positions.append(body.global_position)
			rotations.append(body.global_rotation)
			velocities.append(body.linear_velocity)
	lan_session.send_physics_state(names, positions, rotations, velocities)
	if _is_tornado_game() and tornado_host.is_active():
		lan_session.send_hazard_state(
			LAN_EVENT.Subject.TORNADO,
			tornado_host.get_hazard_position(),
			tornado_host.get_remaining()
		)


func _on_lan_physics_state(names: PackedStringArray, positions: PackedVector3Array, rotations: PackedVector3Array, velocities: PackedVector3Array) -> void:
	if lan_session == null or lan_session.is_host:
		return
	var count := mini(mini(names.size(), positions.size()), mini(rotations.size(), velocities.size()))
	for index in count:
		var body := _find_round_body(names[index])
		if body == null:
			continue
		body.global_position = body.global_position.lerp(positions[index], 0.72)
		body.global_rotation = rotations[index]
		body.linear_velocity = velocities[index]


func _on_lan_hazard_state(subject: int, position_value: Vector3, remaining: float) -> void:
	if lan_session == null or lan_session.is_host:
		return
	if subject == LAN_EVENT.Subject.TORNADO:
		tornado_host.apply_authoritative_state(position_value, remaining)


func _on_local_object_impulse(object_name: String, impulse: Vector3) -> void:
	if lan_session == null or not lan_session.is_active():
		return
	if lan_session.is_host:
		if _selected_minigame_id == &"futbol_rebote":
			lan_session.broadcast_action(
				lan_session.get_local_peer_id(),
				LAN_EVENT.Action.FOOTBALL_KICK,
				player.get_facing_direction()
			)
	else:
		lan_session.request_object_impulse(object_name, impulse)


func _on_local_bat_swing(charged: bool) -> void:
	if lan_session == null or not lan_session.is_active():
		return
	if lan_session.is_host:
		lan_session.broadcast_action(
			lan_session.get_local_peer_id(),
			LAN_EVENT.Action.BATEBALL_SWING,
			player.get_facing_direction(),
			charged
		)
	else:
		lan_session.request_bat_swing(player.get_facing_direction(), charged)


func _on_lan_object_impulse(peer_id: int, object_name: String, impulse: Vector3) -> void:
	if lan_session == null or not lan_session.is_host:
		return
	var body := _find_round_body(object_name)
	if body != null:
		body.sleeping = false
		body.apply_central_impulse(impulse)
	if _selected_minigame_id == &"futbol_rebote":
		var kicker := _get_lan_character(peer_id)
		var facing := (
			kicker.get_facing_direction()
			if is_instance_valid(kicker)
			else Vector3(impulse.x, 0.0, impulse.z).normalized()
		)
		lan_session.broadcast_action(
			peer_id, LAN_EVENT.Action.FOOTBALL_KICK, facing
		)


func _on_lan_bat_swing(peer_id: int, facing: Vector3, charged: bool) -> void:
	if lan_session == null or not lan_session.is_host or peer_id == lan_session.get_local_peer_id():
		return
	var remote: LocalBaseCharacter = _lan_remotes.get(peer_id)
	if is_instance_valid(remote):
		remote.set_facing_direction(facing)
		remote.set_bat_enabled(true)
		remote.perform_network_bat_swing(charged)
		lan_session.broadcast_action(
			peer_id, LAN_EVENT.Action.BATEBALL_SWING, facing, charged
		)


func _on_local_character_push(target_peer_id: int, direction: Vector3) -> void:
	if lan_session == null or not lan_session.is_active() or target_peer_id <= 0:
		return
	if lan_session.is_host:
		lan_session.broadcast_action(
			lan_session.get_local_peer_id(),
			LAN_EVENT.Action.CHARACTER_PUSH,
			direction,
			false,
			target_peer_id
		)
	else:
		lan_session.request_action(
			LAN_EVENT.Action.CHARACTER_PUSH, target_peer_id, direction
		)


func _on_lan_action_request(
	peer_id: int,
	action: int,
	target_peer_id: int,
	direction: Vector3,
	flag: bool
) -> void:
	if lan_session == null or not lan_session.is_host:
		return
	if action == LAN_EVENT.Action.SHOOTER_SHOT:
		var shooter_actor := _get_lan_character(peer_id)
		if is_instance_valid(shooter_actor) and _is_shooter_game():
			shooter_host.process_network_shot(shooter_actor, direction)
		return
	if action == LAN_EVENT.Action.SHOOTER_RELOAD:
		var reload_actor := _get_lan_character(peer_id)
		if is_instance_valid(reload_actor) and _is_shooter_game():
			shooter_host.process_network_reload(reload_actor)
		return
	if action != LAN_EVENT.Action.CHARACTER_PUSH:
		return
	var actor := _get_lan_character(peer_id)
	var target := _get_lan_character(target_peer_id)
	if not is_instance_valid(actor) or not is_instance_valid(target):
		return
	var offset := target.global_position - actor.global_position
	var horizontal := Vector3(offset.x, 0.0, offset.z)
	if horizontal.length() > 2.0 or horizontal.length_squared() < 0.01:
		return
	var push_direction := Vector3(direction.x, 0.0, direction.z).normalized()
	if push_direction.dot(horizontal.normalized()) < 0.15:
		return
	actor.play_remote_push(push_direction)
	target.apply_external_push(
		(push_direction + Vector3.UP * 0.12).normalized(), 4.2
	)
	lan_session.broadcast_action(
		peer_id, action, push_direction, flag, target_peer_id
	)


func _on_lan_action(
	peer_id: int,
	action: int,
	target_peer_id: int,
	direction: Vector3,
	flag: bool
) -> void:
	if lan_session == null or peer_id == lan_session.get_local_peer_id():
		return
	var remote := _get_lan_character(peer_id)
	if not is_instance_valid(remote):
		return
	match action:
		LAN_EVENT.Action.FOOTBALL_KICK:
			remote.perform_network_kick(direction)
		LAN_EVENT.Action.BATEBALL_SWING:
			remote.set_bat_enabled(true)
			remote.play_remote_bat_swing(flag)
		LAN_EVENT.Action.CHARACTER_PUSH:
			remote.play_remote_push(direction)
			var push_target := _get_lan_character(target_peer_id)
			if is_instance_valid(push_target):
				push_target.apply_external_push(
					(direction + Vector3.UP * 0.12).normalized(), 4.2
				)
		LAN_EVENT.Action.BATEBALL_IMPACT:
			var hit_target := _get_lan_character(target_peer_id)
			if is_instance_valid(hit_target):
				hit_target.apply_external_push(direction, LocalBaseCharacter.BAT_CHARGED_PUSH_FORCE)
		LAN_EVENT.Action.SHOOTER_SHOT:
			if _is_shooter_game():
				shooter_host.play_remote_shot(remote, direction)


func _on_lan_bateball_shot(peer_id: int, direction: Vector3) -> void:
	if lan_session == null or not lan_session.is_host or peer_id == lan_session.get_local_peer_id():
		return
	var remote: LocalBaseCharacter = _lan_remotes.get(peer_id)
	if is_instance_valid(remote) and is_instance_valid(bateball_host):
		bateball_host.request_ball_shot(remote, direction)


func _on_local_bateball_holder_peer_changed(peer_id: int) -> void:
	if lan_session != null and lan_session.is_active() and lan_session.is_host:
		lan_session.broadcast_round_event(
			LAN_EVENT.Kind.HOLDER_CHANGED,
			LAN_EVENT.Subject.BATEBALL,
			peer_id
		)


func _on_lan_bateball_holder(peer_id: int) -> void:
	if lan_session == null or lan_session.is_host:
		return
	var holder: LocalBaseCharacter = player if peer_id == lan_session.get_local_peer_id() else _lan_remotes.get(peer_id)
	bateball_host.apply_authoritative_holder(holder if is_instance_valid(holder) else null)


func _on_lan_bateball_score(home_score: int, away_score: int, complete: bool) -> void:
	if lan_session != null and not lan_session.is_host:
		bateball_host.apply_authoritative_score(home_score, away_score, complete)


func _on_local_crown_holder_peer_changed(peer_id: int) -> void:
	if lan_session != null and lan_session.is_active() and lan_session.is_host:
		lan_session.broadcast_round_event(
			LAN_EVENT.Kind.HOLDER_CHANGED,
			LAN_EVENT.Subject.CROWN,
			peer_id
		)


func _on_lan_round_event(
	round_id: int,
	_revision: int,
	kind: int,
	subject: int,
	actor_peer_id: int,
	integer_values: PackedInt32Array,
	vector_values: PackedVector3Array
) -> void:
	if round_id != round_controller.round_seed or lan_session == null or lan_session.is_host:
		return
	if kind == LAN_EVENT.Kind.HOLDER_CHANGED and subject == LAN_EVENT.Subject.CROWN:
		_pending_crown_holder_peer = actor_peer_id
		_apply_pending_round_state()
	elif kind == LAN_EVENT.Kind.HOLDER_CHANGED and subject == LAN_EVENT.Subject.BOMB:
		_pending_bomb_holder_peer = actor_peer_id
		_pending_bomb_remaining_msec = (
			integer_values[0] if not integer_values.is_empty() else 0
		)
		_apply_pending_round_state()
	elif kind == LAN_EVENT.Kind.HOLDER_CHANGED and subject == LAN_EVENT.Subject.BATEBALL:
		_pending_bateball_holder_peer = actor_peer_id
		_apply_pending_round_state()
	elif kind == LAN_EVENT.Kind.ROUND_COMPLETED and subject == LAN_EVENT.Subject.BOMB:
		var loser := _get_lan_character(actor_peer_id)
		var explosion_position := (
			vector_values[0] if not vector_values.is_empty() else Vector3.ZERO
		)
		bomb_host.apply_authoritative_explosion(loser, explosion_position)
	elif kind == LAN_EVENT.Kind.SCORE_CHANGED and subject == LAN_EVENT.Subject.FOOTBALL:
		if integer_values.size() >= 4:
			football_host.apply_authoritative_score(
				integer_values[0],
					integer_values[1],
					integer_values[2] != 0,
					integer_values[3]
				)
			if integer_values.size() >= 5 and integer_values[4] >= 0:
				_show_football_goal(
					&"home" if integer_values[4] == 0 else &"away"
				)
	elif kind == LAN_EVENT.Kind.SCORE_CHANGED and subject == LAN_EVENT.Subject.BATEBALL:
		if integer_values.size() >= 3:
			bateball_host.apply_authoritative_score(
				integer_values[0], integer_values[1], integer_values[2] != 0
			)
			if integer_values.size() >= 4 and integer_values[3] >= 0:
				_show_bateball_goal(
					&"home" if integer_values[3] == 0 else &"away"
				)
	elif kind == LAN_EVENT.Kind.DAMAGE_CONFIRMED and subject == LAN_EVENT.Subject.TORNADO:
		if integer_values.size() >= 2:
			var target := _get_lan_character(actor_peer_id)
			if is_instance_valid(target):
				target.set_authoritative_health(integer_values[0])
				if actor_peer_id == lan_session.get_local_peer_id() and not vector_values.is_empty():
					var impulse := vector_values[0]
					target.apply_external_push(impulse.normalized(), impulse.length())
					if integer_values[1] != 0:
						_on_tornado_player_captured()
	elif kind == LAN_EVENT.Kind.DAMAGE_CONFIRMED and subject == LAN_EVENT.Subject.BATEBALL:
		if integer_values.size() >= 2:
			var bateball_target := _get_lan_character(actor_peer_id)
			if is_instance_valid(bateball_target):
				bateball_target.set_authoritative_health(integer_values[0])
				var respawned := integer_values[1] != 0
				if respawned and not vector_values.is_empty():
					bateball_target.global_position = vector_values[0]
				if integer_values[0] <= 0:
					bateball_target.controls_enabled = false
				elif respawned:
					bateball_target.controls_enabled = (
						actor_peer_id == lan_session.get_local_peer_id()
						and round_controller.phase == LocalRoundController.Phase.ACTIVE
					)
	elif kind == LAN_EVENT.Kind.DAMAGE_CONFIRMED and subject == LAN_EVENT.Subject.SHOOTER:
		if integer_values.size() >= 2:
			var shooter_target := _get_lan_character(actor_peer_id)
			if is_instance_valid(shooter_target):
				shooter_host.apply_authoritative_character_state(
					shooter_target,
					integer_values[0],
					integer_values[1] != 0,
					vector_values[0] if not vector_values.is_empty() else shooter_target.global_position
				)
	elif kind == LAN_EVENT.Kind.SCORE_CHANGED and subject == LAN_EVENT.Subject.SHOOTER:
		if integer_values.size() >= 2:
			var ids := PackedInt32Array()
			var kills := PackedInt32Array()
			var index := 2
			while index + 1 < integer_values.size():
				ids.append(integer_values[index])
				kills.append(integer_values[index + 1])
				index += 2
			shooter_host.apply_authoritative_classification(
				ids, kills, integer_values[0] != 0
			)
	elif kind == LAN_EVENT.Kind.WEAPON_STATE and subject == LAN_EVENT.Subject.SHOOTER:
		if (
			integer_values.size() >= 3
			and actor_peer_id == lan_session.get_local_peer_id()
		):
			shooter_host.apply_authoritative_weapon_state(
				integer_values[0], integer_values[1] != 0, integer_values[2]
			)
	elif kind == LAN_EVENT.Kind.HIT_CONFIRMED and subject == LAN_EVENT.Subject.SHOOTER:
		if (
			not integer_values.is_empty()
			and actor_peer_id == lan_session.get_local_peer_id()
		):
			_on_shooter_hit_confirmed(integer_values[0])
	elif kind == LAN_EVENT.Kind.ROUND_COMPLETED and subject == LAN_EVENT.Subject.TORNADO:
		tornado_host.apply_authoritative_completion(
			integer_values[0] if not integer_values.is_empty() else 0
		)


func _apply_pending_round_state() -> void:
	if _pending_crown_holder_peer < 0 or not crown_host.is_active():
		pass
	else:
		var crown_holder := _get_lan_character(_pending_crown_holder_peer)
		crown_host.apply_authoritative_holder(crown_holder)
		_pending_crown_holder_peer = -1
	if _pending_bomb_holder_peer >= 0 and bomb_host.is_active():
		var bomb_holder := _get_lan_character(_pending_bomb_holder_peer)
		bomb_host.apply_authoritative_holder(
			bomb_holder, _pending_bomb_remaining_msec
		)
		_pending_bomb_holder_peer = -1
	if _pending_bateball_holder_peer >= 0 and bateball_host.is_active():
		var bateball_holder := _get_lan_character(_pending_bateball_holder_peer)
		bateball_host.apply_authoritative_holder(bateball_holder)
		_pending_bateball_holder_peer = -1


func _on_local_bomb_holder_peer_changed(peer_id: int, remaining_msec: int) -> void:
	if lan_session != null and lan_session.is_active() and lan_session.is_host:
		lan_session.broadcast_round_event(
			LAN_EVENT.Kind.HOLDER_CHANGED,
			LAN_EVENT.Subject.BOMB,
			peer_id,
			PackedInt32Array([remaining_msec])
		)


func _on_local_bomb_explosion_authorized(peer_id: int, position_value: Vector3) -> void:
	if lan_session != null and lan_session.is_active() and lan_session.is_host:
		lan_session.broadcast_round_event(
			LAN_EVENT.Kind.ROUND_COMPLETED,
			LAN_EVENT.Subject.BOMB,
			peer_id,
			PackedInt32Array(),
			PackedVector3Array([position_value])
		)


func _get_lan_character(peer_id: int) -> LocalBaseCharacter:
	if peer_id == 0:
		return null
	if lan_session != null and peer_id == lan_session.get_local_peer_id():
		return player
	return _lan_remotes.get(peer_id) as LocalBaseCharacter


func _find_round_body(object_name: String) -> RigidBody3D:
	for object in get_tree().get_nodes_in_group(&"local_round_object"):
		if object is RigidBody3D and object.name == object_name and map_host.is_ancestor_of(object):
			return object as RigidBody3D
	return null


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
		"CUENTA ATRÁS",
		"JUGANDO",
		"RESULTADO",
		"LIMPIANDO",
	]
	_update_round_clock(next_phase, phase_labels[next_phase], seconds)
	var gameplay_active := next_phase == LocalRoundController.Phase.ACTIVE
	joystick.set_input_enabled(gameplay_active)
	look_pad.set_input_enabled(gameplay_active)
	jump_button.visible = gameplay_active
	shoot_button.visible = gameplay_active and _is_shooter_game()
	if not shoot_button.visible:
		shooter_host.set_trigger_held(false)
	reload_button.visible = gameplay_active and _is_shooter_game()
	foot_button.visible = (
		gameplay_active
		and _selected_minigame_id == &"futbol_rebote"
		and player.is_foot_action_available()
	)
	hand_button.visible = (
		gameplay_active
		and _can_show_hand_action()
		and player.is_hand_action_available()
	)
	crosshair.visible = (
		_selected_minigame_id in [&"futbol_rebote", &"shooter_local"]
		and next_phase in [
			LocalRoundController.Phase.RULES,
			LocalRoundController.Phase.COUNTDOWN,
			LocalRoundController.Phase.ACTIVE,
		]
	)
	match next_phase:
		LocalRoundController.Phase.IDLE:
			if _launched_from_room and _match_has_started:
				round_button.set_label("VOLVER A LA SALA")
				round_button.show()
			else:
				round_button.set_label("JUGAR")
				round_button.show()
			banner_title.text = _minigame_title()
			banner_detail.text = "La partida terminó. Vuelve a la sala para elegir de nuevo." if _launched_from_room and _match_has_started else "Pulsa JUGAR para iniciar"
			banner_progress.text = "Dos arcos · paredes · primero a 3" if _selected_minigame_id == &"futbol_rebote" else "Vista aérea · primero a 2" if _is_bateball_game() else "Cinco eliminaciones · cargador y recarga" if _is_shooter_game() else "Una sola regla clara, una ronda limpia"
			_on_player_metrics(player.get_diagnostics())
		LocalRoundController.Phase.PREPARE:
			call_deferred("_position_lan_teams")
			round_button.hide()
			banner_title.text = "PREPARANDO %s" % _minigame_title()
			banner_detail.text = "La corona espera en el centro" if _is_crown_game() else "La bomba empieza en tus manos" if _is_bomb_game() else "El tornado se forma en la arena" if _is_tornado_game() else "La arena aérea carga el balón" if _is_bateball_game() else "El campo de tiro prepara coberturas" if _is_shooter_game() else "El balón caerá en el centro"
			banner_progress.text = "Todos corren a la misma velocidad" if _is_crown_game() else "El contacto entrega la bomba" if _is_bomb_game() else "Objetos y jugadores serán arrastrados" if _is_tornado_game() else "Arrastra a la derecha para apuntar · suelta para actuar" if _is_bateball_game() else "Primera persona · daño hitscan · tres armas" if _is_shooter_game() else "La patada sigue al cuerpo, no a la cámara"
		LocalRoundController.Phase.RULES:
			banner_title.text = "CORONA CENTRAL" if _is_crown_game() else "BOMBA DE RELEVO" if _is_bomb_game() else "TORNADO DE OBJETOS" if _is_tornado_game() else "BATEBALL ARENA" if _is_bateball_game() else "ARENA DE TIRO" if _is_shooter_game() else "FÚTBOL · DOS ARCOS"
			banner_detail.text = "Toma la corona y evita que te la quiten" if _is_crown_game() else "Toca a otro jugador para pasar la bomba" if _is_bomb_game() else "Mantente lejos del embudo y de los objetos" if _is_tornado_game() else "Recoge el balón y apunta para disparar" if _is_bateball_game() else "Usa coberturas y alcanza cinco eliminaciones" if _is_shooter_game() else "Marca en el arco rival y defiende el tuyo"
			banner_progress.text = "El contacto roba la corona" if _is_crown_game() else "La mecha acelera al acercarse el final" if _is_bomb_game() else "El contacto daña; el tornado te puede lanzar" if _is_tornado_game() else "Bate cargado empuja y hace soltar el balón" if _is_bateball_game() else "DISPARAR consume munición · RECARGAR llena el cargador" if _is_shooter_game() else "La pelota rebota en las paredes"
		LocalRoundController.Phase.COUNTDOWN:
			_update_countdown_title(seconds)
			banner_detail.text = "Corre hacia el círculo central" if _is_crown_game() else "Sujeta la bomba con las dos manos" if _is_bomb_game() else "Los objetos empezarán a volar" if _is_tornado_game() else "El balón aparece en el centro" if _is_bateball_game() else "Busca cobertura antes del primer disparo" if _is_shooter_game() else "Muévete para colocarte detrás del balón"
			banner_progress.text = "La corona aparece al centro" if _is_crown_game() else "No dejes que termine la mecha" if _is_bomb_game() else "Sobrevive con vida" if _is_tornado_game() else "El BATE se carga tras cada golpe" if _is_bateball_game() else "La mira central marca la dirección real" if _is_shooter_game() else "La mira es orientativa; el pie usa tu orientación"
		LocalRoundController.Phase.ACTIVE:
			call_deferred("_apply_pending_round_state")
			banner_title.text = "¡CORONA!" if _is_crown_game() else "¡BOMBA!" if _is_bomb_game() else "¡TORNADO!" if _is_tornado_game() else "¡BATEBALL!" if _is_bateball_game() else "¡COMBATE!" if _is_shooter_game() else "¡JUGAR!"
			banner_detail.text = "Consigue la corona" if _is_crown_game() else "Pásala al tocar a otro jugador" if _is_bomb_game() else "Evita el embudo y los objetos proyectados" if _is_tornado_game() else "Recoge, apunta y dispara al arco rival" if _is_bateball_game() else "Apunta al cuerpo visible y controla tu cargador" if _is_shooter_game() else "PATEA al arco rival · protege el tuyo"
			banner_progress.text = "CORONA: %s" % crown_host.get_holder_name() if _is_crown_game() else "BOMBA: %.1f s" % bomb_host.get_remaining() if _is_bomb_game() else "VIDA %d/100 · %.1f s" % [player.get_local_health(), tornado_host.get_remaining()] if _is_tornado_game() else _bateball_score_text() if _is_bateball_game() else _shooter_progress_text() if _is_shooter_game() else _score_text()
		LocalRoundController.Phase.RESULT:
			var winner: int = crown_host.get_winner() if _is_crown_game() else bomb_host.get_winner() if _is_bomb_game() else tornado_host.get_winner() if _is_tornado_game() else bateball_host.get_winner() if _is_bateball_game() else shooter_host.get_winner() if _is_shooter_game() else football_host.get_winner()
			_show_round_result(winner)
		LocalRoundController.Phase.CLEANUP:
			banner_title.text = "LIMPIANDO %s" % _minigame_title()
			banner_detail.text = "Retirando mapa, objetos y estados de la ronda"
			banner_progress.text = "Volviendo a la sala sin residuos"


func _on_round_phase_time_changed(
	current_phase: LocalRoundController.Phase,
	remaining_seconds: float
) -> void:
	if current_phase != round_controller.phase:
		return
	var phase_labels := [
		"LISTA", "PREPARANDO", "REGLAS", "CUENTA ATRÁS",
		"JUGANDO", "RESULTADO", "LIMPIANDO",
	]
	_update_round_clock(current_phase, phase_labels[current_phase], remaining_seconds)
	if current_phase == LocalRoundController.Phase.COUNTDOWN:
		_update_countdown_title(remaining_seconds)


func _update_round_clock(
	current_phase: LocalRoundController.Phase,
	phase_label: String,
	remaining_seconds: float
) -> void:
	if current_phase == LocalRoundController.Phase.IDLE:
		round_label.text = "%s  ·  LISTO" % _minigame_title()
	elif current_phase == LocalRoundController.Phase.COUNTDOWN:
		round_label.text = "%s  ·  %s  ·  %d" % [
			_minigame_title(), phase_label, maxi(1, ceili(remaining_seconds)),
		]
	else:
		round_label.text = "%s  ·  %s  ·  %.1f s" % [
			_minigame_title(), phase_label, maxf(0.0, remaining_seconds),
		]


func _update_countdown_title(remaining_seconds: float) -> void:
	var prefix := (
		"CORONA" if _is_crown_game()
		else "BOMBA" if _is_bomb_game()
		else "TORNADO" if _is_tornado_game()
		else "BATEBALL" if _is_bateball_game()
		else "COMBATE" if _is_shooter_game()
		else "SAQUE"
	)
	banner_title.text = "%s · %d" % [prefix, maxi(1, ceili(remaining_seconds))]


func _show_round_result(winner: int) -> void:
	if _is_crown_game():
		var holder_name: String = str(crown_host.get_holder_name())
		banner_title.text = (
			"¡CONSERVASTE LA CORONA!" if winner > 0
			else "EMPATE · NADIE TOMÓ LA CORONA" if winner == 0
			else "GANÓ %s" % holder_name
		)
		banner_detail.text = "Ganó quien conservó la corona al terminar el tiempo"
		banner_progress.text = "PORTADOR FINAL: %s" % holder_name
	elif _is_bomb_game():
		banner_title.text = "¡TE EXPLOTÓ LA BOMBA!" if winner < 0 else "¡SOBREVIVISTE!"
		banner_detail.text = "%s quedó con la bomba al terminar la mecha" % bomb_host.get_holder_name()
		banner_progress.text = "La explosión terminó la ronda"
	elif _is_tornado_game():
		banner_title.text = "¡SOBREVIVISTE!" if winner > 0 else "ELIMINADO"
		banner_detail.text = "La ronda terminó por tiempo o al caer todos"
		banner_progress.text = "VIDA FINAL %d/100" % player.get_local_health()
	elif _is_shooter_game():
		banner_title.text = "¡VICTORIA!" if winner > 0 else "DERROTA" if winner < 0 else "EMPATE"
		banner_detail.text = "Terminó el combate individual"
		banner_progress.text = _shooter_progress_text()
	else:
		banner_title.text = "¡GANÓ TU EQUIPO!" if winner > 0 else "GANÓ EL EQUIPO RIVAL" if winner < 0 else "EMPATE"
		banner_detail.text = "Resultado oficial del partido"
		banner_progress.text = _bateball_score_text() if _is_bateball_game() else _score_text()


func _score_text() -> String:
	return "TU EQUIPO %d  ·  RIVAL %d  ·  PRIMERO A %d" % [
		football_host.get_local_score(),
		football_host.get_rival_score(),
		football_host.target_score,
	]


func _bateball_score_text() -> String:
	return "EQUIPO %d-%d · VIDA %d · BATE %d%%" % [
		bateball_host.get_local_score(),
		bateball_host.get_rival_score(),
		player.get_local_health(),
		round(player.get_bat_charge_ratio() * 100.0),
	]


func _shooter_progress_text() -> String:
	return "BAJAS %d-%d · VIDA %d · %s %d/%d" % [
		shooter_host.score,
		shooter_host.opponent_score,
		player.get_local_health(),
		WEAPONS.display_name(shooter_host.get_weapon_id()).get_slice(" · ", 0),
		shooter_host.get_ammo(),
		WEAPONS.magazine_size(shooter_host.get_weapon_id()),
	]


func _on_football_score_changed(
	_home_score: int,
	_away_score: int,
	_target: int
) -> void:
	banner_progress.text = _score_text()
	_broadcast_football_state(-1)


func _broadcast_football_state(scoring_side: int) -> void:
	if lan_session != null and lan_session.is_active() and lan_session.is_host:
		lan_session.broadcast_round_event(
			LAN_EVENT.Kind.SCORE_CHANGED,
			LAN_EVENT.Subject.FOOTBALL,
			0,
			PackedInt32Array([
				football_host.score,
				football_host.opponent_score,
				1 if football_host.is_complete() else 0,
				football_host.get_penalty_winner_home(),
				scoring_side,
			])
		)


func _on_goal_scored(scoring_side: StringName) -> void:
	_show_football_goal(scoring_side)
	_broadcast_football_state(0 if scoring_side == &"home" else 1)


func _show_football_goal(scoring_side: StringName) -> void:
	banner_detail.text = (
		"¡GOL TUYO! El balón vuelve al centro"
		if scoring_side == football_host.get_player_team()
		else "¡GOL DEL RIVAL! El balón vuelve al centro"
	)


func _on_kickoff_ready() -> void:
	if round_controller.phase != LocalRoundController.Phase.ACTIVE:
		return
	player.set_spawn_transform(map_host.get_spawn_transform(round_controller.player_slot))
	var facing := map_host.get_team_facing_for_slot(round_controller.player_slot)
	player.set_facing_direction(facing)
	player.set_view_direction(facing)
	banner_detail.text = "Saque desde el centro"


func _position_lan_teams() -> void:
	if lan_session == null:
		return
	var local_slot: int = int(lan_session.get_local_slot())
	if map_host.has_team_layout():
		var local_team := map_host.get_team_for_slot(local_slot)
		player.set_meta(&"football_team", local_team)
		player.set_meta(&"bateball_team", local_team)
		player.set_team(local_team)
	player.set_spawn_transform(map_host.get_spawn_transform(local_slot))
	player.set_view_direction(map_host.get_team_facing_for_slot(local_slot))
	for peer_id: Variant in _lan_remotes:
		var remote: LocalBaseCharacter = _lan_remotes[peer_id]
		if not is_instance_valid(remote):
			continue
		var slot: int = int(lan_session.get_peer_slot(int(peer_id)))
		if map_host.has_team_layout():
			var team := map_host.get_team_for_slot(slot)
			remote.set_meta(&"football_team", team)
			remote.set_meta(&"bateball_team", team)
			remote.set_team(team)
		remote.global_transform = map_host.get_spawn_transform(slot)
		var facing := map_host.get_team_facing_for_slot(slot)
		remote.set_facing_direction(facing)
		remote.set_view_direction(facing)


func _on_crown_holder_changed(holder_name: String) -> void:
	if _is_crown_game():
		if holder_name == "NADIE":
			banner_detail.text = "La corona está libre en el centro"
			banner_progress.text = "CORONA LIBRE"
		else:
			banner_detail.text = "%s tiene la corona" % holder_name
			banner_progress.text = "CORONA: %s" % holder_name


func _on_crown_match_completed(holder_name: String) -> void:
	if _is_crown_game():
		banner_detail.text = "%s conserva la corona" % holder_name


func _on_bomb_holder_changed(holder_name: String) -> void:
	if _is_bomb_game():
		banner_detail.text = "%s lleva la bomba" % holder_name
		hand_button.visible = (
			_can_show_hand_action()
			and player.is_hand_action_available()
			and round_controller.phase == LocalRoundController.Phase.ACTIVE
		)


func _on_bomb_timer_changed(remaining: float) -> void:
	if _is_bomb_game() and round_controller.phase == LocalRoundController.Phase.ACTIVE:
		banner_progress.text = "BOMBA: %.1f s · el pitido acelera" % remaining


func _on_bomb_exploded(holder_name: String) -> void:
	if _is_bomb_game():
		banner_title.text = "¡BOOM!"
		banner_detail.text = "%s quedó con la bomba" % holder_name


func _on_hand_action() -> void:
	if not player.request_hand_action():
		hand_button.hide()


func _on_hand_action_availability_changed(label: String, available: bool) -> void:
	hand_button.set_label(label if available else "EMPUJAR")
	hand_button.visible = (
		available
		and _can_show_hand_action()
		and round_controller.phase == LocalRoundController.Phase.ACTIVE
	)


func _can_show_hand_action() -> bool:
	if _is_bateball_game() or _is_shooter_game():
		return false
	if _is_bomb_game() and bomb_host.is_holder(player):
		return false
	return true


func _on_foot_action() -> void:
	if not player.request_foot_action():
		foot_button.hide()


func _on_foot_action_changed(label: String, available: bool) -> void:
	foot_button.set_label(label if available else "PATEAR")
	foot_button.visible = (
		available
		and _selected_minigame_id == &"futbol_rebote"
		and round_controller.phase == LocalRoundController.Phase.ACTIVE
	)


func _on_shooter_shoot() -> void:
	if _is_shooter_game():
		shooter_host.set_trigger_held(true)
		shooter_host.request_shot()


func _on_shooter_shoot_released() -> void:
	shooter_host.set_trigger_held(false)


func _on_shooter_reload() -> void:
	if _is_shooter_game():
		shooter_host.request_reload()


func _on_shooter_score_changed(_player_score: int, _rival_score: int, _target: int) -> void:
	if _is_shooter_game():
		banner_progress.text = _shooter_progress_text()


func _on_shooter_ammo_changed(_current: int, _maximum: int, reloading: bool) -> void:
	if not _is_shooter_game():
		return
	reload_button.set_label("RECARGANDO" if reloading else "RECARGAR")
	banner_progress.text = _shooter_progress_text()


func _on_shooter_combat_message(text: String) -> void:
	if _is_shooter_game() and round_controller.phase == LocalRoundController.Phase.ACTIVE:
		banner_detail.text = text


func _on_shooter_hit_confirmed(_remaining_health: int) -> void:
	if not _is_shooter_game():
		return
	crosshair.modulate = Color(1.0, 0.2, 0.12)
	var tween := create_tween()
	tween.tween_property(crosshair, "modulate", Color.WHITE, 0.16)


func _on_local_shooter_shot_requested(direction: Vector3) -> void:
	if lan_session != null and lan_session.is_active() and not lan_session.is_host:
		lan_session.request_action(LAN_EVENT.Action.SHOOTER_SHOT, 0, direction)


func _on_local_shooter_reload_requested() -> void:
	if lan_session != null and lan_session.is_active() and not lan_session.is_host:
		lan_session.request_action(LAN_EVENT.Action.SHOOTER_RELOAD, 0, Vector3.ZERO)


func _on_shooter_shot_authorized(peer_id: int, direction: Vector3) -> void:
	if lan_session != null and lan_session.is_active() and lan_session.is_host:
		lan_session.broadcast_action(
			peer_id, LAN_EVENT.Action.SHOOTER_SHOT, direction
		)


func _on_shooter_health_authorized(
	peer_id: int,
	health: int,
	respawned: bool,
	position_value: Vector3
) -> void:
	if lan_session != null and lan_session.is_active() and lan_session.is_host:
		lan_session.broadcast_round_event(
			LAN_EVENT.Kind.DAMAGE_CONFIRMED,
			LAN_EVENT.Subject.SHOOTER,
			peer_id,
			PackedInt32Array([health, 1 if respawned else 0]),
			PackedVector3Array([position_value])
		)


func _on_shooter_weapon_state_authorized(
	peer_id: int,
	ammo: int,
	reloading: bool,
	remaining_msec: int
) -> void:
	if lan_session != null and lan_session.is_active() and lan_session.is_host:
		lan_session.broadcast_round_event(
			LAN_EVENT.Kind.WEAPON_STATE,
			LAN_EVENT.Subject.SHOOTER,
			peer_id,
			PackedInt32Array([ammo, 1 if reloading else 0, remaining_msec])
		)


func _on_shooter_hit_authorized(peer_id: int, remaining_health: int) -> void:
	if lan_session != null and lan_session.is_active() and lan_session.is_host:
		lan_session.broadcast_round_event(
			LAN_EVENT.Kind.HIT_CONFIRMED,
			LAN_EVENT.Subject.SHOOTER,
			peer_id,
			PackedInt32Array([remaining_health])
		)


func _on_shooter_classification_authorized(
	peer_ids: PackedInt32Array,
	kills: PackedInt32Array,
	complete: bool,
	winner_peer_id: int
) -> void:
	if lan_session == null or not lan_session.is_active() or not lan_session.is_host:
		return
	var values := PackedInt32Array([1 if complete else 0, winner_peer_id])
	for index in mini(peer_ids.size(), kills.size()):
		values.append(peer_ids[index])
		values.append(kills[index])
	lan_session.broadcast_round_event(
		LAN_EVENT.Kind.SCORE_CHANGED,
		LAN_EVENT.Subject.SHOOTER,
		winner_peer_id,
		values
	)


func _on_aim_changed(value: Vector2, active: bool) -> void:
	if not _is_bateball_game():
		return
	_aim_active = active
	if value.length_squared() > 0.02:
		_aim_value = value.normalized()
	player.set_top_down_aim(_aim_value, active)


func _on_aim_released(value: Vector2) -> void:
	if not _is_bateball_game() or round_controller.phase != LocalRoundController.Phase.ACTIVE:
		return
	player.set_top_down_aim(value, false)
	var direction := player.get_top_down_aim_direction()
	player.set_facing_direction(direction)
	if bateball_host.is_holder(player):
		if bateball_host.request_ball_shot(player, direction):
			if lan_session != null and lan_session.is_active() and not lan_session.is_host:
				lan_session.request_bateball_shot(direction)
	else:
		player.request_bat_swing()


func _build_aim_guide() -> void:
	_aim_fill = Polygon2D.new()
	_aim_fill.name = "AimArea"
	_aim_fill.z_index = 18
	$HUD.add_child(_aim_fill)
	_aim_line = Line2D.new()
	_aim_line.name = "AimLine"
	_aim_line.width = 4.0
	_aim_line.antialiased = true
	_aim_line.z_index = 19
	$HUD.add_child(_aim_line)
	_update_aim_guide()


func _update_aim_guide() -> void:
	if _aim_line == null or _aim_fill == null:
		return
	var show_guide := (
		_is_bateball_game()
		and _aim_active
		and round_controller.phase == LocalRoundController.Phase.ACTIVE
	)
	_aim_line.visible = show_guide
	_aim_fill.visible = show_guide
	if not show_guide:
		return
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return
	var start := camera.unproject_position(player.global_position + Vector3.UP * 0.48)
	var direction := _aim_value.normalized()
	var perpendicular := Vector2(-direction.y, direction.x)
	var has_ball: bool = bool(bateball_host.is_holder(player))
	var length := 180.0 if has_ball else 112.0
	var finish := start + direction * length
	_aim_line.default_color = Color(0.28, 0.9, 1.0, 0.96) if has_ball else Color(1.0, 0.58, 0.15, 0.96)
	_aim_line.points = PackedVector2Array([start, finish])
	if has_ball:
		_aim_fill.color = Color(0.28, 0.9, 1.0, 0.42)
		_aim_fill.polygon = PackedVector2Array([
			start + perpendicular * 5.0,
			finish - direction * 9.0 + perpendicular * 9.0,
			finish + direction * 15.0,
			finish - direction * 9.0 - perpendicular * 9.0,
			start - perpendicular * 5.0,
		])
	else:
		var half_angle := 0.68
		_aim_fill.color = Color(1.0, 0.48, 0.1, 0.2)
		_aim_fill.polygon = PackedVector2Array([
			start,
			start + direction.rotated(-half_angle) * length,
			start + direction.rotated(half_angle) * length,
		])


func _on_bateball_score_changed(_home: int, _away: int, _target: int) -> void:
	if _is_bateball_game():
		banner_progress.text = _bateball_score_text()


func _broadcast_bateball_score(scoring_side: int) -> void:
	if lan_session != null and lan_session.is_active() and lan_session.is_host:
		lan_session.broadcast_round_event(
			LAN_EVENT.Kind.SCORE_CHANGED,
			LAN_EVENT.Subject.BATEBALL,
			0,
			PackedInt32Array([
				bateball_host.score,
				bateball_host.opponent_score,
				1 if bateball_host.is_complete() else 0,
				scoring_side,
			])
		)


func _on_bateball_holder_changed(holder_name: String) -> void:
	if _is_bateball_game() and round_controller.phase == LocalRoundController.Phase.ACTIVE:
		banner_detail.text = (
			"BALÓN SUELTO · ve por él"
			if holder_name == "NADIE"
			else "%s lleva el balón" % holder_name
		)


func _on_bateball_goal_scored(scoring_side: StringName) -> void:
	if _is_bateball_game():
		_show_bateball_goal(scoring_side)
		_broadcast_bateball_score(0 if scoring_side == &"home" else 1)


func _show_bateball_goal(scoring_side: StringName) -> void:
	banner_detail.text = (
		"¡GOL DE TU EQUIPO!"
		if scoring_side == bateball_host.get_local_team()
		else "¡GOL DEL EQUIPO RIVAL!"
	)


func _on_bat_charge_changed(_ratio: float, _charged: bool) -> void:
	if _is_bateball_game() and round_controller.phase == LocalRoundController.Phase.ACTIVE:
		banner_progress.text = _bateball_score_text()


func _on_local_player_health_changed(current: int, _maximum: int) -> void:
	if current < _last_local_health:
		_play_damage_flash()
	_last_local_health = current
	if _is_bateball_game() and round_controller.phase == LocalRoundController.Phase.ACTIVE:
		banner_progress.text = _bateball_score_text()
	elif _is_shooter_game() and round_controller.phase == LocalRoundController.Phase.ACTIVE:
		banner_progress.text = _shooter_progress_text()


func _play_damage_flash() -> void:
	if is_instance_valid(_damage_tween):
		_damage_tween.kill()
	damage_flash.visible = true
	damage_flash.color.a = 0.2
	_damage_tween = create_tween()
	_damage_tween.tween_property(damage_flash, "color:a", 0.0, 0.28)
	_damage_tween.tween_callback(damage_flash.hide)


func _on_bateball_character_health_authorized(
	peer_id: int,
	health: int,
	respawned: bool,
	position_value: Vector3
) -> void:
	if lan_session != null and lan_session.is_active() and lan_session.is_host:
		lan_session.broadcast_round_event(
			LAN_EVENT.Kind.DAMAGE_CONFIRMED,
			LAN_EVENT.Subject.BATEBALL,
			peer_id,
			PackedInt32Array([health, 1 if respawned else 0]),
			PackedVector3Array([position_value])
		)


func _on_bateball_impact_authorized(
	attacker_peer_id: int,
	target_peer_id: int,
	direction: Vector3
) -> void:
	if lan_session != null and lan_session.is_active() and lan_session.is_host:
		lan_session.broadcast_action(
			attacker_peer_id,
			LAN_EVENT.Action.BATEBALL_IMPACT,
			direction,
			true,
			target_peer_id
		)


func _on_tornado_timer_changed(remaining: float) -> void:
	if _is_tornado_game() and round_controller.phase == LocalRoundController.Phase.ACTIVE:
		banner_progress.text = "VIDA %d/100 · %.1f s" % [player.get_local_health(), remaining]


func _on_tornado_health_changed(current: int, maximum: int) -> void:
	if _is_tornado_game():
		banner_detail.text = "El tornado te atrapó · %d/%d vida" % [current, maximum]


func _on_tornado_player_captured() -> void:
	if _is_tornado_game():
		banner_title.text = "¡ARRASTRADO!"


func _on_tornado_character_health_authorized(
	peer_id: int,
	health: int,
	impulse: Vector3,
	captured: bool
) -> void:
	if lan_session != null and lan_session.is_active() and lan_session.is_host:
		lan_session.broadcast_round_event(
			LAN_EVENT.Kind.DAMAGE_CONFIRMED,
			LAN_EVENT.Subject.TORNADO,
			peer_id,
			PackedInt32Array([health, 1 if captured else 0]),
			PackedVector3Array([impulse])
		)


func _on_tornado_round_completed_authorized(remaining_msec: int) -> void:
	if lan_session != null and lan_session.is_active() and lan_session.is_host:
		lan_session.broadcast_round_event(
			LAN_EVENT.Kind.ROUND_COMPLETED,
			LAN_EVENT.Subject.TORNADO,
			0,
			PackedInt32Array([remaining_msec])
		)


func _is_crown_game() -> bool:
	return _selected_minigame_id == &"corona_central"


func _is_bomb_game() -> bool:
	return _selected_minigame_id == &"bomba_relevo"


func _is_tornado_game() -> bool:
	return _selected_minigame_id == &"tornado_supervivencia"


func _is_bateball_game() -> bool:
	return _selected_minigame_id == &"bateball_arena"


func _is_shooter_game() -> bool:
	return _selected_minigame_id == &"shooter_local"


func _minigame_title() -> String:
	return "CORONA CENTRAL" if _is_crown_game() else "BOMBA DE RELEVO" if _is_bomb_game() else "TORNADO" if _is_tornado_game() else "BATEBALL" if _is_bateball_game() else "ARENA DE TIRO" if _is_shooter_game() else "FÚTBOL"


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
	round_label.text = "%s · PENALES · TIRO %d/5" % [_minigame_title(), attempt]
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
	banner_progress.text = "PENALES  TU EQUIPO %d · RIVAL %d · TIRO %d/5" % [home, away, attempt]


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
	var footprint := _selected_map.footprint if _selected_map != null else Vector2(size, size)
	area_label.text = "ISLA %d × %d m  ·  ESCENARIO %d × %d m" % [
		int(SCALE.ISLAND_SIZE),
		int(SCALE.ISLAND_SIZE),
		int(footprint.x),
		int(footprint.y),
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
