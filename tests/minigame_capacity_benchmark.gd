extends SceneTree

const ROOM_SCRIPT := preload("res://server/room_state.gd")
const NET := preload("res://shared/net_constants.gd")
const ROOM_COUNT := 20
const PLAYER_COUNT := ROOM_COUNT * NET.MAX_PLAYERS_PER_ROOM
const MEASURED_TICKS := NET.SERVER_TICK_RATE * 10
const BALL_STATE_BYTES := 24
const PROJECTILE_STATE_BYTES := 16
const PROJECTILES_PER_PLAYER := 2


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	for workload: StringName in [&"survival", &"soccer", &"shooter"]:
		await _measure(workload)
	quit(0)


func _measure(workload: StringName) -> void:
	var rooms: Array[Node] = []
	var ball_positions := PackedVector3Array()
	var ball_velocities := PackedVector3Array()
	var projectile_positions: Array[PackedVector3Array] = []
	var projectile_velocities: Array[PackedVector3Array] = []
	for room_index: int in ROOM_COUNT:
		var room: Node = ROOM_SCRIPT.new()
		room.room_id = room_index + 1
		root.add_child(room)
		await process_frame
		rooms.append(room)
		for player_index: int in NET.MAX_PLAYERS_PER_ROOM:
			var peer_id := room_index * NET.MAX_PLAYERS_PER_ROOM + player_index + 2
			room.session_manager.register_session(
				peer_id,
				"%016x" % peer_id,
				"",
				"Mode%d" % peer_id,
				player_index % 5,
				0,
				0,
				room.server_tick
			)
		room.phase = NET.RoomPhase.ACTIVE
		ball_positions.append(Vector3.ZERO)
		ball_velocities.append(Vector3(4.0, 0.0, 2.5))
		var positions := PackedVector3Array()
		var velocities := PackedVector3Array()
		for projectile_index: int in (
			NET.MAX_PLAYERS_PER_ROOM * PROJECTILES_PER_PLAYER
		):
			positions.append(
				Vector3(float(projectile_index) * 0.3 - 1.5, 1.2, 0.0)
			)
			velocities.append(
				Vector3(6.0, 0.0, -2.0 if projectile_index % 2 else 2.0)
			)
		projectile_positions.append(positions)
		projectile_velocities.append(velocities)

	var packet_bytes := 0
	var rule_events := 0
	var started_usec := Time.get_ticks_usec()
	for _tick_index: int in MEASURED_TICKS:
		for room_index: int in rooms.size():
			var room: Node = rooms[room_index]
			room.tick()
			match workload:
				&"soccer":
					var ball_position := ball_positions[room_index]
					var ball_velocity := ball_velocities[room_index]
					ball_position += ball_velocity * NET.SERVER_TICK_DELTA
					if absf(ball_position.x) > 11.0:
						ball_position.x = signf(ball_position.x) * 11.0
						ball_velocity.x *= -1.0
						rule_events += 1
					if absf(ball_position.z) > 6.0:
						ball_position.z = signf(ball_position.z) * 6.0
						ball_velocity.z *= -1.0
					ball_positions[room_index] = ball_position
					ball_velocities[room_index] = ball_velocity
				&"shooter":
					var positions := projectile_positions[room_index]
					var velocities := projectile_velocities[room_index]
					for projectile_index: int in positions.size():
						var position := positions[projectile_index]
						position += (
							velocities[projectile_index]
							* NET.SERVER_TICK_DELTA
						)
						if absf(position.x) > 12.0 or absf(position.z) > 12.0:
							position = Vector3.ZERO
							rule_events += 1
						for session: RefCounted in room.session_manager.sessions:
							if position.distance_squared_to(session.position) < 0.36:
								rule_events += 1
						positions[projectile_index] = position
					projectile_positions[room_index] = positions
			if room.server_tick % NET.SNAPSHOT_INTERVAL_TICKS != 0:
				continue
			for session: RefCounted in room.session_manager.sessions:
				packet_bytes += room.build_snapshot_for(session.player_id).size()
				if workload == &"soccer":
					packet_bytes += BALL_STATE_BYTES
				elif workload == &"shooter":
					packet_bytes += (
						PROJECTILE_STATE_BYTES
						* NET.MAX_PLAYERS_PER_ROOM
						* PROJECTILES_PER_PLAYER
					)
	var elapsed_usec := Time.get_ticks_usec() - started_usec
	var simulated_seconds := (
		float(MEASURED_TICKS) / float(NET.SERVER_TICK_RATE)
	)
	print(
		"MINIGAME_CAPACITY workload=%s rooms=%d players=%d core_cpu_pct=%.3f app_tx_kib_s=%.2f rule_events=%d"
		% [
			workload,
			ROOM_COUNT,
			PLAYER_COUNT,
			float(elapsed_usec)
			/ (simulated_seconds * 1000000.0)
			* 100.0,
			float(packet_bytes) / simulated_seconds / 1024.0,
			rule_events,
		]
	)
	for room: Node in rooms:
		root.remove_child(room)
		room.free()
	await process_frame
