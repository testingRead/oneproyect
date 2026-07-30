extends SceneTree

const NETWORK_SCRIPT := preload("res://client/network_client.gd")
const MAIN_SCENE := preload("res://scenes/main.tscn")
const CONNECT_TIMEOUT_MSEC := 8000
const MOVEMENT_TEST_MSEC := 1800

var network: Node
var address := "127.0.0.1"
var port := 9999
var accepted := false
var confirmed_states := 0
var latest_confirmed_sequence := 0
var failed := false


func _init() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--address="):
			address = argument.trim_prefix("--address=")
		elif argument.begins_with("--port="):
			port = clampi(int(argument.trim_prefix("--port=")), 1024, 65535)
	call_deferred("_setup")


func _setup() -> void:
	network = NETWORK_SCRIPT.new()
	network.name = "Network"
	root.add_child(network)
	network.server_port = port
	network.display_name = "MovimientoReal"
	network.color_index = 3
	network.configure_test_identity("%016x" % Time.get_ticks_usec())
	network.status_changed.connect(func(_text: String, online: bool) -> void:
		accepted = accepted or online
	)
	network.owned_state_confirmed.connect(func(sequence: int, _server_tick: int) -> void:
		confirmed_states += 1
		latest_confirmed_sequence = maxi(latest_confirmed_sequence, sequence)
	)
	var error: int = network.connect_to_server(address)
	_require(error == OK, "client ENet creation failed")
	if error != OK:
		return
	_run()


func _run() -> void:
	var connect_started := Time.get_ticks_msec()
	while (
		not network.is_online()
		and Time.get_ticks_msec() - connect_started < CONNECT_TIMEOUT_MSEC
	):
		await process_frame
	_require(network.is_online(), "server did not accept the movement client")
	if not network.is_online():
		return
	await create_timer(0.25).timeout

	var game := MAIN_SCENE.instantiate()
	root.add_child(game)
	await process_frame
	await physics_frame
	var player: GrayboxPlayer = game.get_node("World/Player")
	var disaster: DisasterController = game.get_node("World/DisasterController")
	disaster.set_physics_process(false)
	if network.meteor_received.is_connected(disaster.spawn_network_meteor):
		network.meteor_received.disconnect(disaster.spawn_network_meteor)
	if network.shockwave_received.is_connected(disaster.spawn_network_shockwave):
		network.shockwave_received.disconnect(disaster.spawn_network_shockwave)
	if network.round_state_received.is_connected(disaster.apply_network_state):
		network.round_state_received.disconnect(disaster.apply_network_state)

	player.global_position = Vector3(0.0, 1.2, 4.8)
	player.velocity = Vector3.ZERO
	player.set_touch_move(Vector2.RIGHT)
	var started := Time.get_ticks_msec()
	var previous_position := player.global_position
	var moving_frames := 0
	var stalled_frames := 0
	var backwards_frames := 0
	var distance_travelled := 0.0
	while Time.get_ticks_msec() - started < MOVEMENT_TEST_MSEC:
		await physics_frame
		var elapsed := Time.get_ticks_msec() - started
		var displacement := player.global_position - previous_position
		var horizontal_distance := Vector2(displacement.x, displacement.z).length()
		distance_travelled += horizontal_distance
		if elapsed > 300:
			moving_frames += 1
			stalled_frames += int(horizontal_distance < 0.015)
			backwards_frames += int(displacement.x < -0.002)
		previous_position = player.global_position
	player.set_touch_move(Vector2.ZERO)
	await create_timer(0.4).timeout

	var local_stop_position := player.global_position
	await create_timer(0.8).timeout
	var network_drift := player.global_position.distance_to(local_stop_position)
	_require(distance_travelled > 7.0, "local owner movement did not cover the expected distance")
	_require(
		stalled_frames <= maxi(2, moving_frames / 20),
		"local movement stalled as if it still depended on snapshots"
	)
	_require(backwards_frames == 0, "network traffic moved the local owner backwards")
	_require(network_drift < 0.12, "server snapshots changed the stopped local body")
	_require(confirmed_states >= 10, "server did not confirm enough compact owner states")
	_require(latest_confirmed_sequence > 0, "state sequence was not relayed")

	player.global_position = Vector3(0.0, 1.2, 0.0)
	player.velocity = Vector3.ZERO
	player.heal_full()
	await physics_frame
	var meteor: MeteorSlot = disaster.get_node("MeteorMode").get_child(0)
	meteor.launch(Vector3(0.0, 0.06, 0.0), Vector2.ZERO, 0.01, 22, 10.5)
	var max_player_height := player.global_position.y
	for frame in 190:
		await physics_frame
		max_player_height = maxf(max_player_height, player.global_position.y)
	var damaged_health := player.get_health()
	_require(damaged_health < GrayboxPlayer.MAX_HEALTH, "meteor did not damage the owner")
	_require(max_player_height > 1.55, "meteor impulse did not launch the owner")
	await create_timer(1.0).timeout
	_require(
		player.get_health() == damaged_health,
		"server snapshot restored owner health after local hazard physics"
	)

	var enet := network.multiplayer.multiplayer_peer as ENetMultiplayerPeer
	var server_peer: ENetPacketPeer = enet.get_peer(1)
	var packet_loss := float(server_peer.get_statistic(
		ENetPacketPeer.PEER_PACKET_LOSS
	)) / float(ENetPacketPeer.PACKET_LOSS_SCALE)
	var round_trip_msec := int(server_peer.get_statistic(
		ENetPacketPeer.PEER_ROUND_TRIP_TIME
	))
	print(
		"REAL_MOVEMENT_RESULT confirmed=%d sent=%d moving_frames=%d stalled=%d backwards=%d travelled_m=%.3f stop_drift_m=%.3f meteor_health=%d meteor_peak_y=%.3f loss=%.4f rtt_ms=%d"
		% [
			confirmed_states,
			network._state_sequence,
			moving_frames,
			stalled_frames,
			backwards_frames,
			distance_travelled,
			network_drift,
			damaged_health,
			max_player_height,
			packet_loss,
			round_trip_msec,
		]
	)
	network.disconnect_session()
	# Keep the process alive briefly so ENet can finish its cooperative
	# disconnect instead of losing all channels during the server's last send.
	await create_timer(0.25).timeout
	if failed:
		quit(1)
		return
	quit(0)


func _require(condition: bool, message: String) -> void:
	if condition:
		return
	failed = true
	push_error("REAL_MOVEMENT_FAIL: " + message)
