extends SceneTree

const NETWORK_SCRIPT := preload("res://scripts/network/network_manager.gd")
const TIMEOUT_SECONDS := 10.0

var network: OneProjectNetwork
var role := "observer"
var address := "127.0.0.1"
var online := false
var saw_remote := false
var saw_snapshot := false
var saw_meteor := false
var saw_shockwave := false
var saw_round_state := false
var saw_push := false
var remote_peer_id := 0


func _init() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--role="):
			role = argument.trim_prefix("--role=")
		elif argument.begins_with("--address="):
			address = argument.trim_prefix("--address=")
	call_deferred("_setup")


func _setup() -> void:
	if root.has_node("Network"):
		network = root.get_node("Network")
	else:
		network = NETWORK_SCRIPT.new()
		network.name = "Network"
		root.add_child(network)
	print("NETWORK_PROBE_NODE role=%s path=%s" % [role, network.get_path()])
	network.host_score = 16 if role == "host" else 1
	network.status_changed.connect(_on_status)
	network.remote_player_joined.connect(func(peer_id: int, _name: String, _color: int) -> void:
		saw_remote = true
		remote_peer_id = peer_id
	)
	network.remote_snapshot.connect(func(_id: int, _position: Vector3, _yaw: float) -> void:
		saw_snapshot = true
	)
	network.meteor_received.connect(func(_target: Vector3, _drift: Vector2, _damage: int, _force: float) -> void:
		saw_meteor = true
	)
	network.shockwave_received.connect(func() -> void:
		saw_shockwave = true
	)
	network.round_state_received.connect(func(_state: int, _round: int, _time: float) -> void:
		saw_round_state = true
	)
	network.push_received.connect(func(_sender: int, _direction: Vector3, _force: float) -> void:
		saw_push = true
	)
	_run()


func _run() -> void:
	network.display_name = role.capitalize()
	var error := network.connect_to_server(address)
	_require(error == OK, "client creation failed")
	var elapsed := 0.0
	var sent_events := false
	var events_sent_at := 0.0
	while elapsed < TIMEOUT_SECONDS:
		await process_frame
		elapsed += 1.0 / 60.0
		if online and network.get_player_count() >= 2:
			if role == "host":
				network.send_snapshot(Vector3(2.0, 1.2, -3.0), 0.75)
				if network.is_simulation_host() and not sent_events and elapsed > 1.0:
					network.broadcast_meteor(Vector3(1.0, 0.06, 1.0), Vector2.ZERO, 22, 10.5)
					network.broadcast_shockwave()
					network.broadcast_round_state(1, 3, 20.0)
					network.send_push(remote_peer_id, Vector3.FORWARD, 5.2)
					sent_events = true
					events_sent_at = elapsed
					saw_meteor = true
					saw_shockwave = true
					saw_round_state = true
					saw_push = true
			else:
				network.send_snapshot(Vector3(-2.0, 1.2, 3.0), -0.75)
		if _is_complete(sent_events, elapsed - events_sent_at):
			print(
				"NETWORK_PROBE_OK role=%s players=%d host=%s remote=%s snapshot=%s meteor=%s shockwave=%s round=%s push=%s"
				% [
					role,
					network.get_player_count(),
					network.is_simulation_host(),
					saw_remote,
					saw_snapshot,
					saw_meteor,
					saw_shockwave,
					saw_round_state,
					saw_push,
				]
			)
			network.disconnect_session()
			quit(0)
			return
	_require(false, "timed out waiting for synchronized events")


func _is_complete(sent_events: bool, event_age: float) -> bool:
	if role == "host":
		return online and saw_remote and saw_snapshot and sent_events and event_age >= 1.0
	return (
		online
		and saw_remote
		and saw_snapshot
		and saw_meteor
		and saw_shockwave
		and saw_round_state
		and saw_push
	)


func _on_status(_text: String, is_online: bool) -> void:
	online = is_online


func _require(condition: bool, message: String) -> void:
	if condition:
		return
	push_error("NETWORK_PROBE_FAIL role=%s: %s" % [role, message])
	quit(1)
