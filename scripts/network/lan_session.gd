class_name OneProjectLanSession
extends Node

signal status_changed(text: String)
signal lobby_changed
signal game_started(minigame_path: String, round_seed: int)
signal player_state_received(peer_id: int, position: Vector3, velocity: Vector3, facing_yaw: float, health: int)
signal physics_state_received(names: PackedStringArray, positions: PackedVector3Array, rotations: PackedVector3Array, velocities: PackedVector3Array)
signal object_impulse_received(object_name: String, impulse: Vector3)

const LAN_PORT := 9998
const DISCOVERY_PORT := 9997
const MAX_PLAYERS := 8
const DISCOVERY_MAGIC := "ONEPROYECT_LAN_V1"
const BEACON_INTERVAL := 0.75

var is_host := false
var selected_minigame_path := ""
var players: Dictionary = {}

var _peer: ENetMultiplayerPeer
var _discovery: PacketPeerUDP
var _beacon: PacketPeerUDP
var _beacon_elapsed := 0.0
var _state_sequence := 0


func _ready() -> void:
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected_to_host)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_host_disconnected)
	set_process(true)


func _process(delta: float) -> void:
	if is_host and is_active():
		_beacon_elapsed -= delta
		if _beacon_elapsed <= 0.0:
			_beacon_elapsed = BEACON_INTERVAL
			_send_beacon()
	_poll_discovery()


func host_room(display_name: String, character_path: String) -> Error:
	leave_room()
	_peer = ENetMultiplayerPeer.new()
	_peer.set_bind_ip("*")
	var error := _peer.create_server(LAN_PORT, MAX_PLAYERS, 3)
	if error != OK:
		status_changed.emit("No se pudo abrir la sala LAN (%s)" % error_string(error))
		return error
	multiplayer.multiplayer_peer = _peer
	is_host = true
	players[1] = _profile(display_name, character_path, false)
	_start_beacon()
	status_changed.emit("Sala LAN creada en %s:%d" % [get_preferred_local_ip(), LAN_PORT])
	lobby_changed.emit()
	return OK


func begin_discovery() -> Error:
	_stop_discovery()
	_discovery = PacketPeerUDP.new()
	var error := _discovery.bind(DISCOVERY_PORT, "0.0.0.0")
	if error != OK:
		status_changed.emit("No se pudo escuchar salas; escribe la IP del anfitrión")
		_discovery = null
		return error
	status_changed.emit("Buscando salas en tu Wi-Fi…")
	return OK


func join_room(address: String, display_name: String, character_path: String) -> Error:
	var target := address.strip_edges()
	if target.is_empty():
		status_changed.emit("Escribe la IP del anfitrión")
		return ERR_INVALID_PARAMETER
	leave_room()
	_peer = ENetMultiplayerPeer.new()
	var error := _peer.create_client(target, LAN_PORT, 3)
	if error != OK:
		status_changed.emit("No se pudo conectar a %s" % target)
		return error
	multiplayer.multiplayer_peer = _peer
	is_host = false
	set_meta(&"pending_name", display_name)
	set_meta(&"pending_character", character_path)
	status_changed.emit("Conectando a %s…" % target)
	return OK


func leave_room() -> void:
	_stop_discovery()
	_stop_beacon()
	if multiplayer.multiplayer_peer != null:
		multiplayer.multiplayer_peer.close()
		multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	_peer = null
	is_host = false
	players.clear()
	selected_minigame_path = ""
	lobby_changed.emit()


func is_active() -> bool:
	return _peer != null and multiplayer.multiplayer_peer == _peer


func get_local_peer_id() -> int:
	return multiplayer.get_unique_id() if is_active() else 1


func get_local_slot() -> int:
	var ids := PackedInt32Array(players.keys())
	ids.sort()
	return maxi(0, ids.find(get_local_peer_id()))


func get_player_name(peer_id: int) -> String:
	var profile: Dictionary = players.get(peer_id, {})
	return str(profile.get("name", "Jugador"))


func set_ready(ready: bool) -> void:
	if not is_active():
		return
	if is_host:
		_set_profile_ready(1, ready)
	else:
		_rpc_set_ready.rpc_id(1, ready)


func set_character(character_path: String) -> void:
	if not is_active():
		return
	if is_host:
		_set_profile_character(1, character_path)
	else:
		_rpc_set_character.rpc_id(1, character_path)


func set_minigame(minigame_path: String) -> void:
	if not is_host or not is_active():
		return
	selected_minigame_path = minigame_path
	_broadcast_lobby()


func can_start() -> bool:
	if not is_host or players.size() < 2 or selected_minigame_path.is_empty():
		return false
	for profile: Dictionary in players.values():
		if not bool(profile.get("ready", false)):
			return false
	return true


func start_game() -> bool:
	if not can_start():
		status_changed.emit("Se necesitan 2 jugadores y todos deben estar listos")
		return false
	_rpc_start_game.rpc(selected_minigame_path, int(Time.get_unix_time_from_system()) ^ Time.get_ticks_msec())
	return true


func send_player_state(position: Vector3, velocity: Vector3, facing_yaw: float, health: int) -> void:
	if not is_active():
		return
	_state_sequence += 1
	if is_host:
		_rpc_player_state.rpc(get_local_peer_id(), position, velocity, facing_yaw, health, _state_sequence)
	else:
		_rpc_submit_player_state.rpc_id(1, position, velocity, facing_yaw, health, _state_sequence)


func send_physics_state(names: PackedStringArray, positions: PackedVector3Array, rotations: PackedVector3Array, velocities: PackedVector3Array) -> void:
	if is_host and is_active():
		_rpc_physics_state.rpc(names, positions, rotations, velocities)


func request_object_impulse(object_name: String, impulse: Vector3) -> void:
	if not is_active() or object_name.is_empty() or not impulse.is_finite():
		return
	if is_host:
		object_impulse_received.emit(object_name, impulse)
	else:
		_rpc_request_object_impulse.rpc_id(1, object_name, impulse)


@rpc("any_peer", "call_remote", "reliable", 0)
func _rpc_register_player(display_name: String, character_path: String) -> void:
	if not multiplayer.is_server():
		return
	var sender := multiplayer.get_remote_sender_id()
	players[sender] = _profile(display_name, character_path, false)
	_broadcast_lobby()


@rpc("any_peer", "call_remote", "reliable", 0)
func _rpc_set_ready(ready: bool) -> void:
	if multiplayer.is_server():
		_set_profile_ready(multiplayer.get_remote_sender_id(), ready)


@rpc("any_peer", "call_remote", "reliable", 0)
func _rpc_set_character(character_path: String) -> void:
	if multiplayer.is_server():
		_set_profile_character(multiplayer.get_remote_sender_id(), character_path)


@rpc("authority", "call_local", "reliable", 0)
func _rpc_lobby_state(peer_ids: PackedInt32Array, names: PackedStringArray, ready_flags: PackedByteArray, character_paths: PackedStringArray, minigame_path: String) -> void:
	players.clear()
	for index in peer_ids.size():
		players[peer_ids[index]] = _profile(names[index], character_paths[index], ready_flags[index] != 0)
	selected_minigame_path = minigame_path
	lobby_changed.emit()


@rpc("authority", "call_local", "reliable", 0)
func _rpc_start_game(minigame_path: String, round_seed: int) -> void:
	selected_minigame_path = minigame_path
	for peer_id in players:
		var profile: Dictionary = players[peer_id]
		profile.ready = false
		players[peer_id] = profile
	game_started.emit(minigame_path, round_seed)


@rpc("any_peer", "call_remote", "unreliable_ordered", 1)
func _rpc_submit_player_state(position: Vector3, velocity: Vector3, facing_yaw: float, health: int, sequence: int) -> void:
	if not multiplayer.is_server():
		return
	var sender := multiplayer.get_remote_sender_id()
	_rpc_player_state.rpc(sender, position, velocity, facing_yaw, health, sequence)


@rpc("authority", "call_local", "unreliable_ordered", 1)
func _rpc_player_state(peer_id: int, position: Vector3, velocity: Vector3, facing_yaw: float, health: int, _sequence: int) -> void:
	if peer_id != get_local_peer_id():
		player_state_received.emit(peer_id, position, velocity, facing_yaw, health)


@rpc("authority", "call_remote", "unreliable_ordered", 2)
func _rpc_physics_state(names: PackedStringArray, positions: PackedVector3Array, rotations: PackedVector3Array, velocities: PackedVector3Array) -> void:
	physics_state_received.emit(names, positions, rotations, velocities)


@rpc("any_peer", "call_remote", "reliable", 2)
func _rpc_request_object_impulse(object_name: String, impulse: Vector3) -> void:
	if multiplayer.is_server():
		object_impulse_received.emit(object_name, impulse)


func _set_profile_ready(peer_id: int, ready: bool) -> void:
	if not players.has(peer_id):
		return
	var profile: Dictionary = players[peer_id]
	profile.ready = ready
	players[peer_id] = profile
	_broadcast_lobby()


func _set_profile_character(peer_id: int, character_path: String) -> void:
	if not players.has(peer_id):
		return
	var profile: Dictionary = players[peer_id]
	profile.character = character_path
	profile.ready = false
	players[peer_id] = profile
	_broadcast_lobby()


func _broadcast_lobby() -> void:
	if not is_host:
		return
	var ids := PackedInt32Array(players.keys())
	ids.sort()
	var names := PackedStringArray()
	var ready := PackedByteArray()
	var characters := PackedStringArray()
	for peer_id in ids:
		var profile: Dictionary = players[peer_id]
		names.append(str(profile.name))
		ready.append(1 if bool(profile.ready) else 0)
		characters.append(str(profile.character))
	_rpc_lobby_state.rpc(ids, names, ready, characters, selected_minigame_path)


func _on_connected_to_host() -> void:
	var display_name := str(get_meta(&"pending_name", "Jugador"))
	var character_path := str(get_meta(&"pending_character", ""))
	_rpc_register_player.rpc_id(1, display_name, character_path)
	status_changed.emit("Conectado a la sala LAN")


func _on_peer_connected(_peer_id: int) -> void:
	if is_host:
		status_changed.emit("Un jugador se conectó")


func _on_peer_disconnected(peer_id: int) -> void:
	if is_host and players.erase(peer_id):
		_broadcast_lobby()
	elif not is_host:
		players.erase(peer_id)
		lobby_changed.emit()


func _on_connection_failed() -> void:
	status_changed.emit("No se pudo conectar a la sala LAN")
	leave_room()


func _on_host_disconnected() -> void:
	status_changed.emit("El anfitrión cerró la sala")
	leave_room()


func _start_beacon() -> void:
	_stop_beacon()
	_beacon = PacketPeerUDP.new()
	_beacon.set_broadcast_enabled(true)
	_beacon.set_dest_address("255.255.255.255", DISCOVERY_PORT)


func _send_beacon() -> void:
	if _beacon == null:
		return
	var host_name := get_player_name(1)
	var payload := "%s|%s|%d|%d" % [DISCOVERY_MAGIC, host_name, players.size(), MAX_PLAYERS]
	_beacon.put_packet(payload.to_utf8_buffer())


func _poll_discovery() -> void:
	if _discovery == null:
		return
	while _discovery.get_available_packet_count() > 0:
		var payload := _discovery.get_packet().get_string_from_utf8()
		var parts := payload.split("|")
		if parts.size() == 4 and parts[0] == DISCOVERY_MAGIC:
			var address := _discovery.get_packet_ip()
			status_changed.emit("Sala de %s · %s · %s/%s" % [parts[1], address, parts[2], parts[3]])
			set_meta(&"discovered_address", address)


func get_discovered_address() -> String:
	return str(get_meta(&"discovered_address", ""))


func _stop_discovery() -> void:
	if _discovery != null:
		_discovery.close()
	_discovery = null


func _stop_beacon() -> void:
	if _beacon != null:
		_beacon.close()
	_beacon = null


func get_preferred_local_ip() -> String:
	for address in IP.get_local_addresses():
		if address.begins_with("192.168.") or address.begins_with("10.") or address.begins_with("172."):
			if ":" not in address:
				return address
	return "IP local"


func _profile(display_name: String, character_path: String, ready: bool) -> Dictionary:
	return {
		"name": display_name.left(16),
		"character": character_path,
		"ready": ready,
	}
