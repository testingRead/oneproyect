extends SceneTree

const LAN_SCRIPT := preload("res://scripts/network/lan_session.gd")

var _failed := false


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var session = LAN_SCRIPT.new()
	root.add_child(session)
	session.reset_local_session_points()
	session.award_local_session_points(3)
	session.award_local_session_points(1)
	_require(session.local_session_points == 4, "Local room score must accumulate during the room lifetime")
	session._rpc_lobby_state(
		PackedInt32Array([1, 9]),
		PackedStringArray(["Ana", "Luis"]),
		PackedByteArray([1, 0]),
		PackedStringArray(["base", "base"]),
		PackedInt32Array([6, 3]),
		"res://data/minigames/balon_eliminacion.tres"
	)
	_require(int(session.players[1].points) == 6, "Host score must replicate in lobby profile")
	_require(int(session.players[9].points) == 3, "Guest score must replicate in lobby profile")
	_require(not session.players[9].ready, "Score replication must preserve ready state")
	print("SESSION_SCORE_OK local=4 host=6 guest=3")
	quit(1 if _failed else 0)


func _require(condition: bool, message: String) -> void:
	if not condition:
		_failed = true
		push_error("SESSION_SCORE_FAIL: %s" % message)
