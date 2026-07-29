extends SceneTree

const NET := preload("res://shared/net_constants.gd")
const CODEC := preload("res://shared/net_codec.gd")


func _init() -> void:
	var owned_state := CODEC.create_owned_state_buffer()
	CODEC.write_owned_state(
		owned_state,
		42,
		Vector3(2.0, 1.2, -3.0),
		Vector3(1.0, 4.5, -2.0),
		1.25,
		78,
		NET.ALL_BODY_PARTS_MASK
	)
	_require(CODEC.is_valid_owned_state(owned_state), "Owned state packet must validate")
	_require(
		owned_state.size() == NET.OWNED_STATE_PACKET_SIZE,
		"Owned state packet size must stay fixed"
	)
	_require(CODEC.owned_state_sequence(owned_state) == 42, "State sequence must round-trip")
	_require(
		CODEC.owned_state_position(owned_state).distance_to(Vector3(2.0, 1.2, -3.0)) < 0.001,
		"Owned position must round-trip"
	)
	_require(
		CODEC.owned_state_velocity(owned_state).distance_to(Vector3(1.0, 4.5, -2.0)) < 0.001,
		"Owned velocity must round-trip"
	)
	_require(absf(CODEC.owned_state_yaw(owned_state) - 1.25) < 0.0001, "Yaw must round-trip")
	_require(CODEC.owned_state_health(owned_state) == 78, "Health must round-trip")
	_require(
		CODEC.owned_state_body_mask(owned_state) == NET.ALL_BODY_PARTS_MASK,
		"Body mask must round-trip"
	)

	var snapshot := CODEC.create_snapshot_buffer()
	CODEC.write_snapshot_header(snapshot, 1, 5, 2, 100, 7, 9876, 240, 1, 42)
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
	_require(snapshot.size() == 144, "Five-player snapshot must remain compact")
	_require(CODEC.snapshot_server_tick(snapshot) == 100, "Server tick must round-trip")
	_require(CODEC.snapshot_ack_sequence(snapshot) == 42, "Owner ACK must round-trip")
	_require(CODEC.snapshot_player_id(snapshot, 0) == 9, "Player ID must round-trip")
	_require(
		CODEC.snapshot_player_state_sequence(snapshot, 0) == 42,
		"Relayed state sequence must round-trip"
	)
	_require(
		CODEC.snapshot_player_position(snapshot, 0).distance_to(Vector3(2.0, 1.2, -3.0)) < 0.001,
		"Position must round-trip"
	)
	_require(
		CODEC.snapshot_player_body_mask(snapshot, 0) == NET.ALL_BODY_PARTS_MASK,
		"Compact body mask must round-trip"
	)

	owned_state.resize(4)
	_require(
		not CODEC.is_valid_owned_state(owned_state),
		"Malformed owned state must be rejected"
	)
	print(
		"NETWORK_CODEC_OK state_bytes=%d snapshot_bytes=%d players=%d"
		% [NET.OWNED_STATE_PACKET_SIZE, NET.SNAPSHOT_PACKET_SIZE, NET.MAX_PLAYERS_PER_ROOM]
	)
	quit(0)


func _require(condition: bool, message: String) -> void:
	if condition:
		return
	push_error("NETWORK_CODEC_FAIL: " + message)
	quit(1)
