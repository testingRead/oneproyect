class_name OneProjectDedicatedServer
extends Node

const NET := preload("res://shared/net_constants.gd")

@onready var room_manager: Node = $RoomManager

var server_port := NET.DEFAULT_PORT
var max_rooms := NET.MAX_ROOMS
var _accumulator := 0.0
var _metrics_elapsed := 0.0
var _metrics_cpu_usec := 0
var _bytes_received := 0
var _bytes_sent := 0
var _accepted_states := 0
var _rejected_states := 0
var _lobby_peers: Dictionary = {}
const METRICS_INTERVAL := 5.0


func _ready() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--port="):
			server_port = clampi(int(argument.trim_prefix("--port=")), 1024, 65535)
		elif argument.begins_with("--max-rooms="):
			max_rooms = clampi(
				int(argument.trim_prefix("--max-rooms=")),
				1,
				100
			)
	room_manager.max_rooms = max_rooms
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	room_manager.phase_changed.connect(_on_phase_changed)
	room_manager.meteor_spawned.connect(_on_meteor_spawned)
	room_manager.shockwave_started.connect(_on_shockwave_started)
	room_manager.session_expired.connect(_on_session_expired)
	room_manager.standings_changed.connect(_on_standings_changed)
	var peer := ENetMultiplayerPeer.new()
	peer.set_bind_ip("*")
	var error := peer.create_server(
		server_port,
		max_rooms * NET.MAX_PLAYERS_PER_ROOM,
		NET.ENET_CHANNEL_COUNT,
		0,
		0
	)
	if error != OK:
		push_error("Dedicated server startup failed: %s" % error)
		get_tree().quit(1)
		return
	multiplayer.multiplayer_peer = peer
	print(
		"ONEPROYECT_SERVER_READY udp=%d max_rooms=%d max_players=%d tick_rate=%d snapshot_rate=%d"
		% [
			server_port,
			max_rooms,
			NET.MAX_PLAYERS_PER_ROOM,
			NET.SERVER_TICK_RATE,
			NET.SNAPSHOT_RATE,
		]
	)
	_audit_server_tree()


func _process(delta: float) -> void:
	_accumulator += delta
	_metrics_elapsed += delta
	var catchup_ticks := 0
	while _accumulator >= NET.SERVER_TICK_DELTA and catchup_ticks < 4:
		var started_usec := Time.get_ticks_usec()
		_accumulator -= NET.SERVER_TICK_DELTA
		room_manager.tick_all()
		for room: Node in room_manager.rooms:
			if (
				room.phase != NET.RoomPhase.WAITING
				and room.server_tick % NET.SNAPSHOT_INTERVAL_TICKS == 0
			):
				_broadcast_snapshot(room)
		_metrics_cpu_usec += Time.get_ticks_usec() - started_usec
		catchup_ticks += 1
	if _metrics_elapsed >= METRICS_INTERVAL:
		_print_metrics()


@rpc("any_peer", "call_remote", "reliable", 0)
func _rpc_register_session(
	stable_id: String,
	reconnect_token: String,
	requested_name: String,
	requested_color: int,
	requested_victories: int,
	requested_experience: int
) -> void:
	var sender := multiplayer.get_remote_sender_id()
	var room: Node = room_manager.fixed_room()
	room.auto_start_when_ready = true
	_register_session_in_room(
		sender,
		room,
		stable_id,
		reconnect_token,
		requested_name,
		requested_color,
		requested_victories,
		requested_experience
	)


@rpc("any_peer", "call_remote", "reliable", 0)
func _rpc_enter_lobby() -> void:
	var sender := multiplayer.get_remote_sender_id()
	if room_manager.find_room_for_peer(sender) != null:
		_rpc_room_action_failed.rpc_id(sender, "already_in_room")
		return
	_lobby_peers[sender] = true
	_rpc_lobby_ready.rpc_id(sender, max_rooms, NET.MAX_PLAYERS_PER_ROOM)
	_send_room_list(sender)


@rpc("any_peer", "call_remote", "reliable", 0)
func _rpc_request_room_list() -> void:
	var sender := multiplayer.get_remote_sender_id()
	if _lobby_peers.has(sender):
		_send_room_list(sender)


@rpc("any_peer", "call_remote", "reliable", 0)
func _rpc_create_room(
	stable_id: String,
	reconnect_token: String,
	requested_name: String,
	requested_color: int,
	requested_victories: int,
	requested_experience: int
) -> void:
	var sender := multiplayer.get_remote_sender_id()
	if room_manager.find_room_for_peer(sender) != null:
		_rpc_room_action_failed.rpc_id(sender, "already_in_room")
		return
	var room: Node = room_manager.create_room()
	if room == null:
		_rpc_room_action_failed.rpc_id(sender, "room_limit")
		return
	if not _register_session_in_room(
		sender,
		room,
		stable_id,
		reconnect_token,
		requested_name,
		requested_color,
		requested_victories,
		requested_experience
	):
		room_manager.remove_room(room)
		_broadcast_lobby_rooms()


@rpc("any_peer", "call_remote", "reliable", 0)
func _rpc_join_room(
	room_id: int,
	stable_id: String,
	reconnect_token: String,
	requested_name: String,
	requested_color: int,
	requested_victories: int,
	requested_experience: int
) -> void:
	var sender := multiplayer.get_remote_sender_id()
	if room_manager.find_room_for_peer(sender) != null:
		_rpc_room_action_failed.rpc_id(sender, "already_in_room")
		return
	var room: Node = room_manager.find_room(room_id)
	var reconnect_room: Node = room_manager.find_room_for_stable_id(
		stable_id.strip_edges().to_lower().substr(0, 64)
	)
	if reconnect_room != null:
		room = reconnect_room
	if room == null:
		_rpc_room_action_failed.rpc_id(sender, "room_missing")
		return
	if reconnect_room == null and not room.accepts_new_players():
		_rpc_room_action_failed.rpc_id(sender, "room_unavailable")
		return
	_register_session_in_room(
		sender,
		room,
		stable_id,
		reconnect_token,
		requested_name,
		requested_color,
		requested_victories,
		requested_experience
	)


@rpc("any_peer", "call_remote", "reliable", 0)
func _rpc_start_room() -> void:
	var sender := multiplayer.get_remote_sender_id()
	var room: Node = room_manager.find_room_for_peer(sender)
	if room == null:
		_rpc_room_action_failed.rpc_id(sender, "not_in_room")
		return
	if not room.is_host_peer(sender):
		_rpc_room_action_failed.rpc_id(sender, "host_only")
		return
	if room.connected_count() < NET.MIN_PLAYERS_TO_START:
		_rpc_room_action_failed.rpc_id(sender, "need_two_players")
		return
	if not room.all_connected_ready():
		_rpc_room_action_failed.rpc_id(sender, "players_not_ready")
		return
	if not room.start_rounds():
		_rpc_room_action_failed.rpc_id(sender, "room_unavailable")
		return
	_broadcast_lobby_rooms()


@rpc("any_peer", "call_remote", "reliable", 0)
func _rpc_set_room_profile(character_index: int, ready: bool) -> void:
	var sender := multiplayer.get_remote_sender_id()
	var room: Node = room_manager.find_room_for_peer(sender)
	if room == null:
		_rpc_room_action_failed.rpc_id(sender, "not_in_room")
		return
	if room.phase != NET.RoomPhase.WAITING:
		_rpc_room_action_failed.rpc_id(sender, "room_unavailable")
		return
	var session: RefCounted = room.session_manager.find_by_peer_id(sender)
	if session == null:
		_rpc_room_action_failed.rpc_id(sender, "not_in_room")
		return
	session.color_index = clampi(character_index, 0, 4)
	session.ready = ready
	_broadcast_player_profile(room, session)
	_broadcast_room_waiting(room)


@rpc("any_peer", "call_remote", "reliable", 0)
func _rpc_set_room_rules(total_rounds: int) -> void:
	var sender := multiplayer.get_remote_sender_id()
	var room: Node = room_manager.find_room_for_peer(sender)
	if room == null:
		_rpc_room_action_failed.rpc_id(sender, "not_in_room")
		return
	if not room.is_host_peer(sender):
		_rpc_room_action_failed.rpc_id(sender, "host_only")
		return
	if not room.set_total_rounds(total_rounds):
		_rpc_room_action_failed.rpc_id(sender, "invalid_round_count")
		return
	_broadcast_room_waiting(room)


@rpc("any_peer", "call_remote", "reliable", 0)
func _rpc_leave_room() -> void:
	var sender := multiplayer.get_remote_sender_id()
	var room: Node = room_manager.find_room_for_peer(sender)
	if room == null:
		_lobby_peers[sender] = true
		_send_room_list(sender)
		return
	var removed: RefCounted = room.session_manager.remove_by_peer_id(sender)
	if removed != null:
		room.release_player_cache(removed.player_id)
		for session: RefCounted in room.session_manager.sessions:
			if session.connected and _peer_can_receive(session.peer_id):
				_rpc_player_left.rpc_id(session.peer_id, removed.player_id, false)
	_lobby_peers[sender] = true
	_rpc_returned_to_lobby.rpc_id(sender)
	if room.session_manager.sessions.is_empty():
		room_manager.remove_room(room)
	else:
		room.call_deferred("_refresh_host")
		call_deferred("_broadcast_room_waiting", room)
	call_deferred("_broadcast_lobby_rooms")


@rpc("any_peer", "call_remote", "reliable", 0)
func _rpc_reopen_room() -> void:
	var sender := multiplayer.get_remote_sender_id()
	var room: Node = room_manager.find_room_for_peer(sender)
	if room == null:
		_rpc_room_action_failed.rpc_id(sender, "not_in_room")
		return
	if not room.reopen_waiting_room():
		_rpc_room_action_failed.rpc_id(sender, "match_not_finished")
		return
	_broadcast_room_waiting(room)
	_broadcast_room_reopened(room)
	_broadcast_lobby_rooms()


func _register_session_in_room(
	sender: int,
	room: Node,
	stable_id: String,
	reconnect_token: String,
	requested_name: String,
	requested_color: int,
	requested_victories: int,
	requested_experience: int
) -> bool:
	if room == null:
		_rpc_session_rejected.rpc_id(sender, "room_missing")
		return false
	var session: RefCounted = room.session_manager.register_session(
		sender,
		stable_id,
		reconnect_token,
		requested_name,
		requested_color,
		requested_victories,
		requested_experience,
		room.server_tick
	)
	if session == null:
		var reason := str(room.session_manager.last_registration_error)
		if _lobby_peers.has(sender):
			_rpc_room_action_failed.rpc_id(sender, reason)
		else:
			_rpc_session_rejected.rpc_id(sender, reason)
		return false
	if room.host_player_id == 0:
		room.host_player_id = session.player_id
	_lobby_peers.erase(sender)
	_rpc_session_accepted.rpc_id(
		sender,
		session.player_id,
		session.reconnect_token,
		room.session_manager.last_registration_reconnected,
		room.room_id,
		room.server_tick
	)
	for existing: RefCounted in room.session_manager.sessions:
		if not existing.connected or not _peer_can_receive(existing.peer_id):
			continue
		_rpc_player_joined.rpc_id(
			sender,
			existing.player_id,
			existing.display_name,
			existing.color_index,
			existing.position
		)
		if existing.player_id != session.player_id:
			_rpc_player_joined.rpc_id(
				existing.peer_id,
				session.player_id,
				session.display_name,
				session.color_index,
				session.position
			)
	_broadcast_round_state_to_peer(room, sender)
	_send_standings_to_peer(room, sender)
	_broadcast_room_waiting(room)
	_broadcast_lobby_rooms()
	print(
		"SESSION_ACCEPTED player=%d peer=%d reconnect=%s room=%d connected=%d"
		% [
			session.player_id,
			sender,
			room.session_manager.last_registration_reconnected,
			room.room_id,
			room.session_manager.connected_count(),
		]
	)
	return true


@rpc("any_peer", "call_remote", "unreliable_ordered", 1)
func _rpc_submit_owned_state(packet: PackedByteArray) -> void:
	_bytes_received += packet.size()
	var room: Node = room_manager.find_room_for_peer(multiplayer.get_remote_sender_id())
	if room != null and room.apply_owned_state(multiplayer.get_remote_sender_id(), packet):
		_accepted_states += 1
	else:
		_rejected_states += 1


@rpc("any_peer", "call_remote", "reliable", 2)
func _rpc_submit_push(target_player_id: int, direction: Vector3) -> void:
	var sender := multiplayer.get_remote_sender_id()
	var room: Node = room_manager.find_room_for_peer(sender)
	if room == null or not room.apply_push(sender, target_player_id, direction):
		return
	var source: RefCounted = room.session_manager.find_by_peer_id(sender)
	var target: RefCounted = room.session_manager.find_by_player_id(target_player_id)
	if (
		source != null
		and target != null
		and target.connected
		and _peer_can_receive(target.peer_id)
	):
		_rpc_receive_push.rpc_id(
			target.peer_id,
			source.player_id,
			direction.normalized(),
			5.2
		)


@rpc("authority", "call_remote", "reliable", 0)
func _rpc_session_accepted(
	_player_id: int,
	_reconnect_token: String,
	_reconnected: bool,
	_room_id: int,
	_server_tick: int
) -> void:
	pass


@rpc("authority", "call_remote", "reliable", 0)
func _rpc_session_rejected(_reason: String) -> void:
	pass


@rpc("authority", "call_remote", "reliable", 0)
func _rpc_lobby_ready(_maximum_rooms: int, _maximum_players: int) -> void:
	pass


@rpc("authority", "call_remote", "reliable", 0)
func _rpc_room_list(
	_room_ids: PackedInt32Array,
	_player_counts: PackedInt32Array,
	_phases: PackedInt32Array,
	_host_names: PackedStringArray
) -> void:
	pass


@rpc("authority", "call_remote", "reliable", 0)
func _rpc_room_waiting(
	_room_id: int,
	_player_count: int,
	_host_player_id: int,
	_ready_count: int,
	_local_ready: bool,
	_all_ready: bool,
	_player_names: PackedStringArray,
	_ready_flags: PackedByteArray,
	_character_indices: PackedByteArray,
	_victory_counts: PackedInt32Array,
	_experience_values: PackedInt32Array,
	_total_rounds: int
) -> void:
	pass


@rpc("authority", "call_remote", "reliable", 0)
func _rpc_room_started(_room_id: int) -> void:
	pass


@rpc("authority", "call_remote", "reliable", 0)
func _rpc_room_action_failed(_reason: String) -> void:
	pass


@rpc("authority", "call_remote", "reliable", 0)
func _rpc_returned_to_lobby() -> void:
	pass


@rpc("authority", "call_remote", "reliable", 0)
func _rpc_room_reopened(_room_id: int) -> void:
	pass


@rpc("authority", "call_remote", "reliable", 0)
func _rpc_player_joined(
	_player_id: int,
	_display_name: String,
	_color_index: int,
	_position: Vector3
) -> void:
	pass


@rpc("authority", "call_remote", "reliable", 0)
func _rpc_player_left(_player_id: int, _temporary: bool) -> void:
	pass


@rpc("authority", "call_remote", "unreliable_ordered", 1)
func _rpc_receive_snapshot(_packet: PackedByteArray) -> void:
	pass


@rpc("authority", "call_remote", "reliable", 2)
func _rpc_receive_meteor(
	_target: Vector3,
	_drift: Vector2,
	_damage: int,
	_blast_force: float
) -> void:
	pass


@rpc("authority", "call_remote", "reliable", 2)
func _rpc_receive_shockwave() -> void:
	pass


@rpc("authority", "call_remote", "reliable", 0)
func _rpc_receive_round_state(
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


@rpc("authority", "call_remote", "reliable", 0)
func _rpc_receive_standings(
	_player_ids: PackedInt32Array,
	_player_names: PackedStringArray,
	_health_values: PackedByteArray,
	_round_points: PackedByteArray,
	_total_scores: PackedInt32Array,
	_round_number: int,
	_total_rounds: int,
	_match_finished: bool,
	_winner_player_id: int,
	_match_id: int
) -> void:
	pass


@rpc("authority", "call_remote", "reliable", 2)
func _rpc_receive_push(
	_sender_player_id: int,
	_direction: Vector3,
	_force: float
) -> void:
	pass


func _broadcast_snapshot(room: Node) -> void:
	for session: RefCounted in room.session_manager.sessions:
		if not session.connected or not _peer_can_receive(session.peer_id):
			continue
		var packet: PackedByteArray = room.build_snapshot_for(session.player_id)
		_rpc_receive_snapshot.rpc_id(session.peer_id, packet)
		_bytes_sent += packet.size()


func _broadcast_round_state(room: Node) -> void:
	for session: RefCounted in room.session_manager.sessions:
		if session.connected and _peer_can_receive(session.peer_id):
			_broadcast_round_state_to_peer(room, session.peer_id)


func _broadcast_round_state_to_peer(room: Node, peer_id: int) -> void:
	_rpc_receive_round_state.rpc_id(
		peer_id,
		room.phase,
		room.round_number,
		room.seconds_left(),
		NET.mode_name(room.mode_id),
		"plaza_caos",
		room.round_seed,
		PackedStringArray(),
		"default",
		"spread",
		"overhead"
	)


func _on_standings_changed(room: Node) -> void:
	for session: RefCounted in room.session_manager.sessions:
		if session.connected and _peer_can_receive(session.peer_id):
			_send_standings_to_peer(room, session.peer_id)


func _send_standings_to_peer(room: Node, peer_id: int) -> void:
	var player_ids := PackedInt32Array()
	var player_names := PackedStringArray()
	var health_values := PackedByteArray()
	var round_points := PackedByteArray()
	var total_scores := PackedInt32Array()
	var ranked: Array[RefCounted] = room.standings()
	for session: RefCounted in ranked:
		player_ids.append(session.player_id)
		player_names.append(session.display_name)
		health_values.append(clampi(session.health, 0, 100))
		round_points.append(clampi(session.round_points, 0, 255))
		total_scores.append(session.score)
	var winner_player_id: int = (
		ranked[0].player_id
		if room.match_finished and not ranked.is_empty()
		else 0
	)
	_rpc_receive_standings.rpc_id(
		peer_id,
		player_ids,
		player_names,
		health_values,
		round_points,
		total_scores,
		room.round_number,
		room.total_rounds,
		room.match_finished,
		winner_player_id,
		room.match_id
	)


func _on_peer_connected(peer_id: int) -> void:
	var transport := multiplayer.multiplayer_peer as ENetMultiplayerPeer
	var connected_peer: ENetPacketPeer = transport.get_peer(peer_id)
	if connected_peer != null:
		connected_peer.throttle_configure(
			1000,
			ENetPacketPeer.PACKET_THROTTLE_SCALE,
			1
		)
		connected_peer.ping_interval(250)
	print("PEER_CONNECTED peer=%d" % peer_id)


func _on_peer_disconnected(peer_id: int) -> void:
	_lobby_peers.erase(peer_id)
	var room: Node = room_manager.find_room_for_peer(peer_id)
	if room == null:
		return
	var session: RefCounted = room.session_manager.mark_disconnected(
		peer_id,
		room.server_tick
	)
	if session == null:
		return
	room.call_deferred("_refresh_host")
	call_deferred("_notify_session_suspended", room, session.player_id)
	call_deferred("_broadcast_room_waiting", room)
	call_deferred("_broadcast_lobby_rooms")
	print(
		"SESSION_SUSPENDED player=%d reconnect_until_tick=%d"
		% [session.player_id, session.reconnect_until_tick]
	)


func _notify_session_suspended(room: Node, player_id: int) -> void:
	if not is_instance_valid(room):
		return
	var connected_peers := multiplayer.get_peers()
	for other: RefCounted in room.session_manager.sessions:
		if (
			other.connected
			and other.peer_id in connected_peers
			and _peer_can_receive(other.peer_id)
		):
			_rpc_player_left.rpc_id(other.peer_id, player_id, true)


func _on_phase_changed(room: Node) -> void:
	_broadcast_round_state(room)
	if room.phase == NET.RoomPhase.COUNTDOWN and room.round_number == 0:
		_broadcast_room_started(room)
	_broadcast_lobby_rooms()


func _on_meteor_spawned(
	room: Node,
	target: Vector3,
	drift: Vector2,
	damage: int,
	force: float
) -> void:
	for session: RefCounted in room.session_manager.sessions:
		if session.connected and _peer_can_receive(session.peer_id):
			_rpc_receive_meteor.rpc_id(
				session.peer_id,
				target,
				drift,
				damage,
				force
			)


func _on_shockwave_started(room: Node) -> void:
	for session: RefCounted in room.session_manager.sessions:
		if session.connected and _peer_can_receive(session.peer_id):
			_rpc_receive_shockwave.rpc_id(session.peer_id)


func _on_session_expired(room: Node, player_id: int) -> void:
	room.release_player_cache(player_id)
	var connected_peers := multiplayer.get_peers()
	for session: RefCounted in room.session_manager.sessions:
		if (
			session.connected
			and session.peer_id in connected_peers
			and _peer_can_receive(session.peer_id)
		):
			_rpc_player_left.rpc_id(session.peer_id, player_id, false)
	print("SESSION_EXPIRED player=%d room=%d" % [player_id, room.room_id])
	call_deferred("_remove_room_if_empty", room)


func _remove_room_if_empty(room: Node) -> void:
	if not is_instance_valid(room):
		return
	if room.session_manager.sessions.is_empty():
		room_manager.remove_room(room)
	else:
		_broadcast_room_waiting(room)
	_broadcast_lobby_rooms()


func _send_room_list(peer_id: int) -> void:
	if not _peer_can_receive(peer_id):
		_lobby_peers.erase(peer_id)
		return
	var room_ids := PackedInt32Array()
	var player_counts := PackedInt32Array()
	var phases := PackedInt32Array()
	var host_names := PackedStringArray()
	for room: Node in room_manager.rooms:
		room_ids.append(room.room_id)
		player_counts.append(room.connected_count())
		phases.append(room.phase)
		host_names.append(room.host_name())
	_rpc_room_list.rpc_id(peer_id, room_ids, player_counts, phases, host_names)


func _broadcast_lobby_rooms() -> void:
	var connected_peers := multiplayer.get_peers()
	for peer_id: int in _lobby_peers.keys():
		if peer_id in connected_peers and _peer_can_receive(peer_id):
			_send_room_list(peer_id)
		else:
			_lobby_peers.erase(peer_id)


func _broadcast_room_waiting(room: Node) -> void:
	if not is_instance_valid(room):
		return
	if room.phase != NET.RoomPhase.WAITING:
		return
	room._refresh_host()
	var connected_peers := multiplayer.get_peers()
	var player_names := PackedStringArray()
	var ready_flags := PackedByteArray()
	var character_indices := PackedByteArray()
	var victory_counts := PackedInt32Array()
	var experience_values := PackedInt32Array()
	for session: RefCounted in room.session_manager.sessions:
		if not session.connected:
			continue
		player_names.append(session.display_name)
		ready_flags.append(1 if session.ready else 0)
		character_indices.append(session.color_index)
		victory_counts.append(session.profile_victories)
		experience_values.append(session.profile_experience)
	var ready_count: int = room.ready_count()
	var all_ready: bool = room.all_connected_ready()
	for session: RefCounted in room.session_manager.sessions:
		if (
			session.connected
			and session.peer_id in connected_peers
			and _peer_can_receive(session.peer_id)
		):
			_rpc_room_waiting.rpc_id(
				session.peer_id,
				room.room_id,
				room.connected_count(),
				room.host_player_id,
				ready_count,
				session.ready,
				all_ready,
				player_names,
				ready_flags,
				character_indices,
				victory_counts,
				experience_values,
				room.total_rounds
			)


func _broadcast_player_profile(room: Node, changed: RefCounted) -> void:
	for session: RefCounted in room.session_manager.sessions:
		if session.connected and _peer_can_receive(session.peer_id):
			_rpc_player_joined.rpc_id(
				session.peer_id,
				changed.player_id,
				changed.display_name,
				changed.color_index,
				changed.position
			)


func _broadcast_room_started(room: Node) -> void:
	var connected_peers := multiplayer.get_peers()
	for session: RefCounted in room.session_manager.sessions:
		if (
			session.connected
			and session.peer_id in connected_peers
			and _peer_can_receive(session.peer_id)
		):
			_rpc_room_started.rpc_id(session.peer_id, room.room_id)


func _broadcast_room_reopened(room: Node) -> void:
	for session: RefCounted in room.session_manager.sessions:
		if session.connected and _peer_can_receive(session.peer_id):
			_rpc_room_reopened.rpc_id(session.peer_id, room.room_id)


func _peer_can_receive(peer_id: int) -> bool:
	var transport := multiplayer.multiplayer_peer as ENetMultiplayerPeer
	if transport == null:
		return false
	var packet_peer: ENetPacketPeer = transport.get_peer(peer_id)
	return (
		packet_peer != null
		and packet_peer.is_active()
		and packet_peer.get_state() == ENetPacketPeer.STATE_CONNECTED
		and packet_peer.get_channels() > 0
	)


func _print_metrics() -> void:
	var elapsed := maxf(_metrics_elapsed, 0.001)
	var cpu_percent := float(_metrics_cpu_usec) / (elapsed * 1000000.0) * 100.0
	var memory_mib := float(OS.get_static_memory_usage()) / 1048576.0
	print(
		"SERVER_METRICS cpu_pct=%.3f memory_mib=%.2f rx_bps=%.1f tx_bps=%.1f states_ok=%d states_rejected=%d"
		% [
			cpu_percent,
			memory_mib,
			float(_bytes_received) / elapsed,
			float(_bytes_sent) / elapsed,
			_accepted_states,
			_rejected_states,
		]
	)
	_metrics_elapsed = 0.0
	_metrics_cpu_usec = 0
	_bytes_received = 0
	_bytes_sent = 0
	_accepted_states = 0
	_rejected_states = 0


func _audit_server_tree() -> void:
	var nodes := find_children("*", "", true, false)
	var visual_nodes := 0
	for node: Node in nodes:
		visual_nodes += int(
			node is Node3D
			or node is CanvasItem
			or node is AudioStreamPlayer
			or node is AudioStreamPlayer3D
		)
	if visual_nodes > 0:
		push_error("Dedicated server tree contains %d visual/audio nodes" % visual_nodes)
		get_tree().quit(1)
		return
	print("SERVER_TREE_OK nodes=%d visual_nodes=0" % (nodes.size() + 1))
