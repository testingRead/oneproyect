extends SceneTree

const NETWORK_SCRIPT := preload("res://client/network_client.gd")
const NET := preload("res://shared/net_constants.gd")
const TIMEOUT_MSEC := 16000

var network: Node
var role := "observer"
var address := "127.0.0.1"
var port := 9999
var accepted := false
var saw_remote := false
var saw_remote_movement := false
var saw_relay_confirmation := false
var saw_state_sequence := false
var saw_round_state := false
var saw_suspension := false
var resumed := false
var reconnect_id_preserved := false
var remote_join_count := 0
var local_player_id_before_drop := 0
var position_before_drop := Vector3.ZERO
var latest_owner_position := Vector3.ZERO
var drop_requested := false
var resumed_at_msec := 0


func _init() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--role="):
			role = argument.trim_prefix("--role=")
		elif argument.begins_with("--address="):
			address = argument.trim_prefix("--address=")
		elif argument.begins_with("--port="):
			port = clampi(int(argument.trim_prefix("--port=")), 1024, 65535)
	call_deferred("_setup")


func _setup() -> void:
	network = NETWORK_SCRIPT.new()
	network.name = "Network"
	root.add_child(network)
	network.server_port = port
	network.display_name = role.capitalize()
	network.color_index = 1 if role == "host" else 2
	network.configure_test_identity(
		"aaaaaaaaaaaaaaaa" if role == "host" else "bbbbbbbbbbbbbbbb"
	)
	network.status_changed.connect(func(_text: String, online: bool) -> void:
		accepted = accepted or online
	)
	network.remote_player_joined.connect(func(
		_player_id: int,
		_name: String,
		_color: int
	) -> void:
		saw_remote = true
		remote_join_count += 1
	)
	network.remote_session_suspended.connect(func(_player_id: int) -> void:
		saw_suspension = true
	)
	network.remote_snapshot.connect(func(
		_player_id: int,
		position: Vector3,
		_velocity: Vector3,
		_yaw: float,
		body_mask: int,
		_health: int
	) -> void:
		if body_mask == 0b111111111111 and position.x > 0.45:
			saw_remote_movement = true
	)
	network.owned_state_confirmed.connect(func(
		state_sequence: int,
		_server_tick: int
	) -> void:
		saw_relay_confirmation = true
		saw_state_sequence = saw_state_sequence or state_sequence > 0
	)
	network.round_state_received.connect(func(
		_state: int,
		_round: int,
		_time: float,
		mode_id: String,
		map_id: String,
		_seed: int,
		_features: PackedStringArray,
		_profile: String,
		_spawn: String,
		_spectator: String
	) -> void:
		saw_round_state = (
			mode_id in ["meteors", "shockwave", "flood"]
			and map_id == "plaza_caos"
		)
	)
	network.session_resumed.connect(func(player_id: int) -> void:
		resumed = true
		reconnect_id_preserved = player_id == local_player_id_before_drop
		resumed_at_msec = Time.get_ticks_msec()
	)
	var error: int = network.connect_to_server(address)
	_require(error == OK, "client ENet creation failed")
	_run()


func _run() -> void:
	var started_msec := Time.get_ticks_msec()
	var next_state_msec := started_msec
	while Time.get_ticks_msec() - started_msec < TIMEOUT_MSEC:
		await process_frame
		var now_msec := Time.get_ticks_msec()
		if network.is_online() and now_msec >= next_state_msec:
			next_state_msec = now_msec + 50
			var elapsed := float(now_msec - started_msec) / 1000.0
			latest_owner_position = Vector3(
				minf(elapsed * 0.8, 7.0) if role == "host" else 0.0,
				1.2,
				8.0
			)
			network.submit_owned_state(
				latest_owner_position,
				Vector3(0.8, 0.0, 0.0) if role == "host" else Vector3.ZERO,
				0.5,
				100,
				NET.ALL_BODY_PARTS_MASK
			)
		if (
			role == "host"
			and not drop_requested
			and saw_state_sequence
			and latest_owner_position.x > 0.45
			and now_msec - started_msec > 2200
		):
			drop_requested = true
			local_player_id_before_drop = network.get_local_player_id()
			position_before_drop = latest_owner_position
			network.simulate_network_drop_for_test()
		if _is_complete(now_msec):
			print(
				"NETWORK_PROBE_OK role=%s accepted=%s remote=%s confirmed=%s sequence=%s moved=%s round=%s suspended=%s resumed=%s same_id=%s"
				% [
					role,
					accepted,
					saw_remote,
					saw_relay_confirmation,
					saw_state_sequence,
					saw_remote_movement,
					saw_round_state,
					saw_suspension,
					resumed,
					reconnect_id_preserved,
				]
			)
			network.disconnect_session()
			quit(0)
			return
	_require(false, "timed out waiting for relayed movement/reconnection")


func _is_complete(now_msec: int) -> bool:
	if role == "host":
		return (
			accepted
			and saw_remote
			and saw_relay_confirmation
			and saw_state_sequence
			and drop_requested
			and resumed
			and reconnect_id_preserved
			and latest_owner_position.x >= position_before_drop.x - 0.25
			and now_msec - resumed_at_msec >= 1200
		)
	return (
		accepted
		and saw_remote
		and saw_remote_movement
		and saw_round_state
		and saw_suspension
		and remote_join_count >= 2
	)


func _require(condition: bool, message: String) -> void:
	if condition:
		return
	push_error("NETWORK_PROBE_FAIL role=%s: %s" % [role, message])
	quit(1)
