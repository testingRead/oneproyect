extends SceneTree

const LAN_SCRIPT := preload("res://scripts/network/lan_session.gd")
const LAN_EVENT := preload("res://shared/lan_round_event.gd")

var _lan
var _registered := false
var _started := false
var _got_physics := false
var _got_holder := false
var _got_score := false
var _got_round_event := false
var _got_bomb_event := false
var _got_football_event := false
var _got_damage_event := false
var _got_hazard_state := false
var _got_action := false
var _got_bateball_impact := false
var _got_shooter_shot := false
var _got_shooter_weapon_state := false
var _got_shooter_hit := false
var _sent_push_request := false


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
	_lan.hazard_state_received.connect(func(subject: int, position: Vector3, remaining: float) -> void:
		_got_hazard_state = subject == LAN_EVENT.Subject.TORNADO and position.x == 3.0 and remaining > 0.0
	)
	_lan.action_received.connect(func(peer_id: int, action: int, target_peer_id: int, direction: Vector3, flag: bool) -> void:
		if peer_id == 1 and action == LAN_EVENT.Action.FOOTBALL_KICK and direction.dot(Vector3.FORWARD) > 0.9:
			_got_action = true
		elif peer_id == 1 and action == LAN_EVENT.Action.BATEBALL_IMPACT:
			_got_bateball_impact = target_peer_id == _lan.get_local_peer_id() and direction.dot(Vector3.RIGHT) > 0.9 and flag
		elif peer_id == 1 and action == LAN_EVENT.Action.SHOOTER_SHOT:
			_got_shooter_shot = direction.dot(Vector3.FORWARD) > 0.9
	)
	_lan.bateball_holder_received.connect(func(peer_id: int) -> void: _got_holder = peer_id == 1)
	_lan.bateball_score_received.connect(func(home: int, away: int, complete: bool) -> void:
		_got_score = home == 1 and away == 0 and not complete
	)
	_lan.round_event_received.connect(func(round_id: int, revision: int, kind: int, subject: int, actor: int, ints: PackedInt32Array, vectors: PackedVector3Array) -> void:
		if round_id != 7701 or revision <= 0:
			return
		if kind == LAN_EVENT.Kind.HOLDER_CHANGED and subject == LAN_EVENT.Subject.CROWN and actor == 1:
			_got_round_event = true
		elif kind == LAN_EVENT.Kind.HOLDER_CHANGED and subject == LAN_EVENT.Subject.BOMB and ints.size() == 1:
			_got_bomb_event = ints[0] == 19000
		elif kind == LAN_EVENT.Kind.SCORE_CHANGED and subject == LAN_EVENT.Subject.FOOTBALL and ints.size() >= 4:
			_got_football_event = ints[0] == 2 and ints[1] == 1
		elif kind == LAN_EVENT.Kind.DAMAGE_CONFIRMED and subject == LAN_EVENT.Subject.TORNADO and not vectors.is_empty():
			_got_damage_event = ints[0] == 76 and vectors[0].length() > 1.0
		elif kind == LAN_EVENT.Kind.WEAPON_STATE and subject == LAN_EVENT.Subject.SHOOTER:
			_got_shooter_weapon_state = actor == _lan.get_local_peer_id() and ints == PackedInt32Array([3, 1, 900])
		elif kind == LAN_EVENT.Kind.HIT_CONFIRMED and subject == LAN_EVENT.Subject.SHOOTER:
			_got_shooter_hit = actor == _lan.get_local_peer_id() and ints == PackedInt32Array([66])
	)
	if _lan.join_room("127.0.0.1", "ClientProbe", "res://data/characters/base_character.tres") != OK:
		push_error("LAN_CLIENT_FAIL: cannot connect")
		quit(1)
		return
	_lan.set_round_context(7701)
	for frame in 600:
		if _registered:
			_lan.send_player_state(Vector3(2.0, 0.02, -12.0), Vector3(1.0, 0.0, 0.0), 0.4, -0.25, 88)
			_lan.request_object_impulse("Ball", Vector3(4.0, 1.0, 0.0))
			_lan.request_bateball_shot(Vector3.RIGHT)
			if not _sent_push_request:
				_sent_push_request = true
				_lan.request_action(
					LAN_EVENT.Action.CHARACTER_PUSH, 1, Vector3.RIGHT
				)
				_lan.request_action(
					LAN_EVENT.Action.SHOOTER_SHOT, 0, Vector3.FORWARD
				)
				_lan.request_action(
					LAN_EVENT.Action.SHOOTER_RELOAD, 0, Vector3.ZERO
				)
		if (
			_started
			and _got_physics
			and _got_holder
			and _got_score
			and _got_round_event
			and _got_bomb_event
			and _got_football_event
			and _got_damage_event
			and _got_hazard_state
			and _got_action
			and _got_bateball_impact
			and _got_shooter_shot
			and _got_shooter_weapon_state
			and _got_shooter_hit
		):
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
