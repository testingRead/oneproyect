extends SceneTree

const ROOM_SCRIPT := preload("res://server/room_state.gd")
const NET := preload("res://shared/net_constants.gd")
const ROOM_COUNT := 100
const MEASURED_TICKS := NET.SERVER_TICK_RATE * 10


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var baseline_rss := _rss_kib()
	var baseline_static := OS.get_static_memory_usage()
	var rooms: Array[Node] = []
	for room_index: int in ROOM_COUNT:
		var room: Node = ROOM_SCRIPT.new()
		room.room_id = room_index + 1
		root.add_child(room)
		rooms.append(room)
	await process_frame
	var empty_static := OS.get_static_memory_usage()
	var empty_started_usec := Time.get_ticks_usec()
	for _tick_index: int in MEASURED_TICKS:
		for room: Node in rooms:
			room.tick()
	var empty_elapsed_usec := Time.get_ticks_usec() - empty_started_usec
	var simulated_seconds := (
		float(MEASURED_TICKS) / float(NET.SERVER_TICK_RATE)
	)
	var empty_room_core_cpu_pct := (
		float(empty_elapsed_usec)
		/ (simulated_seconds * 1000000.0)
		* 100.0
	)

	for room_index: int in rooms.size():
		var room: Node = rooms[room_index]
		for player_index: int in NET.MAX_PLAYERS_PER_ROOM:
			var peer_id := room_index * NET.MAX_PLAYERS_PER_ROOM + player_index + 2
			room.session_manager.register_session(
				peer_id,
				"%016x" % peer_id,
				"",
				"Memory%d" % peer_id,
				player_index % 5,
				0,
				0,
				room.server_tick
			)
	await process_frame
	var waiting_static := OS.get_static_memory_usage()

	var snapshot_bytes := 0
	for room: Node in rooms:
		room.phase = NET.RoomPhase.ACTIVE
		for session: RefCounted in room.session_manager.sessions:
			snapshot_bytes += room.build_snapshot_for(session.player_id).size()
	await process_frame
	var active_rss := _rss_kib()
	var active_static := OS.get_static_memory_usage()
	var player_count := ROOM_COUNT * NET.MAX_PLAYERS_PER_ROOM
	print(
		"SERVER_MEMORY rooms=%d players=%d baseline_rss_mib=%.2f active_rss_mib=%.2f empty_room_static_kib=%.2f empty_rooms_core_cpu_pct=%.3f waiting_player_static_kib=%.2f snapshot_cache_static_kib=%.2f static_delta_kib=%.2f snapshot_bytes=%d"
		% [
			ROOM_COUNT,
			player_count,
			float(baseline_rss) / 1024.0,
			float(active_rss) / 1024.0,
			float(empty_static - baseline_static) / 1024.0 / float(ROOM_COUNT),
			empty_room_core_cpu_pct,
			float(waiting_static - empty_static) / 1024.0 / float(player_count),
			float(active_static - waiting_static) / 1024.0 / float(player_count),
			float(active_static - baseline_static) / 1024.0,
			snapshot_bytes,
		]
	)
	print(
		"SERVER_MEMORY_STATIC baseline_kib=%.2f empty_kib=%.2f waiting_kib=%.2f active_kib=%.2f"
		% [
			float(baseline_static) / 1024.0,
			float(empty_static) / 1024.0,
			float(waiting_static) / 1024.0,
			float(active_static) / 1024.0,
		]
	)
	quit(0)


func _rss_kib() -> int:
	var status := FileAccess.open("/proc/self/status", FileAccess.READ)
	if status == null:
		return 0
	while not status.eof_reached():
		var line := status.get_line()
		if line.begins_with("VmRSS:"):
			var value := line.trim_prefix("VmRSS:").strip_edges()
			return int(value.split(" ", false)[0])
	return 0
