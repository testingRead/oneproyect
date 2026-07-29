extends SceneTree

const NET := preload("res://shared/net_constants.gd")
const CODEC := preload("res://shared/net_codec.gd")
const ROOM_SCRIPT := preload("res://server/room_state.gd")
const ROOM_MANAGER_SCRIPT := preload("res://server/room_manager.gd")


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var manager: Node = ROOM_MANAGER_SCRIPT.new()
	manager.name = "RoomManagerTest"
	root.add_child(manager)
	await process_frame
	for room_id in range(1, NET.MAX_ROOMS + 1):
		_require(manager.create_room(room_id) != null, "Five rooms must be creatable")
	_require(manager.create_room() == null, "A sixth room must be rejected")
	_require(manager.rooms.size() == NET.MAX_ROOMS, "Room manager must enforce its hard limit")
	_require(
		NET.MAX_SERVER_CONNECTIONS == NET.MAX_ROOMS * NET.MAX_PLAYERS_PER_ROOM,
		"ENet capacity must cover every room"
	)
	var empty_room: Node = manager.find_room(3)
	_require(manager.remove_room(empty_room), "An empty room must release its slot")
	_require(manager.create_room(3) != null, "A released room ID must be reusable")
	manager.queue_free()

	var room: Node = ROOM_SCRIPT.new()
	room.name = "RoomTest"
	root.add_child(room)
	await process_frame
	_require(room.phase == NET.RoomPhase.WAITING, "New rooms must wait in the lobby")

	var first: RefCounted = room.session_manager.register_session(
		20,
		"aaaaaaaaaaaaaaaa",
		"",
		"Ana",
		2,
		room.server_tick
	)
	var second: RefCounted = room.session_manager.register_session(
		21,
		"bbbbbbbbbbbbbbbb",
		"",
		"Beto",
		3,
		room.server_tick
	)
	_require(first != null and second != null, "Fixed room must accept two sessions")
	_require(first.player_id != second.player_id, "Logical player IDs must be stable and unique")
	_require(
		room.session_manager.connected_count() == NET.MIN_PLAYERS_TO_START,
		"Room must count the minimum two connected players"
	)
	_require(
		not room.start_rounds(),
		"Lobby room must reject an arbitrary start before everyone is ready"
	)
	first.ready = true
	second.ready = true
	_require(room.start_rounds(), "Host-ready room must enter countdown with two players")
	room.phase_end_tick = room.server_tick + 1
	room.tick()
	_require(room.phase == NET.RoomPhase.ACTIVE, "Countdown must advance to active play")

	var input := CODEC.create_input_buffer()
	CODEC.write_input(input, 1, Vector2(1.0, 0.0), 0.5, NET.InputFlags.JUMP)
	_require(room.apply_input(20, input), "Valid ordered input must be accepted")
	var start_position: Vector3 = first.position
	room.tick()
	_require(first.position.x > start_position.x, "Server must integrate horizontal movement")
	_require(first.position.y > NET.FLOOR_HEIGHT, "Server must integrate jump")
	_require(first.last_input_sequence == 1, "Server must acknowledge processed input")
	_require(not room.apply_input(20, input), "Duplicate input sequence must be rejected")

	var snapshot: PackedByteArray = room.build_snapshot()
	_require(CODEC.is_valid_snapshot(snapshot), "Room snapshot must use compact shared codec")
	_require(CODEC.snapshot_player_count(snapshot) == 2, "Snapshot must include connected players")
	_require(snapshot.size() == 68, "Two-player snapshot must omit three unused player slots")
	_require(
		CODEC.snapshot_player_ack(snapshot, 0) == 1,
		"Snapshot must expose the last authoritative input sequence"
	)

	var first_id: int = first.player_id
	var first_token: String = first.reconnect_token
	room.host_player_id = first.player_id
	room.session_manager.mark_disconnected(20, room.server_tick)
	room.tick()
	_require(
		room.host_player_id == second.player_id,
		"A connected player must inherit host when the creator disconnects"
	)
	var resumed: RefCounted = room.session_manager.register_session(
		44,
		"aaaaaaaaaaaaaaaa",
		first_token,
		"Ana",
		2,
		room.server_tick + 20
	)
	_require(resumed == first, "Reconnect must resume the same session object")
	_require(
		resumed.player_id == first_id
		and resumed.peer_id == 44
		and room.session_manager.last_registration_reconnected,
		"Reconnect must preserve identity while replacing peer_id"
	)

	var expired_state := [false]
	room.session_manager.session_expired.connect(func(player_id: int) -> void:
		expired_state[0] = player_id == first_id
	)
	room.session_manager.mark_disconnected(44, room.server_tick)
	room.session_manager.purge_expired(room.server_tick + NET.RECONNECT_TICKS + 1)
	_require(expired_state[0], "Disconnected session must expire after 60 seconds")
	_require(
		room.session_manager.find_by_player_id(first_id) == null,
		"Expired session must free its room slot"
	)
	print(
		"SERVER_ROOM_OK tick=%d players=%d snapshot_bytes=%d reconnect_ticks=%d"
		% [
			room.server_tick,
			room.session_manager.connected_count(),
			snapshot.size(),
			NET.RECONNECT_TICKS,
		]
	)
	quit(0)


func _require(condition: bool, message: String) -> void:
	if condition:
		return
	push_error("SERVER_ROOM_FAIL: " + message)
	quit(1)
