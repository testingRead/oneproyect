extends SceneTree

const LAN_SCRIPT := preload("res://scripts/network/lan_session.gd")

var _lan
var _registered := false
var _started := false
var _got_physics := false


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_lan = LAN_SCRIPT.new()
	_lan.name = "LanSession"
	root.add_child(_lan)
	_lan.lobby_changed.connect(_on_lobby)
	_lan.game_started.connect(func(path: String, seed: int) -> void:
		_started = not path.is_empty() and seed != 0
	)
	_lan.physics_state_received.connect(func(names: PackedStringArray, _positions: PackedVector3Array, _rotations: PackedVector3Array, _velocities: PackedVector3Array) -> void:
		_got_physics = names.size() == 1 and names[0] == "Ball"
	)
	if _lan.join_room("127.0.0.1", "ClientProbe", "res://data/characters/base_character.tres") != OK:
		push_error("LAN_CLIENT_FAIL: cannot connect")
		quit(1)
		return
	for frame in 600:
		if _registered:
			_lan.send_player_state(Vector3(2.0, 0.02, -12.0), Vector3(1.0, 0.0, 0.0), 0.4, 88)
			_lan.request_object_impulse("Ball", Vector3(4.0, 1.0, 0.0))
		if _started and _got_physics:
			print("LAN_CLIENT_OK peer=%d players=%d" % [_lan.get_local_peer_id(), _lan.players.size()])
			_lan.leave_room()
			quit(0)
			return
		await process_frame
	push_error("LAN_CLIENT_FAIL: registered=%s started=%s players=%d" % [_registered, _started, _lan.players.size()])
	_lan.leave_room()
	quit(1)


func _on_lobby() -> void:
	if not _lan.is_active():
		return
	var local_id: int = _lan.get_local_peer_id()
	if _lan.players.has(local_id) and not _registered:
		_registered = true
		_lan.set_ready(true)
