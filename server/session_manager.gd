class_name ServerSessionManager
extends Node

signal session_expired(player_id: int)

const NET := preload("res://shared/net_constants.gd")
const SESSION_SCRIPT := preload("res://server/session_state.gd")

var room_id := 1
var sessions: Array[RefCounted] = []
var last_registration_reconnected := false
var last_registration_error := ""
var _next_player_id := 1
var _crypto := Crypto.new()


func register_session(
	peer_id: int,
	stable_id: String,
	reconnect_token: String,
	requested_name: String,
	requested_color: int,
	server_tick: int
) -> RefCounted:
	last_registration_reconnected = false
	last_registration_error = ""
	var safe_stable_id := _sanitize_identity(stable_id)
	if safe_stable_id.is_empty():
		last_registration_error = "invalid_identity"
		return null
	var existing := find_by_stable_id(safe_stable_id)
	if existing != null:
		if existing.connected:
			last_registration_error = "already_connected"
			return null
		if (
			existing.reconnect_token != reconnect_token
			or server_tick > existing.reconnect_until_tick
		):
			last_registration_error = "invalid_reconnect"
			return null
		existing.peer_id = peer_id
		existing.connected = true
		existing.reconnect_until_tick = 0
		existing.display_name = _sanitize_name(requested_name, existing.player_id)
		existing.color_index = clampi(requested_color, 0, 4)
		existing.input_move = Vector2.ZERO
		last_registration_reconnected = true
		return existing
	if sessions.size() >= NET.MAX_PLAYERS_PER_ROOM:
		last_registration_error = "room_full"
		return null
	var session: RefCounted = SESSION_SCRIPT.new()
	session.player_id = _next_player_id
	_next_player_id += 1
	session.room_id = room_id
	session.stable_id = safe_stable_id
	session.reconnect_token = _create_token()
	session.peer_id = peer_id
	session.display_name = _sanitize_name(requested_name, session.player_id)
	session.color_index = clampi(requested_color, 0, 4)
	session.connected = true
	var slot := sessions.size()
	session.position = Vector3(
		float((slot % 3) - 1) * 2.4,
		NET.FLOOR_HEIGHT,
		8.0 - float(slot / 3) * 2.4
	)
	sessions.append(session)
	return session


func mark_disconnected(peer_id: int, server_tick: int) -> RefCounted:
	var session: RefCounted = find_by_peer_id(peer_id)
	if session == null:
		return null
	session.connected = false
	session.peer_id = 0
	session.input_move = Vector2.ZERO
	session.velocity.x = 0.0
	session.velocity.z = 0.0
	session.reconnect_until_tick = server_tick + NET.RECONNECT_TICKS
	return session


func remove_by_peer_id(peer_id: int) -> RefCounted:
	for index in sessions.size():
		var session: RefCounted = sessions[index]
		if session.connected and session.peer_id == peer_id:
			sessions.remove_at(index)
			session.connected = false
			session.peer_id = 0
			return session
	return null


func purge_expired(server_tick: int) -> void:
	for index in range(sessions.size() - 1, -1, -1):
		var session: RefCounted = sessions[index]
		if (
			not session.connected
			and session.reconnect_until_tick > 0
			and server_tick > session.reconnect_until_tick
		):
			sessions.remove_at(index)
			session_expired.emit(session.player_id)


func find_by_peer_id(peer_id: int) -> RefCounted:
	for session in sessions:
		if session.connected and session.peer_id == peer_id:
			return session
	return null


func find_by_player_id(player_id: int) -> RefCounted:
	for session in sessions:
		if session.player_id == player_id:
			return session
	return null


func find_by_stable_id(stable_id: String) -> RefCounted:
	for session in sessions:
		if session.stable_id == stable_id:
			return session
	return null


func connected_count() -> int:
	var count := 0
	for session in sessions:
		count += int(session.connected)
	return count


func _create_token() -> String:
	return _crypto.generate_random_bytes(16).hex_encode()


func _sanitize_identity(value: String) -> String:
	var safe := value.strip_edges().to_lower().substr(0, 64)
	for character in safe:
		if character not in "0123456789abcdef-":
			return ""
	return safe


func _sanitize_name(value: String, player_id: int) -> String:
	var safe := value.strip_edges().substr(0, 16)
	return safe if not safe.is_empty() else "Jugador%d" % player_id
