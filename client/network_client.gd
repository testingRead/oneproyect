class_name OneProjectNetwork
extends Node

signal status_changed(text: String, online: bool)
signal peers_changed(current: int, maximum: int)
signal remote_player_joined(player_id: int, display_name: String, color_index: int)
signal remote_player_left(player_id: int)
signal owned_state_confirmed(sequence: int, server_tick: int)
signal remote_snapshot(
	player_id: int,
	position: Vector3,
	velocity: Vector3,
	facing_yaw: float,
	body_mask: int
)
signal meteor_received(target: Vector3, drift: Vector2, damage: int, blast_force: float)
signal shockwave_received
signal round_state_received(
	state: int,
	round_number: int,
	time_left: float,
	mode_id: String,
	map_id: String,
	round_seed: int,
	feature_ids: PackedStringArray,
	player_profile_id: String,
	spawn_policy_id: String,
	spectator_policy_id: String
)
signal simulation_host_changed(peer_id: int)
signal push_received(sender_id: int, direction: Vector3, force: float)
signal session_resumed(player_id: int)
signal remote_session_suspended(player_id: int)
signal lobby_ready(maximum_rooms: int, maximum_players: int)
signal room_list_updated(
	room_ids: PackedInt32Array,
	player_counts: PackedInt32Array,
	phases: PackedInt32Array,
	host_names: PackedStringArray
)
signal room_waiting_updated(
	room_id: int,
	player_count: int,
	is_host: bool,
	ready_count: int,
	local_ready: bool,
	all_ready: bool,
	player_names: PackedStringArray,
	ready_flags: PackedByteArray
)
signal room_started(room_id: int)
signal room_action_failed(reason: String)
signal returned_to_lobby

const NET := preload("res://shared/net_constants.gd")
const CODEC := preload("res://shared/net_codec.gd")
const IDENTITY_PATH := "user://network_identity.cfg"

var server_address := "149.50.152.250"
var server_port := NET.DEFAULT_PORT
var display_name := ""
var color_index := 0

var _players: Dictionary = {}
var _online := false
var _session_accepted := false
var _manual_disconnect := true
var _reconnect_pending := false
var _reconnect_elapsed := 0.0
var _local_player_id := 0
var _local_spawn_position := Vector3(0.0, NET.FLOOR_HEIGHT, 8.0)
var _room_id := 0
var _state_sequence := 0
var _state_packet := PackedByteArray()
var _stable_id := ""
var _reconnect_token := ""
var _persist_identity := true
var _lobby_mode := false


func _ready() -> void:
	server_address = str(ProjectSettings.get_setting("network/server_address", server_address))
	server_port = int(ProjectSettings.get_setting("network/server_port", NET.DEFAULT_PORT))
	display_name = "Jugador%03d" % (randi() % 1000)
	color_index = randi() % 5
	_state_packet = CODEC.create_owned_state_buffer()
	_load_identity()
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)


func _process(delta: float) -> void:
	if not _reconnect_pending or _manual_disconnect:
		return
	_reconnect_elapsed -= delta
	if _reconnect_elapsed <= 0.0:
		_reconnect_elapsed = 2.0
		_start_client_peer(server_address)


func connect_to_server(address: String = "") -> Error:
	_lobby_mode = false
	_manual_disconnect = false
	_reconnect_pending = false
	var target := address.strip_edges()
	if target.is_empty():
		target = server_address
	server_address = target
	return _start_client_peer(target)


func connect_to_lobby(address: String = "") -> Error:
	_lobby_mode = true
	_room_id = 0
	_manual_disconnect = false
	_reconnect_pending = false
	var target := address.strip_edges()
	if target.is_empty():
		target = server_address
	server_address = target
	return _start_client_peer(target)


func request_room_list() -> void:
	if multiplayer.multiplayer_peer != null:
		_rpc_request_room_list.rpc_id(1)


func create_room() -> void:
	_rpc_create_room.rpc_id(
		1,
		_stable_id,
		_reconnect_token,
		display_name,
		color_index
	)


func join_room(room_id: int) -> void:
	if room_id <= 0:
		return
	_rpc_join_room.rpc_id(
		1,
		room_id,
		_stable_id,
		_reconnect_token,
		display_name,
		color_index
	)


func start_room() -> void:
	if _session_accepted:
		_rpc_start_room.rpc_id(1)


func set_room_profile(ready: bool) -> void:
	if _session_accepted:
		_rpc_set_room_profile.rpc_id(1, clampi(color_index, 0, 4), ready)


func leave_room() -> void:
	if _session_accepted:
		_rpc_leave_room.rpc_id(1)


func disconnect_session() -> void:
	_manual_disconnect = true
	_reconnect_pending = false
	_close_peer()
	_reset_runtime_state()
	status_changed.emit("MODO LOCAL", false)
	peers_changed.emit(1, NET.MAX_PLAYERS_PER_ROOM)


func is_online() -> bool:
	return _online and _session_accepted


func is_simulation_host() -> bool:
	return false


func get_player_count() -> int:
	var count := 0
	for player: Dictionary in _players.values():
		count += int(bool(player.get("connected", false)))
	return count


func get_local_player_id() -> int:
	return _local_player_id


func get_room_id() -> int:
	return _room_id


func get_local_spawn_position() -> Vector3:
	return _local_spawn_position


func replay_remote_players() -> void:
	for player_id: int in _players:
		if player_id == _local_player_id:
			continue
		var player: Dictionary = _players[player_id]
		if not bool(player.get("connected", false)):
			continue
		remote_player_joined.emit(
			player_id,
			str(player.get("name", "Jugador")),
			int(player.get("color", 0))
		)
		remote_snapshot.emit(
			player_id,
			player.get("position", Vector3(0.0, NET.FLOOR_HEIGHT, 8.0)),
			player.get("velocity", Vector3.ZERO),
			float(player.get("yaw", 0.0)),
			int(player.get("body_mask", NET.ALL_BODY_PARTS_MASK))
		)


func configure_test_identity(stable_id: String, reconnect_token := "") -> void:
	_persist_identity = false
	_stable_id = stable_id
	_reconnect_token = reconnect_token


func simulate_network_drop_for_test() -> void:
	if not is_online():
		return
	_online = false
	_session_accepted = false
	_manual_disconnect = false
	_reconnect_pending = true
	_reconnect_elapsed = 0.25
	for player: Dictionary in _players.values():
		player.connected = false
	_close_peer()


func submit_owned_state(
	position: Vector3,
	velocity: Vector3,
	facing_yaw: float,
	health: int,
	body_mask: int
) -> void:
	if not is_online():
		return
	_state_sequence += 1
	CODEC.write_owned_state(
		_state_packet,
		_state_sequence,
		position,
		velocity,
		facing_yaw,
		health,
		body_mask
	)
	_rpc_submit_owned_state.rpc_id(1, _state_packet)


func send_push(target_player_id: int, direction: Vector3, _force := 5.2) -> void:
	if not is_online() or target_player_id == _local_player_id:
		return
	_rpc_submit_push.rpc_id(1, target_player_id, direction)


func send_snapshot(_position: Vector3, _facing_yaw: float, _body_mask := 0) -> void:
	pass


func broadcast_meteor(
	_target: Vector3,
	_drift: Vector2,
	_damage: int,
	_blast_force: float
) -> void:
	pass


func broadcast_round_state(
	_state: int,
	_round_number: int,
	_time_left: float,
	_mode_id: String,
	_map_id: String,
	_round_seed: int,
	_feature_ids: PackedStringArray,
	_player_profile_id: String,
	_spawn_policy_id: String,
	_spectator_policy_id: String
) -> void:
	pass


func broadcast_shockwave() -> void:
	pass


@rpc("any_peer", "call_remote", "reliable", 0)
func _rpc_register_session(
	_stable_id_value: String,
	_reconnect_token_value: String,
	_requested_name: String,
	_requested_color: int
) -> void:
	pass


@rpc("any_peer", "call_remote", "reliable", 0)
func _rpc_enter_lobby() -> void:
	pass


@rpc("any_peer", "call_remote", "reliable", 0)
func _rpc_request_room_list() -> void:
	pass


@rpc("any_peer", "call_remote", "reliable", 0)
func _rpc_create_room(
	_stable_id_value: String,
	_reconnect_token_value: String,
	_requested_name: String,
	_requested_color: int
) -> void:
	pass


@rpc("any_peer", "call_remote", "reliable", 0)
func _rpc_join_room(
	_room_id_value: int,
	_stable_id_value: String,
	_reconnect_token_value: String,
	_requested_name: String,
	_requested_color: int
) -> void:
	pass


@rpc("any_peer", "call_remote", "reliable", 0)
func _rpc_start_room() -> void:
	pass


@rpc("any_peer", "call_remote", "reliable", 0)
func _rpc_set_room_profile(_character_index: int, _ready: bool) -> void:
	pass


@rpc("any_peer", "call_remote", "reliable", 0)
func _rpc_leave_room() -> void:
	pass


@rpc("any_peer", "call_remote", "unreliable_ordered", 1)
func _rpc_submit_owned_state(_packet: PackedByteArray) -> void:
	pass


@rpc("any_peer", "call_remote", "reliable", 2)
func _rpc_submit_push(_target_player_id: int, _direction: Vector3) -> void:
	pass


@rpc("authority", "call_remote", "reliable", 0)
func _rpc_session_accepted(
	player_id: int,
	reconnect_token: String,
	reconnected: bool,
	room_id: int,
	_server_tick: int
) -> void:
	_local_player_id = player_id
	_room_id = room_id
	_reconnect_token = reconnect_token
	_session_accepted = true
	_online = true
	_reconnect_pending = false
	_save_identity()
	status_changed.emit(
		"RECONECTADO · sala %d" % room_id if reconnected else "EN LÍNEA · sala %d" % room_id,
		true
	)
	if reconnected:
		session_resumed.emit(player_id)


@rpc("authority", "call_remote", "reliable", 0)
func _rpc_session_rejected(reason: String) -> void:
	status_changed.emit("SESIÓN RECHAZADA · %s" % reason, false)
	_manual_disconnect = true
	_reconnect_pending = false
	_close_peer()
	_reset_runtime_state()


@rpc("authority", "call_remote", "reliable", 0)
func _rpc_lobby_ready(maximum_rooms: int, maximum_players: int) -> void:
	status_changed.emit("LOBBY CONECTADO", false)
	lobby_ready.emit(maximum_rooms, maximum_players)


@rpc("authority", "call_remote", "reliable", 0)
func _rpc_room_list(
	room_ids: PackedInt32Array,
	player_counts: PackedInt32Array,
	phases: PackedInt32Array,
	host_names: PackedStringArray
) -> void:
	room_list_updated.emit(room_ids, player_counts, phases, host_names)


@rpc("authority", "call_remote", "reliable", 0)
func _rpc_room_waiting(
	room_id: int,
	player_count: int,
	host_player_id: int,
	ready_count: int,
	local_ready: bool,
	all_ready: bool,
	player_names: PackedStringArray,
	ready_flags: PackedByteArray
) -> void:
	_room_id = room_id
	status_changed.emit(
		"SALA %d · %d/%d JUGADORES" % [
			room_id,
			player_count,
			NET.MAX_PLAYERS_PER_ROOM,
		],
		true
	)
	room_waiting_updated.emit(
		room_id,
		player_count,
		host_player_id == _local_player_id,
		ready_count,
		local_ready,
		all_ready,
		player_names,
		ready_flags
	)


@rpc("authority", "call_remote", "reliable", 0)
func _rpc_room_started(room_id: int) -> void:
	if room_id == _room_id:
		room_started.emit(room_id)


@rpc("authority", "call_remote", "reliable", 0)
func _rpc_room_action_failed(reason: String) -> void:
	status_changed.emit("NO SE PUDO · %s" % reason, false)
	room_action_failed.emit(reason)


@rpc("authority", "call_remote", "reliable", 0)
func _rpc_returned_to_lobby() -> void:
	_players.clear()
	_session_accepted = false
	_room_id = 0
	_local_player_id = 0
	_lobby_mode = true
	status_changed.emit("LOBBY CONECTADO", false)
	returned_to_lobby.emit()


@rpc("authority", "call_remote", "reliable", 0)
func _rpc_player_joined(
	player_id: int,
	player_name: String,
	player_color: int,
	position: Vector3
) -> void:
	var already_known := _players.has(player_id)
	var was_connected := (
		bool(_players[player_id].get("connected", false))
		if already_known
		else false
	)
	var previous_yaw := (
		float(_players[player_id].get("yaw", 0.0))
		if already_known
		else 0.0
	)
	var previous_body_mask := (
		int(_players[player_id].get("body_mask", NET.ALL_BODY_PARTS_MASK))
		if already_known
		else NET.ALL_BODY_PARTS_MASK
	)
	_players[player_id] = {
		"name": player_name,
		"color": player_color,
		"connected": true,
		"position": position,
		"velocity": Vector3.ZERO,
		"yaw": previous_yaw,
		"body_mask": previous_body_mask,
	}
	if player_id == _local_player_id:
		_local_spawn_position = position
	if player_id != _local_player_id and (not already_known or not was_connected):
		remote_player_joined.emit(player_id, player_name, player_color)
		remote_snapshot.emit(
			player_id,
			position,
			Vector3.ZERO,
			0.0,
			NET.ALL_BODY_PARTS_MASK
		)
	peers_changed.emit(get_player_count(), NET.MAX_PLAYERS_PER_ROOM)


@rpc("authority", "call_remote", "reliable", 0)
func _rpc_player_left(player_id: int, temporary: bool) -> void:
	if not _players.has(player_id):
		return
	if temporary:
		_players[player_id].connected = false
		remote_session_suspended.emit(player_id)
	else:
		_players.erase(player_id)
		remote_player_left.emit(player_id)
	peers_changed.emit(get_player_count(), NET.MAX_PLAYERS_PER_ROOM)


@rpc("authority", "call_remote", "unreliable_ordered", 1)
func _rpc_receive_snapshot(packet: PackedByteArray) -> void:
	if not CODEC.is_valid_snapshot(packet):
		return
	var server_tick := CODEC.snapshot_server_tick(packet)
	for slot in CODEC.snapshot_player_count(packet):
		var player_id := CODEC.snapshot_player_id(packet, slot)
		var position := CODEC.snapshot_player_position(packet, slot)
		var velocity := CODEC.snapshot_player_velocity(packet, slot)
		var yaw := CODEC.snapshot_player_yaw(packet, slot)
		var body_mask := CODEC.snapshot_player_body_mask(packet, slot)
		if player_id == _local_player_id:
			_local_spawn_position = position
			owned_state_confirmed.emit(
				CODEC.snapshot_player_state_sequence(packet, slot),
				server_tick
			)
		else:
			if _players.has(player_id):
				_players[player_id].position = position
				_players[player_id].velocity = velocity
				_players[player_id].yaw = yaw
				_players[player_id].body_mask = body_mask
			remote_snapshot.emit(player_id, position, velocity, yaw, body_mask)


@rpc("authority", "call_remote", "reliable", 2)
func _rpc_receive_meteor(
	target: Vector3,
	drift: Vector2,
	damage: int,
	blast_force: float
) -> void:
	meteor_received.emit(target, drift, damage, blast_force)


@rpc("authority", "call_remote", "reliable", 2)
func _rpc_receive_shockwave() -> void:
	shockwave_received.emit()


@rpc("authority", "call_remote", "reliable", 0)
func _rpc_receive_round_state(
	state: int,
	round_number: int,
	time_left: float,
	mode_id: String,
	map_id: String,
	round_seed: int,
	feature_ids: PackedStringArray,
	player_profile_id: String,
	spawn_policy_id: String,
	spectator_policy_id: String
) -> void:
	round_state_received.emit(
		state,
		round_number,
		time_left,
		mode_id,
		map_id,
		round_seed,
		feature_ids,
		player_profile_id,
		spawn_policy_id,
		spectator_policy_id
	)


@rpc("authority", "call_remote", "reliable", 2)
func _rpc_receive_push(sender_player_id: int, direction: Vector3, force: float) -> void:
	push_received.emit(sender_player_id, direction, force)


func _start_client_peer(address: String) -> Error:
	if multiplayer.multiplayer_peer != null:
		multiplayer.multiplayer_peer.close()
	var peer := ENetMultiplayerPeer.new()
	var error := peer.create_client(
		address,
		server_port,
		NET.ENET_CHANNEL_COUNT,
		0,
		0
	)
	if error != OK:
		status_changed.emit("No se pudo iniciar ENet", false)
		return error
	multiplayer.multiplayer_peer = peer
	status_changed.emit("CONECTANDO A %s:%d…" % [address, server_port], false)
	return OK


func _on_connected_to_server() -> void:
	var transport := multiplayer.multiplayer_peer as ENetMultiplayerPeer
	var server_peer: ENetPacketPeer = transport.get_peer(1)
	if server_peer != null:
		server_peer.throttle_configure(
			1000,
			ENetPacketPeer.PACKET_THROTTLE_SCALE,
			1
		)
		server_peer.ping_interval(250)
	_online = true
	_session_accepted = false
	if _room_id > 0 and not _reconnect_token.is_empty():
		_rpc_join_room.rpc_id(
			1,
			_room_id,
			_stable_id,
			_reconnect_token,
			display_name,
			color_index
		)
		status_changed.emit("RECONECTANDO A SALA %d…" % _room_id, false)
		return
	if _lobby_mode:
		_rpc_enter_lobby.rpc_id(1)
		status_changed.emit("ENTRANDO AL LOBBY…", false)
		return
	_rpc_register_session.rpc_id(
		1,
		_stable_id,
		_reconnect_token,
		display_name,
		color_index
	)
	status_changed.emit("VALIDANDO SESIÓN…", false)


func _on_connection_failed() -> void:
	_online = false
	_session_accepted = false
	_close_peer()
	if not _manual_disconnect and not _reconnect_token.is_empty():
		_reconnect_pending = true
		_reconnect_elapsed = 2.0
		status_changed.emit("REINTENTANDO CONEXIÓN…", false)
	else:
		status_changed.emit("SIN SERVIDOR · modo local", false)


func _on_server_disconnected() -> void:
	_online = false
	_session_accepted = false
	for player: Dictionary in _players.values():
		player.connected = false
	_close_peer()
	if not _manual_disconnect:
		_reconnect_pending = true
		_reconnect_elapsed = 1.0
		status_changed.emit("CONEXIÓN INTERRUMPIDA · reconectando", false)


func _close_peer() -> void:
	if multiplayer.multiplayer_peer != null:
		multiplayer.multiplayer_peer.close()
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()


func _reset_runtime_state() -> void:
	_online = false
	_session_accepted = false
	_players.clear()
	_local_player_id = 0
	_local_spawn_position = Vector3(0.0, NET.FLOOR_HEIGHT, 8.0)
	_room_id = 0
	_state_sequence = 0
	_lobby_mode = false


func _load_identity() -> void:
	var config := ConfigFile.new()
	if config.load(IDENTITY_PATH) == OK:
		_stable_id = str(config.get_value("network", "stable_id", ""))
		_reconnect_token = str(config.get_value("network", "reconnect_token", ""))
	if _stable_id.is_empty():
		_stable_id = Crypto.new().generate_random_bytes(16).hex_encode()
		_save_identity()


func _save_identity() -> void:
	if not _persist_identity:
		return
	var config := ConfigFile.new()
	config.set_value("network", "stable_id", _stable_id)
	config.set_value("network", "reconnect_token", _reconnect_token)
	config.save(IDENTITY_PATH)
