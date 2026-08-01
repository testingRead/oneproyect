extends SceneTree

const NETWORK_SCRIPT := preload("res://client/network_client.gd")
const NET := preload("res://shared/net_constants.gd")
const TIMEOUT_MSEC := 12000

var network: Node
var role := "host"
var address := "127.0.0.1"
var port := NET.DEFAULT_PORT
var joined := false
var saw_two_players := false
var started := false
var requested_create := false
var requested_join := false
var requested_ready := false
var requested_start := false
var returned_to_lobby := false
var replayed_remote := false


func _init() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--role="):
			role = argument.trim_prefix("--role=")
		elif argument.begins_with("--address="):
			address = argument.trim_prefix("--address=")
		elif argument.begins_with("--port="):
			port = int(argument.trim_prefix("--port="))
	call_deferred("_setup")


func _setup() -> void:
	network = NETWORK_SCRIPT.new()
	network.name = "Network"
	root.add_child(network)
	network.server_port = port
	network.display_name = role.capitalize()
	network.color_index = 1 if role == "host" else 2
	network.configure_test_identity(
		"cccccccccccccccc" if role == "host" else "dddddddddddddddd"
	)
	network.lobby_ready.connect(_on_lobby_ready)
	network.room_list_updated.connect(_on_room_list)
	network.room_waiting_updated.connect(_on_room_waiting)
	network.room_started.connect(func(_room_id: int) -> void:
		started = true
	)
	network.room_action_failed.connect(func(reason: String) -> void:
		_fail("room action rejected: " + reason)
	)
	network.returned_to_lobby.connect(func() -> void:
		returned_to_lobby = true
	)
	var error: int = network.connect_to_lobby(address)
	if error != OK:
		_fail("client ENet creation failed")
		return
	_run()


func _on_lobby_ready(maximum_rooms: int, maximum_players: int) -> void:
	if maximum_rooms != NET.MAX_ROOMS or maximum_players != NET.MAX_PLAYERS_PER_ROOM:
		_fail("server advertised incorrect room limits")
		return
	if role == "host" and not requested_create:
		requested_create = true
		network.create_room()
	else:
		network.request_room_list()


func _on_room_list(
	room_ids: PackedInt32Array,
	player_counts: PackedInt32Array,
	phases: PackedInt32Array,
	_host_names: PackedStringArray
) -> void:
	if role != "joiner" or requested_join:
		return
	for index in room_ids.size():
		if (
			phases[index] == NET.RoomPhase.WAITING
			and player_counts[index] < NET.MAX_PLAYERS_PER_ROOM
		):
			requested_join = true
			network.join_room(room_ids[index])
			return


func _on_room_waiting(
	_room_id: int,
	player_count: int,
	is_host: bool,
	_ready_count: int,
	local_ready: bool,
	all_ready: bool,
	_player_names: PackedStringArray,
	_ready_flags: PackedByteArray,
	_character_indices: PackedByteArray,
	_victory_counts: PackedInt32Array,
	_experience_values: PackedInt32Array,
	_session_scores: PackedInt32Array
) -> void:
	joined = true
	saw_two_players = saw_two_players or player_count >= NET.MIN_PLAYERS_TO_START
	if not local_ready and not requested_ready:
		requested_ready = true
		network.set_room_profile(true)
	if (
		role == "host"
		and is_host
		and saw_two_players
		and all_ready
		and not requested_start
	):
		requested_start = true
		network.start_room()


func _run() -> void:
	var started_msec := Time.get_ticks_msec()
	while Time.get_ticks_msec() - started_msec < TIMEOUT_MSEC:
		await process_frame
		if joined and saw_two_players and started:
			var completed_room_id: int = network.get_room_id()
			var replay_count := [0]
			network.remote_player_joined.connect(func(
				_player_id: int,
				_name: String,
				_color: int
			) -> void:
				var expected_color := 2 if role == "host" else 1
				if _color != expected_color:
					_fail("cached remote character selection was not preserved")
					return
				replay_count[0] += 1
			)
			network.replay_remote_players()
			await process_frame
			if replay_count[0] != 1:
				_fail("late game scene did not reconstruct the cached remote avatar")
				return
			replayed_remote = true
			await create_timer(0.35 if role == "host" else 0.9).timeout
			network.leave_room()
			var leave_started := Time.get_ticks_msec()
			while (
				not returned_to_lobby
				and Time.get_ticks_msec() - leave_started < 2000
			):
				await process_frame
			if not returned_to_lobby:
				_fail("server did not acknowledge leaving the room")
				return
			print(
				"LOBBY_PROBE_OK role=%s room=%d players=2 ready=true replay=true"
				% [role, completed_room_id]
			)
			network.disconnect_session()
			quit(0)
			return
	_fail("timed out waiting for room creation/join/start")


func _fail(message: String) -> void:
	push_error("LOBBY_PROBE_FAIL role=%s: %s" % [role, message])
	quit(1)
