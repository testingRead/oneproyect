class_name ServerRoomState
extends Node

signal phase_changed
signal meteor_spawned(target: Vector3, drift: Vector2, damage: int, force: float)
signal shockwave_started
signal session_expired(player_id: int)

const NET := preload("res://shared/net_constants.gd")
const CODEC := preload("res://shared/net_codec.gd")
const SESSION_MANAGER_SCRIPT := preload("res://server/session_manager.gd")

var room_id := 1
var server_tick := 0
var phase := NET.RoomPhase.WAITING
var round_number := 0
var round_seed := 1
var phase_end_tick := 0
var mode_id := NET.ModeId.METEORS
var session_manager: Node
var host_player_id := 0
var auto_start_when_ready := false

var _snapshot_buffer := PackedByteArray()
var _random := RandomNumberGenerator.new()
var _next_mode_event_tick := 0


func _ready() -> void:
	session_manager = SESSION_MANAGER_SCRIPT.new()
	session_manager.name = "SessionManager"
	session_manager.room_id = room_id
	add_child(session_manager)
	session_manager.session_expired.connect(session_expired.emit)
	_snapshot_buffer = CODEC.create_snapshot_buffer()
	_random.seed = int(Time.get_unix_time_from_system()) ^ room_id
	round_seed = int(_random.randi() & 0x7fffffff)
	phase_end_tick = 0


func tick() -> void:
	server_tick += 1
	for session: RefCounted in session_manager.sessions:
		session.simulate(server_tick)
	session_manager.purge_expired(server_tick)
	_refresh_host()
	if (
		phase == NET.RoomPhase.WAITING
		and auto_start_when_ready
		and session_manager.connected_count() >= NET.MIN_PLAYERS_TO_START
	):
		start_rounds()
	if phase != NET.RoomPhase.WAITING and server_tick >= phase_end_tick:
		_advance_phase()
	if phase == NET.RoomPhase.ACTIVE:
		_tick_mode_events()


func build_snapshot() -> PackedByteArray:
	var connected_count: int = int(session_manager.connected_count())
	_snapshot_buffer.resize(CODEC.snapshot_size(connected_count))
	CODEC.write_snapshot_header(
		_snapshot_buffer,
		phase,
		connected_count,
		mode_id,
		server_tick,
		round_number,
		round_seed,
		phase_end_tick,
		room_id
	)
	var slot := 0
	for session: RefCounted in session_manager.sessions:
		if not session.connected:
			continue
		CODEC.write_snapshot_player(
			_snapshot_buffer,
			slot,
			session.player_id,
			session.player_flags(),
			session.health,
			session.last_input_sequence,
			session.position,
			session.velocity,
			session.facing_yaw,
			session.body_mask
		)
		slot += 1
	return _snapshot_buffer


func apply_input(peer_id: int, packet: PackedByteArray) -> bool:
	var session: RefCounted = session_manager.find_by_peer_id(peer_id)
	return session != null and session.accept_input(packet, server_tick)


func apply_push(peer_id: int, target_player_id: int, direction: Vector3) -> bool:
	var source: RefCounted = session_manager.find_by_peer_id(peer_id)
	var target: RefCounted = session_manager.find_by_player_id(target_player_id)
	if source == null or target == null or not target.connected or not target.active:
		return false
	var safe_direction := direction
	safe_direction.y = 0.0
	if not safe_direction.is_finite() or safe_direction.length_squared() < 0.01:
		return false
	safe_direction = safe_direction.normalized()
	var offset: Vector3 = target.position - source.position
	var horizontal_offset := Vector3(offset.x, 0.0, offset.z)
	if horizontal_offset.length() > 2.8:
		return false
	if horizontal_offset.normalized().dot(safe_direction) < 0.55:
		return false
	target.velocity.x += safe_direction.x * 5.2
	target.velocity.z += safe_direction.z * 5.2
	target.velocity.y = maxf(target.velocity.y, 2.2)
	return true


func seconds_left() -> float:
	if phase == NET.RoomPhase.WAITING:
		return 0.0
	return maxf(
		0.0,
		float(phase_end_tick - server_tick) / float(NET.SERVER_TICK_RATE)
	)


func accepts_new_players() -> bool:
	return (
		phase == NET.RoomPhase.WAITING
		and session_manager.sessions.size() < NET.MAX_PLAYERS_PER_ROOM
	)


func start_rounds() -> bool:
	if (
		phase != NET.RoomPhase.WAITING
		or session_manager.connected_count() < NET.MIN_PLAYERS_TO_START
	):
		return false
	phase = NET.RoomPhase.COUNTDOWN
	phase_end_tick = server_tick + 5 * NET.SERVER_TICK_RATE
	phase_changed.emit()
	return true


func is_host_peer(peer_id: int) -> bool:
	var session: RefCounted = session_manager.find_by_peer_id(peer_id)
	return session != null and session.player_id == host_player_id


func connected_count() -> int:
	return session_manager.connected_count()


func host_name() -> String:
	var host: RefCounted = session_manager.find_by_player_id(host_player_id)
	return host.display_name if host != null else ""


func _refresh_host() -> void:
	var current: RefCounted = session_manager.find_by_player_id(host_player_id)
	if current != null and current.connected:
		return
	host_player_id = 0
	for session: RefCounted in session_manager.sessions:
		if session.connected:
			host_player_id = session.player_id
			return


func _advance_phase() -> void:
	match phase:
		NET.RoomPhase.COUNTDOWN:
			phase = NET.RoomPhase.ACTIVE
			round_number += 1
			phase_end_tick = server_tick + NET.mode_duration_ticks(mode_id)
			_next_mode_event_tick = server_tick + 5
		NET.RoomPhase.ACTIVE:
			phase = NET.RoomPhase.RESULT
			phase_end_tick = server_tick + 6 * NET.SERVER_TICK_RATE
		_:
			phase = NET.RoomPhase.COUNTDOWN
			var previous_mode := mode_id
			while mode_id == previous_mode:
				mode_id = int(_random.randi_range(0, 2))
			round_seed = int(_random.randi() & 0x7fffffff)
			phase_end_tick = server_tick + 5 * NET.SERVER_TICK_RATE
	phase_changed.emit()


func _tick_mode_events() -> void:
	if server_tick < _next_mode_event_tick:
		return
	match mode_id:
		NET.ModeId.METEORS:
			var target := Vector3(
				_random.randf_range(-10.8, 10.8),
				0.06,
				_random.randf_range(-10.8, 10.8)
			)
			var drift := Vector2(
				_random.randf_range(-1.1, 1.1),
				_random.randf_range(-1.1, 1.1)
			)
			meteor_spawned.emit(target, drift, 22, 10.5)
			_next_mode_event_tick = server_tick + _random.randi_range(15, 29)
		NET.ModeId.SHOCKWAVE:
			shockwave_started.emit()
			_next_mode_event_tick = server_tick + _random.randi_range(65, 90)
		_:
			_next_mode_event_tick = phase_end_tick + 1
