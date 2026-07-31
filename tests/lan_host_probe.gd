extends SceneTree

const LAN_SCRIPT := preload("res://scripts/network/lan_session.gd")
const LAN_EVENT := preload("res://shared/lan_round_event.gd")

var _lan
var _got_client_state := false
var _got_start := false
var _got_impulse := false
var _got_bateball_shot := false
var _sent_round_contract := false
var _got_pitch := false
var _got_push_request := false


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_lan = LAN_SCRIPT.new()
	_lan.name = "LanSession"
	root.add_child(_lan)
	_lan.player_state_received.connect(func(peer_id: int, _position: Vector3, _velocity: Vector3, _yaw: float, _pitch: float, _health: int) -> void:
		if peer_id != 1:
			_got_client_state = true
			_got_pitch = is_equal_approx(_pitch, -0.25)
	)
	_lan.action_request_received.connect(func(peer_id: int, action: int, target_peer_id: int, direction: Vector3, _flag: bool) -> void:
		_got_push_request = peer_id != 1 and action == LAN_EVENT.Action.CHARACTER_PUSH and target_peer_id == 1 and direction.dot(Vector3.RIGHT) > 0.9
	)
	_lan.game_started.connect(func(_path: String, _seed: int) -> void: _got_start = true)
	_lan.object_impulse_received.connect(func(name: String, impulse: Vector3) -> void:
		_got_impulse = name == "Ball" and impulse.length() > 1.0
	)
	_lan.bateball_shot_received.connect(func(peer_id: int, direction: Vector3) -> void:
		_got_bateball_shot = peer_id != 1 and direction.dot(Vector3.RIGHT) > 0.9
	)
	if _lan.host_room("HostProbe", "res://data/characters/base_character.tres") != OK:
		push_error("LAN_HOST_FAIL: cannot host")
		quit(1)
		return
	_lan.set_round_context(7701)
	_lan.set_minigame("res://data/minigames/tornado_supervivencia.tres")
	_lan.set_ready(true)
	for frame in 600:
		if _lan.players.size() >= 2 and _lan.can_start():
			_lan.start_game()
			break
		await process_frame
	for frame in 240:
		_lan.send_physics_state(PackedStringArray(["Ball"]), PackedVector3Array([Vector3(1.0, 0.5, -20.0)]), PackedVector3Array([Vector3.ZERO]), PackedVector3Array([Vector3(2.0, 0.0, 0.0)]))
		_lan.send_hazard_state(LAN_EVENT.Subject.TORNADO, Vector3(3.0, 0.0, -20.0), 31.0)
		_lan.broadcast_bateball_holder(1)
		_lan.broadcast_bateball_score(1, 0, false)
		if not _sent_round_contract:
			_sent_round_contract = true
			_lan.broadcast_action(
				1, LAN_EVENT.Action.FOOTBALL_KICK, Vector3.FORWARD
			)
			_lan.broadcast_round_event(
				LAN_EVENT.Kind.HOLDER_CHANGED,
				LAN_EVENT.Subject.CROWN,
				1
			)
			_lan.broadcast_round_event(
				LAN_EVENT.Kind.HOLDER_CHANGED,
				LAN_EVENT.Subject.BOMB,
				1,
				PackedInt32Array([19000])
			)
			_lan.broadcast_round_event(
				LAN_EVENT.Kind.SCORE_CHANGED,
				LAN_EVENT.Subject.FOOTBALL,
				0,
				PackedInt32Array([2, 1, 0, 0, 0])
			)
			_lan.broadcast_round_event(
				LAN_EVENT.Kind.DAMAGE_CONFIRMED,
				LAN_EVENT.Subject.TORNADO,
				1,
				PackedInt32Array([76, 1]),
				PackedVector3Array([Vector3(4.0, 1.0, 0.0)])
			)
		if _got_client_state and _got_pitch and _got_push_request and _got_start and _got_impulse and _got_bateball_shot:
			for settle_frame in 90:
				await process_frame
			print("LAN_HOST_OK players=%d start=%s state=%s impulse=%s bateball=%s" % [_lan.players.size(), _got_start, _got_client_state, _got_impulse, _got_bateball_shot])
			_lan.leave_room()
			quit(0)
			return
		await process_frame
	push_error("LAN_HOST_FAIL: players=%d start=%s state=%s impulse=%s" % [_lan.players.size(), _got_start, _got_client_state, _got_impulse])
	_lan.leave_room()
	quit(1)
