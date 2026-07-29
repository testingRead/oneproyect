extends SceneTree

const NETWORK_SCRIPT := preload("res://client/network_client.gd")
const RUN_MSEC := 7000

var network: Node
var client_index := 1
var address := "127.0.0.1"
var port := 9999
var accepted := false
var authoritative := false
var acknowledged := false


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
	network.set_prediction_origin(Vector3(0.0, 1.2, 8.0))
	network.status_changed.connect(func(_text: String, online: bool) -> void:
		accepted = accepted or online
	)
	network.authoritative_state.connect(func(
		_position: Vector3,
		_velocity: Vector3,
		_yaw: float,
		_health: int,
		_body_mask: int,
		ack_sequence: int,
		_server_tick: int
	) -> void:
		authoritative = true
		acknowledged = acknowledged or ack_sequence > 0
	)
	var error: int = network.connect_to_server(address)
	_require(error == OK, "client ENet creation failed")
	_run()


func _run() -> void:
	var started_msec := Time.get_ticks_msec()
	var next_input_msec := started_msec
	var angle := float(client_index - 1) / 5.0 * TAU
	var move := Vector2(cos(angle), sin(angle)) * 0.65
	var run_msec := RUN_MSEC + client_index * 250
	while Time.get_ticks_msec() - started_msec < run_msec:
		await process_frame
		var now_msec := Time.get_ticks_msec()
		if network.is_online() and now_msec >= next_input_msec:
			next_input_msec = now_msec + 50
			network.submit_input(move, angle, false)
	_require(accepted, "session was not accepted")
	_require(authoritative, "authoritative snapshots were not received")
	_require(acknowledged, "server did not acknowledge inputs")
	print(
		"NETWORK_LOAD_OK client=%d accepted=%s authoritative=%s ack=%s"
		% [client_index, accepted, authoritative, acknowledged]
	)
	network.disconnect_session()
	quit(0)


func _require(condition: bool, message: String) -> void:
	if condition:
		return
	push_error("NETWORK_LOAD_FAIL client=%d: %s" % [client_index, message])
	quit(1)
