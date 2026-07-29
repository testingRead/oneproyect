class_name OneProjectNetwork
extends Node

signal status_changed(text: String, online: bool)
signal peers_changed(current: int, maximum: int)
signal remote_player_joined(peer_id: int, display_name: String, color_index: int)
signal remote_player_left(peer_id: int)
signal remote_snapshot(peer_id: int, position: Vector3, facing_yaw: float)
signal meteor_received(target: Vector3, drift: Vector2, damage: int, blast_force: float)
signal shockwave_received
signal round_state_received(state: int, round_number: int, time_left: float)
signal simulation_host_changed(peer_id: int)
signal push_received(sender_id: int, direction: Vector3, force: float)

const DEFAULT_PORT := 9999
const MAX_PLAYERS := 5
const SNAPSHOT_RATE := 10.0
const MAX_POSITION := 40.0

var server_address := "149.50.152.250"
var server_port := DEFAULT_PORT
var display_name := ""
var color_index := 0
var host_score := 1

var _players: Dictionary = {}
var _join_order: Array[int] = []
var _simulation_host_id := 0
var _online := false
var _server_mode := false
var _last_round_state: Dictionary = {}
var _host_review_elapsed := 0.0


func _ready() -> void:
	server_address = str(ProjectSettings.get_setting("network/server_address", server_address))
	server_port = int(ProjectSettings.get_setting("network/server_port", DEFAULT_PORT))
	display_name = "Jugador%03d" % (randi() % 1000)
	color_index = randi() % 5
	host_score = clampi(OS.get_processor_count(), 1, 16)
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)


func _process(delta: float) -> void:
	if not _server_mode or _players.size() < 2:
		return
	_host_review_elapsed += delta
	if _host_review_elapsed >= 3.0:
		_host_review_elapsed = 0.0
		_elect_simulation_host(true, false)


func start_server() -> Error:
	if _online:
		return ERR_ALREADY_IN_USE
	var peer := ENetMultiplayerPeer.new()
	peer.set_bind_ip("*")
	var error := peer.create_server(server_port, MAX_PLAYERS, 2, 131072, 131072)
	if error != OK:
		status_changed.emit("No se pudo abrir UDP %d" % server_port, false)
		return error
	multiplayer.multiplayer_peer = peer
	_server_mode = true
	_online = true
	_players.clear()
	_join_order.clear()
	_last_round_state.clear()
	print("ONEPROYECT_SERVER_READY udp=%d max_players=%d" % [server_port, MAX_PLAYERS])
	status_changed.emit("Servidor UDP %d activo" % server_port, true)
	peers_changed.emit(0, MAX_PLAYERS)
	return OK


func connect_to_server(address: String = "") -> Error:
	if _online:
		disconnect_session()
	var target := address.strip_edges()
	if target.is_empty():
		target = server_address
	var peer := ENetMultiplayerPeer.new()
	var error := peer.create_client(target, server_port, 2, 65536, 65536)
	if error != OK:
		status_changed.emit("No se pudo iniciar la conexión", false)
		return error
	multiplayer.multiplayer_peer = peer
	status_changed.emit("Conectando a %s:%d…" % [target, server_port], false)
	return OK


func disconnect_session() -> void:
	if multiplayer.multiplayer_peer != null:
		multiplayer.multiplayer_peer.close()
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	_online = false
	_server_mode = false
	_players.clear()
	_join_order.clear()
	_simulation_host_id = 0
	status_changed.emit("MODO LOCAL", false)
	peers_changed.emit(1, MAX_PLAYERS)


func is_online() -> bool:
	return _online and not _server_mode


func is_simulation_host() -> bool:
	return is_online() and multiplayer.get_unique_id() == _simulation_host_id


func get_player_count() -> int:
	return _players.size()


func send_snapshot(position: Vector3, facing_yaw: float) -> void:
	if not is_online():
		return
	_rpc_submit_snapshot.rpc_id(1, position, facing_yaw)


func broadcast_meteor(target: Vector3, drift: Vector2, damage: int, blast_force: float) -> void:
	if not is_simulation_host():
		return
	meteor_received.emit(target, drift, damage, blast_force)
	_rpc_submit_meteor.rpc_id(1, target, drift, damage, blast_force)


func broadcast_round_state(state: int, round_number: int, time_left: float) -> void:
	if not is_simulation_host():
		return
	_rpc_submit_round_state.rpc_id(1, state, round_number, time_left)


func broadcast_shockwave() -> void:
	if not is_simulation_host():
		return
	shockwave_received.emit()
	_rpc_submit_shockwave.rpc_id(1)


func send_push(target_peer_id: int, direction: Vector3, force := 5.2) -> void:
	if not is_online() or target_peer_id == multiplayer.get_unique_id():
		return
	var safe_direction := direction
	safe_direction.y = 0.0
	if not safe_direction.is_finite() or safe_direction.length_squared() < 0.01:
		return
	_rpc_submit_push.rpc_id(1, target_peer_id, safe_direction.normalized(), force)


@rpc("any_peer", "call_remote", "reliable", 0)
func _rpc_register_player(requested_name: String, requested_color: int, requested_host_score: int) -> void:
	if not multiplayer.is_server():
		return
	var sender := multiplayer.get_remote_sender_id()
	if sender <= 1:
		return
	var safe_name := requested_name.strip_edges().substr(0, 16)
	if safe_name.is_empty():
		safe_name = "Jugador%d" % sender
	var safe_color := clampi(requested_color, 0, 4)
	var safe_host_score := clampi(requested_host_score, 1, 16)
	for existing_id in _players:
		var existing: Dictionary = _players[existing_id]
		_rpc_player_joined.rpc_id(sender, existing_id, existing.name, existing.color)
	_players[sender] = {
		"name": safe_name,
		"color": safe_color,
		"host_score": safe_host_score,
	}
	_join_order.append(sender)
	for peer_id in _players:
		_rpc_player_joined.rpc_id(peer_id, sender, safe_name, safe_color)
	_elect_simulation_host()
	if not _last_round_state.is_empty():
		_rpc_receive_round_state.rpc_id(
			sender,
			_last_round_state.state,
			_last_round_state.round_number,
			_last_round_state.time_left
		)
	peers_changed.emit(_players.size(), MAX_PLAYERS)
	print(
		"PLAYER_REGISTERED id=%d name=%s score=%d total=%d"
		% [sender, safe_name, safe_host_score, _players.size()]
	)


@rpc("authority", "call_remote", "reliable", 0)
func _rpc_player_joined(peer_id: int, player_name: String, player_color: int) -> void:
	_players[peer_id] = {"name": player_name, "color": player_color}
	if peer_id != multiplayer.get_unique_id():
		remote_player_joined.emit(peer_id, player_name, player_color)
	peers_changed.emit(_players.size(), MAX_PLAYERS)


@rpc("authority", "call_remote", "reliable", 0)
func _rpc_player_left(peer_id: int) -> void:
	_players.erase(peer_id)
	remote_player_left.emit(peer_id)
	peers_changed.emit(_players.size(), MAX_PLAYERS)


@rpc("authority", "call_remote", "reliable", 0)
func _rpc_set_simulation_host(peer_id: int) -> void:
	_simulation_host_id = peer_id
	simulation_host_changed.emit(peer_id)
	var suffix := " (HOST)" if peer_id == multiplayer.get_unique_id() else ""
	status_changed.emit("EN LÍNEA %d/%d%s" % [_players.size(), MAX_PLAYERS, suffix], true)


@rpc("any_peer", "call_remote", "unreliable_ordered", 1)
func _rpc_submit_snapshot(position: Vector3, facing_yaw: float) -> void:
	if not multiplayer.is_server():
		return
	var sender := multiplayer.get_remote_sender_id()
	if not _players.has(sender) or not position.is_finite() or position.length() > MAX_POSITION:
		return
	for peer_id in _players:
		if peer_id != sender:
			_rpc_receive_snapshot.rpc_id(peer_id, sender, position, facing_yaw)


@rpc("authority", "call_remote", "unreliable_ordered", 1)
func _rpc_receive_snapshot(peer_id: int, position: Vector3, facing_yaw: float) -> void:
	if peer_id != multiplayer.get_unique_id():
		remote_snapshot.emit(peer_id, position, facing_yaw)


@rpc("any_peer", "call_remote", "reliable", 0)
func _rpc_submit_meteor(target: Vector3, drift: Vector2, damage: int, blast_force: float) -> void:
	if not multiplayer.is_server():
		return
	var sender := multiplayer.get_remote_sender_id()
	if sender != _simulation_host_id:
		return
	if absf(target.x) > 12.0 or absf(target.z) > 12.0:
		return
	var safe_drift := drift.limit_length(2.0)
	for peer_id in _players:
		if peer_id != sender:
			_rpc_receive_meteor.rpc_id(
				peer_id,
				target,
				safe_drift,
				clampi(damage, 1, 40),
				clampf(blast_force, 1.0, 16.0)
			)


@rpc("authority", "call_remote", "reliable", 0)
func _rpc_receive_meteor(target: Vector3, drift: Vector2, damage: int, blast_force: float) -> void:
	meteor_received.emit(target, drift, damage, blast_force)


@rpc("any_peer", "call_remote", "reliable", 0)
func _rpc_submit_shockwave() -> void:
	if not multiplayer.is_server():
		return
	var sender := multiplayer.get_remote_sender_id()
	if sender != _simulation_host_id:
		return
	for peer_id in _players:
		if peer_id != sender:
			_rpc_receive_shockwave.rpc_id(peer_id)


@rpc("authority", "call_remote", "reliable", 0)
func _rpc_receive_shockwave() -> void:
	shockwave_received.emit()


@rpc("any_peer", "call_remote", "reliable", 0)
func _rpc_submit_push(target_peer_id: int, direction: Vector3, force: float) -> void:
	if not multiplayer.is_server():
		return
	var sender := multiplayer.get_remote_sender_id()
	if not _players.has(sender) or not _players.has(target_peer_id):
		return
	if not direction.is_finite() or direction.length_squared() < 0.01:
		return
	var safe_direction := direction
	safe_direction.y = 0.0
	_rpc_receive_push.rpc_id(
		target_peer_id,
		sender,
		safe_direction.normalized(),
		clampf(force, 2.0, 6.5)
	)


@rpc("authority", "call_remote", "reliable", 0)
func _rpc_receive_push(sender_id: int, direction: Vector3, force: float) -> void:
	push_received.emit(sender_id, direction, force)


@rpc("any_peer", "call_remote", "reliable", 0)
func _rpc_submit_round_state(state: int, round_number: int, time_left: float) -> void:
	if not multiplayer.is_server():
		return
	var sender := multiplayer.get_remote_sender_id()
	if sender != _simulation_host_id:
		return
	var safe_state := clampi(state, 0, 2)
	var safe_round := clampi(round_number, 0, 999)
	var safe_time := clampf(time_left, 0.0, 90.0)
	_last_round_state = {
		"state": safe_state,
		"round_number": safe_round,
		"time_left": safe_time,
	}
	for peer_id in _players:
		if peer_id != sender:
			_rpc_receive_round_state.rpc_id(peer_id, safe_state, safe_round, safe_time)


@rpc("authority", "call_remote", "reliable", 0)
func _rpc_receive_round_state(state: int, round_number: int, time_left: float) -> void:
	round_state_received.emit(state, round_number, time_left)


func _on_connected_to_server() -> void:
	_online = true
	_server_mode = false
	var own_id := multiplayer.get_unique_id()
	_players[own_id] = {"name": display_name, "color": color_index}
	_rpc_register_player.rpc_id(1, display_name, color_index, host_score)
	status_changed.emit("CONECTADO · esperando sala", true)


func _on_connection_failed() -> void:
	_online = false
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	status_changed.emit("SIN SERVIDOR · modo local", false)


func _on_server_disconnected() -> void:
	disconnect_session()
	status_changed.emit("SERVIDOR DESCONECTADO · modo local", false)


func _on_peer_connected(peer_id: int) -> void:
	if _server_mode:
		print("PEER_CONNECTED id=%d" % peer_id)


func _on_peer_disconnected(peer_id: int) -> void:
	if not _server_mode:
		return
	if _players.erase(peer_id):
		_join_order.erase(peer_id)
		for other_id in _players:
			_rpc_player_left.rpc_id(other_id, peer_id)
		_elect_simulation_host()
		peers_changed.emit(_players.size(), MAX_PLAYERS)
		if _players.is_empty():
			_last_round_state.clear()
	print("PEER_DISCONNECTED id=%d total=%d" % [peer_id, _players.size()])


func _elect_simulation_host(consider_latency := false, force_announce := true) -> void:
	if not multiplayer.is_server():
		return
	var next_host := 0
	var best_device_score := -1
	for peer_id in _join_order:
		if not _players.has(peer_id):
			continue
		var candidate_score := int(_players[peer_id].host_score)
		if candidate_score > best_device_score:
			best_device_score = candidate_score
			next_host = peer_id
	if (
		_players.has(_simulation_host_id)
		and int(_players[_simulation_host_id].host_score) == best_device_score
	):
		next_host = _simulation_host_id
	if consider_latency and next_host != 0:
		next_host = _choose_lower_latency_peer(next_host, best_device_score)
	if next_host == _simulation_host_id and not force_announce:
		return
	_simulation_host_id = next_host
	for peer_id in _players:
		_rpc_set_simulation_host.rpc_id(peer_id, next_host)
	print("SIMULATION_HOST id=%d" % next_host)


func _choose_lower_latency_peer(current_choice: int, device_score: int) -> int:
	var enet_peer := multiplayer.multiplayer_peer as ENetMultiplayerPeer
	if enet_peer == null:
		return current_choice
	var best_id := current_choice
	var best_rtt := _get_peer_rtt(enet_peer, current_choice)
	for peer_id in _join_order:
		if not _players.has(peer_id) or int(_players[peer_id].host_score) != device_score:
			continue
		var candidate_rtt := _get_peer_rtt(enet_peer, peer_id)
		if candidate_rtt > 0.0 and (best_rtt <= 0.0 or candidate_rtt + 40.0 < best_rtt):
			best_id = peer_id
			best_rtt = candidate_rtt
	return best_id


func _get_peer_rtt(enet_peer: ENetMultiplayerPeer, peer_id: int) -> float:
	var packet_peer := enet_peer.get_peer(peer_id)
	if packet_peer == null:
		return 0.0
	return packet_peer.get_statistic(ENetPacketPeer.PEER_ROUND_TRIP_TIME)
