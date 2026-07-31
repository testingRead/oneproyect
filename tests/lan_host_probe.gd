extends SceneTree

const LAN_SCRIPT := preload("res://scripts/network/lan_session.gd")

var _lan
var _got_client_state := false
var _got_start := false
var _got_impulse := false


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_lan = LAN_SCRIPT.new()
	_lan.name = "LanSession"
	root.add_child(_lan)
	_lan.player_state_received.connect(func(peer_id: int, _position: Vector3, _velocity: Vector3, _yaw: float, _health: int) -> void:
		if peer_id != 1:
			_got_client_state = true
	)
	_lan.game_started.connect(func(_path: String, _seed: int) -> void: _got_start = true)
	_lan.object_impulse_received.connect(func(name: String, impulse: Vector3) -> void:
		_got_impulse = name == "Ball" and impulse.length() > 1.0
	)
	if _lan.host_room("HostProbe", "res://data/characters/base_character.tres") != OK:
		push_error("LAN_HOST_FAIL: cannot host")
		quit(1)
		return
	_lan.set_minigame("res://data/minigames/tornado_supervivencia.tres")
	_lan.set_ready(true)
	for frame in 600:
		if _lan.players.size() >= 2 and _lan.can_start():
			_lan.start_game()
			break
		await process_frame
	for frame in 240:
		_lan.send_physics_state(PackedStringArray(["Ball"]), PackedVector3Array([Vector3(1.0, 0.5, -20.0)]), PackedVector3Array([Vector3.ZERO]), PackedVector3Array([Vector3(2.0, 0.0, 0.0)]))
		if _got_client_state and _got_start and _got_impulse:
			for settle_frame in 90:
				await process_frame
			print("LAN_HOST_OK players=%d start=%s state=%s impulse=%s" % [_lan.players.size(), _got_start, _got_client_state, _got_impulse])
			_lan.leave_room()
			quit(0)
			return
		await process_frame
	push_error("LAN_HOST_FAIL: players=%d start=%s state=%s impulse=%s" % [_lan.players.size(), _got_start, _got_client_state, _got_impulse])
	_lan.leave_room()
	quit(1)
