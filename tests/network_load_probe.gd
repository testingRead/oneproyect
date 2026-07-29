extends SceneTree

const NETWORK_SCRIPT := preload("res://client/network_client.gd")
const NET := preload("res://shared/net_constants.gd")
const RUN_MSEC := 7000

var network: Node
var client_index := 1
var address := "127.0.0.1"
var port := 9999
var accepted := false
var saw_remote_state := false
var confirmed := false


func _init() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--client="):
			client_index = clampi(int(argument.trim_prefix("--client=")), 1, 5)
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
	network.display_name = "Carga%d" % client_index
	network.color_index = (client_index - 1) % 5
	network.configure_test_identity("%016x" % client_index)
	network.status_changed.connect(func(_text: String, online: bool) -> void:
		accepted = accepted or online
	)
	network.owned_state_confirmed.connect(func(
		sequence: int,
		_server_tick: int
	) -> void:
		confirmed = confirmed or sequence > 0
	)
	network.remote_snapshot.connect(func(
		_player_id: int,
		_position: Vector3,
		_velocity: Vector3,
		_yaw: float,
		_body_mask: int,
		_health: int
	) -> void:
		saw_remote_state = true
	)
	var error: int = network.connect_to_server(address)
	_require(error == OK, "client ENet creation failed")
	_run()


func _run() -> void:
	var started_msec := Time.get_ticks_msec()
	var next_state_msec := started_msec
	var angle := float(client_index - 1) / 5.0 * TAU
	var run_msec := RUN_MSEC + client_index * 250
	while Time.get_ticks_msec() - started_msec < run_msec:
		await process_frame
		var now_msec := Time.get_ticks_msec()
		if network.is_online() and now_msec >= next_state_msec:
			next_state_msec = now_msec + 50
			var elapsed := float(now_msec - started_msec) / 1000.0
			var position := Vector3(
				cos(angle) * minf(elapsed * 0.7, 4.0),
				1.2,
				8.0 + sin(angle) * minf(elapsed * 0.7, 4.0)
			)
			var velocity := Vector3(cos(angle) * 0.7, 0.0, sin(angle) * 0.7)
			network.submit_owned_state(
				position,
				velocity,
				angle,
				100,
				NET.ALL_BODY_PARTS_MASK
			)
	_require(accepted, "session was not accepted")
	_require(confirmed, "server did not confirm owned states")
	_require(saw_remote_state, "client did not receive another owner's state")
	print(
		"NETWORK_LOAD_OK client=%d accepted=%s confirmed=%s remote=%s"
		% [client_index, accepted, confirmed, saw_remote_state]
	)
	network.disconnect_session()
	quit(0)


func _require(condition: bool, message: String) -> void:
	if condition:
		return
	push_error("NETWORK_LOAD_FAIL client=%d: %s" % [client_index, message])
	quit(1)
