class_name OneProjectDedicatedServer
extends Node

const NET := preload("res://shared/net_constants.gd")

@onready var room_manager: Node = $RoomManager

var server_port := NET.DEFAULT_PORT
var _accumulator := 0.0
var _metrics_elapsed := 0.0
var _metrics_cpu_usec := 0
var _bytes_received := 0
var _bytes_sent := 0
var _accepted_inputs := 0
var _rejected_inputs := 0
const METRICS_INTERVAL := 5.0


func _ready() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--port="):
			server_port = clampi(int(argument.trim_prefix("--port=")), 1024, 65535)
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	room_manager.phase_changed.connect(_on_phase_changed)
	room_manager.meteor_spawned.connect(_on_meteor_spawned)
	room_manager.shockwave_started.connect(_on_shockwave_started)
	room_manager.session_expired.connect(_on_session_expired)
	var peer := ENetMultiplayerPeer.new()
	peer.set_bind_ip("*")
	var error := peer.create_server(
		server_port,
		NET.MAX_PLAYERS_PER_ROOM,
		NET.ENET_CHANNEL_COUNT,
		262144,
		262144
	)
	if error != OK:
		push_error("Dedicated server startup failed: %s" % error)
		get_tree().quit(1)
		return
	multiplayer.multiplayer_peer = peer
	print(
		"ONEPROYECT_SERVER_READY udp=%d rooms=1 max_players=%d tick_rate=%d snapshot_rate=%d"
		% [
			server_port,
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
		var room: Node = room_manager.fixed_room()
		if room.server_tick % NET.SNAPSHOT_INTERVAL_TICKS == 0:
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
	requested_color: int
) -> void:
	var sender := multiplayer.get_remote_sender_id()
	var room: Node = room_manager.fixed_room()
	var session: RefCounted = room.session_manager.register_session(
		sender,
		stable_id,
		reconnect_token,
		requested_name,
		requested_color,
		room.server_tick
	)
	if session == null:
		_rpc_session_rejected.rpc_id(
			sender,
			str(room.session_manager.last_registration_error)
		)
		return
	_rpc_session_accepted.rpc_id(
		sender,
		session.player_id,
		session.reconnect_token,
		room.session_manager.last_registration_reconnected,
		room.room_id,
		room.server_tick
	)
	for existing: RefCounted in room.session_manager.sessions:
		if not existing.connected:
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


@rpc("any_peer", "call_remote", "unreliable_ordered", 1)
func _rpc_submit_input(packet: PackedByteArray) -> void:
	_bytes_received += packet.size()
	var room: Node = room_manager.find_room_for_peer(multiplayer.get_remote_sender_id())
	if room != null and room.apply_input(multiplayer.get_remote_sender_id(), packet):
		_accepted_inputs += 1
	else:
		_rejected_inputs += 1


@rpc("any_peer", "call_remote", "reliable", 2)
func _rpc_submit_push(target_player_id: int, direction: Vector3) -> void:
	var sender := multiplayer.get_remote_sender_id()
	var room: Node = room_manager.find_room_for_peer(sender)
	if room == null or not room.apply_push(sender, target_player_id, direction):
		return
	var source: RefCounted = room.session_manager.find_by_peer_id(sender)
	var target: RefCounted = room.session_manager.find_by_player_id(target_player_id)
	if source != null and target != null and target.connected:
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


@rpc("authority", "call_remote", "reliable", 2)
func _rpc_receive_push(
	_sender_player_id: int,
	_direction: Vector3,
	_force: float
) -> void:
	pass


func _broadcast_snapshot(room: Node) -> void:
	var packet: PackedByteArray = room.build_snapshot()
	for session: RefCounted in room.session_manager.sessions:
		if not session.connected:
			continue
		_rpc_receive_snapshot.rpc_id(session.peer_id, packet)
		_bytes_sent += packet.size()


func _broadcast_round_state(room: Node) -> void:
	for session: RefCounted in room.session_manager.sessions:
		if session.connected:
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


func _on_peer_connected(peer_id: int) -> void:
	print("PEER_CONNECTED peer=%d" % peer_id)


func _on_peer_disconnected(peer_id: int) -> void:
	var room: Node = room_manager.find_room_for_peer(peer_id)
	if room == null:
		return
	var session: RefCounted = room.session_manager.mark_disconnected(
		peer_id,
		room.server_tick
	)
	if session == null:
		return
	call_deferred("_notify_session_suspended", room, session.player_id)
	print(
		"SESSION_SUSPENDED player=%d reconnect_until_tick=%d"
		% [session.player_id, session.reconnect_until_tick]
	)


func _notify_session_suspended(room: Node, player_id: int) -> void:
	if not is_instance_valid(room):
		return
	var connected_peers := multiplayer.get_peers()
	for other: RefCounted in room.session_manager.sessions:
		if other.connected and other.peer_id in connected_peers:
			_rpc_player_left.rpc_id(other.peer_id, player_id, true)


func _on_phase_changed(room: Node) -> void:
	_broadcast_round_state(room)


func _on_meteor_spawned(
	room: Node,
	target: Vector3,
	drift: Vector2,
	damage: int,
	force: float
) -> void:
	for session: RefCounted in room.session_manager.sessions:
		if session.connected:
			_rpc_receive_meteor.rpc_id(
				session.peer_id,
				target,
				drift,
				damage,
				force
			)


func _on_shockwave_started(room: Node) -> void:
	for session: RefCounted in room.session_manager.sessions:
		if session.connected:
			_rpc_receive_shockwave.rpc_id(session.peer_id)


func _on_session_expired(room: Node, player_id: int) -> void:
	var connected_peers := multiplayer.get_peers()
	for session: RefCounted in room.session_manager.sessions:
		if session.connected and session.peer_id in connected_peers:
			_rpc_player_left.rpc_id(session.peer_id, player_id, false)
	print("SESSION_EXPIRED player=%d room=%d" % [player_id, room.room_id])


func _print_metrics() -> void:
	var elapsed := maxf(_metrics_elapsed, 0.001)
	var cpu_percent := float(_metrics_cpu_usec) / (elapsed * 1000000.0) * 100.0
	var memory_mib := float(OS.get_static_memory_usage()) / 1048576.0
	print(
		"SERVER_METRICS cpu_pct=%.3f memory_mib=%.2f rx_bps=%.1f tx_bps=%.1f inputs_ok=%d inputs_rejected=%d"
		% [
			cpu_percent,
			memory_mib,
			float(_bytes_received) / elapsed,
			float(_bytes_sent) / elapsed,
			_accepted_inputs,
			_rejected_inputs,
		]
	)
	_metrics_elapsed = 0.0
	_metrics_cpu_usec = 0
	_bytes_received = 0
	_bytes_sent = 0
	_accepted_inputs = 0
	_rejected_inputs = 0


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
