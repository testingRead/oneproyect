extends SceneTree

const NET := preload("res://shared/net_constants.gd")
const CODEC := preload("res://shared/net_codec.gd")
const MOVEMENT := preload("res://shared/movement_rules.gd")


func _init() -> void:
	var input := CODEC.create_input_buffer()
	CODEC.write_input(
		input,
		42,
		Vector2(0.5, -0.75),
		1.25,
		NET.InputFlags.JUMP
	)
	_require(CODEC.is_valid_input(input), "Input packet must validate")
	_require(input.size() == NET.INPUT_PACKET_SIZE, "Input packet size must stay fixed")
	_require(CODEC.input_sequence(input) == 42, "Input sequence must round-trip")
	_require(
		CODEC.input_move(input).distance_to(Vector2(0.5, -0.75)) < 0.0001,
		"Move must round-trip"
	)
	_require(absf(CODEC.input_yaw(input) - 1.25) < 0.0001, "Yaw must round-trip")
	_require(CODEC.input_flags(input) == NET.InputFlags.JUMP, "Flags must round-trip")

	var snapshot := CODEC.create_snapshot_buffer()
	CODEC.write_snapshot_header(snapshot, 1, 5, 2, 100, 7, 9876, 240, 1)
	CODEC.write_snapshot_player(
		snapshot,
		0,
		9,
		NET.PlayerFlags.CONNECTED | NET.PlayerFlags.ACTIVE,
		84,
		42,
		Vector3(2.0, 1.2, -3.0),
		Vector3(1.0, 0.0, -2.0),
		0.75,
		NET.ALL_BODY_PARTS_MASK
	)
	_require(CODEC.is_valid_snapshot(snapshot), "Snapshot packet must validate")
	_require(snapshot.size() == 140, "Five-player snapshot must remain 140 bytes")
	_require(CODEC.snapshot_server_tick(snapshot) == 100, "Server tick must round-trip")
	_require(CODEC.snapshot_player_id(snapshot, 0) == 9, "Player ID must round-trip")
	_require(CODEC.snapshot_player_ack(snapshot, 0) == 42, "Input ACK must round-trip")
	_require(
		CODEC.snapshot_player_position(snapshot, 0).distance_to(Vector3(2.0, 1.2, -3.0)) < 0.001,
		"Position must round-trip"
	)
	_require(
		CODEC.snapshot_player_body_mask(snapshot, 0) == NET.ALL_BODY_PARTS_MASK,
		"Compact body mask must round-trip"
	)

	var velocity := MOVEMENT.step_velocity(
		Vector3.ZERO,
		Vector2(1.0, 0.0),
		true,
		true,
		NET.SERVER_TICK_DELTA
	)
	var position := MOVEMENT.step_position(
		Vector3(0.0, NET.FLOOR_HEIGHT, 0.0),
		velocity,
		NET.SERVER_TICK_DELTA
	)
	_require(velocity.x > 0.0 and velocity.y > 0.0, "Shared rules must move and jump")
	_require(position.x > 0.0 and position.y > NET.FLOOR_HEIGHT, "Movement must integrate")

	input.resize(4)
	_require(not CODEC.is_valid_input(input), "Malformed input must be rejected")
	print(
		"NETWORK_CODEC_OK input_bytes=%d snapshot_bytes=%d players=%d"
		% [NET.INPUT_PACKET_SIZE, NET.SNAPSHOT_PACKET_SIZE, NET.MAX_PLAYERS_PER_ROOM]
	)
	quit(0)


func _require(condition: bool, message: String) -> void:
	if condition:
		return
	push_error("NETWORK_CODEC_FAIL: " + message)
	quit(1)
