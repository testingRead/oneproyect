extends SceneTree

const ROOM_SCRIPT := preload("res://server/room_state.gd")
const NET := preload("res://shared/net_constants.gd")
const ROOM_COUNTS := [1, 5, 20, 50]
const MEASURED_TICKS := NET.SERVER_TICK_RATE * 10

var _failed := false


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	for room_count: int in ROOM_COUNTS:
		await _measure(room_count)
		if _failed:
			break
	quit(1 if _failed else 0)


func _measure(room_count: int) -> void:
	var rooms: Array[Node] = []
	for room_index: int in room_count:
		var room: Node = ROOM_SCRIPT.new()
		room.room_id = room_index + 1
		root.add_child(room)
		await process_frame
		rooms.append(room)
		for player_index: int in NET.MAX_PLAYERS_PER_ROOM:
			var peer_id := room_index * NET.MAX_PLAYERS_PER_ROOM + player_index + 2
			var session: RefCounted = room.session_manager.register_session(
				peer_id,
				"%016x" % peer_id,
				"",
				"Bench%d" % peer_id,
				player_index % 5,
				0,
				0,
				room.server_tick
			)
			if session == null:
				_fail("could not fill synthetic room")
				return
		room.phase = NET.RoomPhase.ACTIVE

	var packet_bytes := 0
	var snapshot_count := 0
	var started_usec := Time.get_ticks_usec()
	for _tick_index: int in MEASURED_TICKS:
		for room: Node in rooms:
			room.tick()
			if room.server_tick % NET.SNAPSHOT_INTERVAL_TICKS != 0:
				continue
			for session: RefCounted in room.session_manager.sessions:
				var packet: PackedByteArray = room.build_snapshot_for(session.player_id)
				packet_bytes += packet.size()
				snapshot_count += 1
	var elapsed_usec := Time.get_ticks_usec() - started_usec
	var simulated_seconds := (
		float(MEASURED_TICKS) / float(NET.SERVER_TICK_RATE)
	)
	var players := room_count * NET.MAX_PLAYERS_PER_ROOM
	var core_cpu_percent := (
		float(elapsed_usec)
		/ (simulated_seconds * 1000000.0)
		* 100.0
	)
	print(
		"SERVER_CAPACITY rooms=%d players=%d core_cpu_pct=%.3f app_tx_kib_s=%.2f snapshots=%d memory_mib=%.2f"
		% [
			room_count,
			players,
			core_cpu_percent,
			float(packet_bytes) / simulated_seconds / 1024.0,
			snapshot_count,
			float(OS.get_static_memory_usage()) / 1048576.0,
		]
	)
	for room: Node in rooms:
		root.remove_child(room)
		room.free()
	await process_frame


func _fail(message: String) -> void:
	_failed = true
	push_error("SERVER_CAPACITY_FAIL: " + message)
