extends SceneTree

const NETWORK_SCRIPT := preload("res://client/network_client.gd")
const MAIN_SCENE := preload("res://scenes/main.tscn")
const RUN_MSEC := 12000
const CONNECT_TIMEOUT_MSEC := 8000

var network: Node
var address := "127.0.0.1"
var port := 9999
var accepted := false
var authoritative_samples := 0
var latest_authoritative_position := Vector3.ZERO
var latest_ack_sequence := 0
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
	network.configure_test_identity("e1a2b3c4d5e6f708")
	network.status_changed.connect(func(_text: String, online: bool) -> void:
		accepted = accepted or online
	)
	network.authoritative_state.connect(func(
		position: Vector3,
		_velocity: Vector3,
		_yaw: float,
		_health: int,
		_body_mask: int,
		ack_sequence: int,
		_server_tick: int
	) -> void:
		authoritative_samples += 1
		latest_authoritative_position = position
		latest_ack_sequence = ack_sequence
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
	player.set_touch_move(Vector2.ZERO)
	await create_timer(1.0).timeout
	player.reset_network_correction_diagnostics()
	player.network_correction_applied.connect(func(
		hard: bool,
		error: float,
		local_position: Vector3,
		authoritative_position: Vector3,
		local_velocity: Vector3,
		authoritative_velocity: Vector3,
		move: Vector2
	) -> void:
		print(
			"REAL_MOVEMENT_CORRECTION hard=%s error=%.3f local=(%.2f,%.2f) auth=(%.2f,%.2f) local_v=(%.2f,%.2f) auth_v=(%.2f,%.2f) move=(%.2f,%.2f)"
			% [
				hard,
				error,
				local_position.x,
				local_position.z,
				authoritative_position.x,
				authoritative_position.z,
				local_velocity.x,
				local_velocity.z,
				authoritative_velocity.x,
				authoritative_velocity.z,
				move.x,
				move.y,
			]
		)
	)

	var started := Time.get_ticks_msec()
	var previous_position := player.global_position
	var backwards_frames := 0
	var backwards_distance := 0.0
	var distance_travelled := 0.0
	var max_visual_authority_gap := 0.0
	while Time.get_ticks_msec() - started < RUN_MSEC:
		var elapsed := Time.get_ticks_msec() - started
		var phase := int(elapsed / 1500) % 2
		var move := Vector2.RIGHT if phase == 0 else Vector2.LEFT
		player.set_touch_move(move)
		await physics_frame
		var displacement := player.global_position - previous_position
		var along_move := Vector2(displacement.x, displacement.z).dot(move)
		if along_move < -0.01:
			backwards_frames += 1
			backwards_distance -= along_move
		distance_travelled += Vector2(displacement.x, displacement.z).length()
		max_visual_authority_gap = maxf(
			max_visual_authority_gap,
			Vector2(
				player.global_position.x - latest_authoritative_position.x,
				player.global_position.z - latest_authoritative_position.z
			).length()
		)
		previous_position = player.global_position
	player.set_touch_move(Vector2.ZERO)
	var enet := network.multiplayer.multiplayer_peer as ENetMultiplayerPeer
	var server_peer: ENetPacketPeer = enet.get_peer(1)
	var packet_throttle := int(server_peer.get_statistic(
		ENetPacketPeer.PEER_PACKET_THROTTLE
	))
	var packet_throttle_limit := int(server_peer.get_statistic(
		ENetPacketPeer.PEER_PACKET_THROTTLE_LIMIT
	))
	var packet_loss := float(server_peer.get_statistic(
		ENetPacketPeer.PEER_PACKET_LOSS
	)) / float(ENetPacketPeer.PACKET_LOSS_SCALE)
	var round_trip_msec := int(server_peer.get_statistic(
		ENetPacketPeer.PEER_ROUND_TRIP_TIME
	))

	print(
		"REAL_MOVEMENT_RESULT samples=%d sent=%d ack=%d hard=%d soft=%d correction_back_m=%.3f backwards_frames=%d backwards_motion_m=%.3f max_rule_error_m=%.3f max_visual_gap_m=%.3f travelled_m=%.3f throttle=%d/%d loss=%.4f rtt_ms=%d"
		% [
			authoritative_samples,
			network._input_sequence,
			latest_ack_sequence,
			player.get_network_hard_correction_count(),
			player.get_network_soft_correction_count(),
			player.get_network_backward_correction_distance(),
			backwards_frames,
			backwards_distance,
			player.get_network_max_horizontal_error(),
			max_visual_authority_gap,
			distance_travelled,
			packet_throttle,
			packet_throttle_limit,
			packet_loss,
			round_trip_msec,
		]
	)
	_require(authoritative_samples >= 60, "too few real authoritative snapshots")
	_require(
		player.get_network_hard_correction_count() == 0,
		"normal sustained movement triggered a hard reconciliation"
	)
	_require(
		player.get_network_backward_correction_distance() < 0.01,
		"authoritative reconciliation pulled the active player backwards"
	)
	_require(
		player.get_network_max_horizontal_error() < 4.25,
		"client and server movement diverged beyond the latency budget"
	)
	_require(
		packet_throttle >= 24 and packet_throttle_limit == 32,
		"ENet throttled the compact input stream"
	)
	network.disconnect_session()
	if failed:
		quit(1)
		return
	quit(0)


func _require(condition: bool, message: String) -> void:
	if condition:
		return
	failed = true
	push_error("REAL_MOVEMENT_FAIL: " + message)
