class_name NetCodec
extends RefCounted

const NET := preload("res://shared/net_constants.gd")

const STATE_VERSION := 0
const STATE_HEALTH := 1
const STATE_SEQUENCE := 2
const STATE_POSITION_X := 6
const STATE_POSITION_Y := 8
const STATE_POSITION_Z := 10
const STATE_VELOCITY_X := 12
const STATE_VELOCITY_Y := 14
const STATE_VELOCITY_Z := 16
const STATE_YAW := 18
const STATE_BODY_MASK := 20

const SNAPSHOT_VERSION := 0
const SNAPSHOT_PHASE := 1
const SNAPSHOT_PLAYER_COUNT := 2
const SNAPSHOT_MODE := 3
const SNAPSHOT_SERVER_TICK := 4
const SNAPSHOT_ROUND := 8
const SNAPSHOT_SEED := 10
const SNAPSHOT_PHASE_END_TICK := 14
const SNAPSHOT_ROOM_ID := 18

const PLAYER_ID := 0
const PLAYER_FLAGS := 2
const PLAYER_HEALTH := 3
const PLAYER_STATE_SEQUENCE := 4
const PLAYER_POSITION_X := 8
const PLAYER_POSITION_Y := 10
const PLAYER_POSITION_Z := 12
const PLAYER_VELOCITY_X := 14
const PLAYER_VELOCITY_Y := 16
const PLAYER_VELOCITY_Z := 18
const PLAYER_YAW := 20
const PLAYER_BODY_MASK := 22

const NORMALIZED_SCALE := 32767.0
const WORLD_SCALE := 100.0


static func create_owned_state_buffer() -> PackedByteArray:
	var packet := PackedByteArray()
	packet.resize(NET.OWNED_STATE_PACKET_SIZE)
	packet[STATE_VERSION] = NET.PROTOCOL_VERSION
	return packet


static func write_owned_state(
	packet: PackedByteArray,
	sequence: int,
	position: Vector3,
	velocity: Vector3,
	yaw: float,
	health: int,
	body_mask: int
) -> void:
	if packet.size() != NET.OWNED_STATE_PACKET_SIZE:
		packet.resize(NET.OWNED_STATE_PACKET_SIZE)
	packet[STATE_VERSION] = NET.PROTOCOL_VERSION
	packet[STATE_HEALTH] = clampi(health, 0, 100)
	packet.encode_u32(STATE_SEQUENCE, sequence)
	packet.encode_s16(STATE_POSITION_X, _encode_world(position.x))
	packet.encode_s16(STATE_POSITION_Y, _encode_world(position.y))
	packet.encode_s16(STATE_POSITION_Z, _encode_world(position.z))
	packet.encode_s16(STATE_VELOCITY_X, _encode_world(velocity.x))
	packet.encode_s16(STATE_VELOCITY_Y, _encode_world(velocity.y))
	packet.encode_s16(STATE_VELOCITY_Z, _encode_world(velocity.z))
	packet.encode_s16(STATE_YAW, _encode_angle(yaw))
	packet.encode_u16(STATE_BODY_MASK, body_mask)


static func is_valid_owned_state(packet: PackedByteArray) -> bool:
	return (
		packet.size() == NET.OWNED_STATE_PACKET_SIZE
		and packet[STATE_VERSION] == NET.PROTOCOL_VERSION
	)


static func owned_state_sequence(packet: PackedByteArray) -> int:
	return packet.decode_u32(STATE_SEQUENCE)


static func owned_state_position(packet: PackedByteArray) -> Vector3:
	return Vector3(
		float(packet.decode_s16(STATE_POSITION_X)) / WORLD_SCALE,
		float(packet.decode_s16(STATE_POSITION_Y)) / WORLD_SCALE,
		float(packet.decode_s16(STATE_POSITION_Z)) / WORLD_SCALE
	)


static func owned_state_velocity(packet: PackedByteArray) -> Vector3:
	return Vector3(
		float(packet.decode_s16(STATE_VELOCITY_X)) / WORLD_SCALE,
		float(packet.decode_s16(STATE_VELOCITY_Y)) / WORLD_SCALE,
		float(packet.decode_s16(STATE_VELOCITY_Z)) / WORLD_SCALE
	)


static func owned_state_yaw(packet: PackedByteArray) -> float:
	return float(packet.decode_s16(STATE_YAW)) / NORMALIZED_SCALE * PI


static func owned_state_health(packet: PackedByteArray) -> int:
	return packet[STATE_HEALTH]


static func owned_state_body_mask(packet: PackedByteArray) -> int:
	return packet.decode_u16(STATE_BODY_MASK)


static func create_snapshot_buffer() -> PackedByteArray:
	var packet := PackedByteArray()
	packet.resize(NET.SNAPSHOT_PACKET_SIZE)
	packet[SNAPSHOT_VERSION] = NET.PROTOCOL_VERSION
	return packet


static func snapshot_size(player_count: int) -> int:
	return (
		NET.SNAPSHOT_HEADER_SIZE
		+ clampi(player_count, 0, NET.MAX_PLAYERS_PER_ROOM) * NET.SNAPSHOT_PLAYER_SIZE
	)


static func write_snapshot_header(
	packet: PackedByteArray,
	phase: int,
	player_count: int,
	mode_id: int,
	server_tick: int,
	round_number: int,
	round_seed: int,
	phase_end_tick: int,
	room_id: int
) -> void:
	packet[SNAPSHOT_VERSION] = NET.PROTOCOL_VERSION
	packet[SNAPSHOT_PHASE] = phase & 0xff
	packet[SNAPSHOT_PLAYER_COUNT] = clampi(player_count, 0, NET.MAX_PLAYERS_PER_ROOM)
	packet[SNAPSHOT_MODE] = mode_id & 0xff
	packet.encode_u32(SNAPSHOT_SERVER_TICK, server_tick)
	packet.encode_u16(SNAPSHOT_ROUND, round_number)
	packet.encode_u32(SNAPSHOT_SEED, round_seed)
	packet.encode_u32(SNAPSHOT_PHASE_END_TICK, phase_end_tick)
	packet.encode_u16(SNAPSHOT_ROOM_ID, room_id)


static func write_snapshot_player(
	packet: PackedByteArray,
	slot: int,
	player_id: int,
	flags: int,
	health: int,
	state_sequence: int,
	position: Vector3,
	velocity: Vector3,
	yaw: float,
	body_mask: int
) -> void:
	var offset := player_offset(slot)
	packet.encode_u16(offset + PLAYER_ID, player_id)
	packet[offset + PLAYER_FLAGS] = flags & 0xff
	packet[offset + PLAYER_HEALTH] = clampi(health, 0, 255)
	packet.encode_u32(offset + PLAYER_STATE_SEQUENCE, state_sequence)
	packet.encode_s16(offset + PLAYER_POSITION_X, _encode_world(position.x))
	packet.encode_s16(offset + PLAYER_POSITION_Y, _encode_world(position.y))
	packet.encode_s16(offset + PLAYER_POSITION_Z, _encode_world(position.z))
	packet.encode_s16(offset + PLAYER_VELOCITY_X, _encode_world(velocity.x))
	packet.encode_s16(offset + PLAYER_VELOCITY_Y, _encode_world(velocity.y))
	packet.encode_s16(offset + PLAYER_VELOCITY_Z, _encode_world(velocity.z))
	packet.encode_s16(offset + PLAYER_YAW, _encode_angle(yaw))
	packet.encode_u16(offset + PLAYER_BODY_MASK, body_mask)


static func is_valid_snapshot(packet: PackedByteArray) -> bool:
	if packet.size() < NET.SNAPSHOT_HEADER_SIZE:
		return false
	var player_count := snapshot_player_count(packet)
	return (
		packet[SNAPSHOT_VERSION] == NET.PROTOCOL_VERSION
		and player_count <= NET.MAX_PLAYERS_PER_ROOM
		and packet.size() == snapshot_size(player_count)
	)


static func snapshot_player_count(packet: PackedByteArray) -> int:
	return packet[SNAPSHOT_PLAYER_COUNT]


static func snapshot_server_tick(packet: PackedByteArray) -> int:
	return packet.decode_u32(SNAPSHOT_SERVER_TICK)


static func snapshot_phase(packet: PackedByteArray) -> int:
	return packet[SNAPSHOT_PHASE]


static func snapshot_mode(packet: PackedByteArray) -> int:
	return packet[SNAPSHOT_MODE]


static func snapshot_round(packet: PackedByteArray) -> int:
	return packet.decode_u16(SNAPSHOT_ROUND)


static func snapshot_seed(packet: PackedByteArray) -> int:
	return packet.decode_u32(SNAPSHOT_SEED)


static func snapshot_phase_end_tick(packet: PackedByteArray) -> int:
	return packet.decode_u32(SNAPSHOT_PHASE_END_TICK)


static func snapshot_room_id(packet: PackedByteArray) -> int:
	return packet.decode_u16(SNAPSHOT_ROOM_ID)


static func player_offset(slot: int) -> int:
	return NET.SNAPSHOT_HEADER_SIZE + slot * NET.SNAPSHOT_PLAYER_SIZE


static func snapshot_player_id(packet: PackedByteArray, slot: int) -> int:
	return packet.decode_u16(player_offset(slot) + PLAYER_ID)


static func snapshot_player_flags(packet: PackedByteArray, slot: int) -> int:
	return packet[player_offset(slot) + PLAYER_FLAGS]


static func snapshot_player_health(packet: PackedByteArray, slot: int) -> int:
	return packet[player_offset(slot) + PLAYER_HEALTH]


static func snapshot_player_state_sequence(packet: PackedByteArray, slot: int) -> int:
	return packet.decode_u32(player_offset(slot) + PLAYER_STATE_SEQUENCE)


static func snapshot_player_position(packet: PackedByteArray, slot: int) -> Vector3:
	var offset := player_offset(slot)
	return Vector3(
		float(packet.decode_s16(offset + PLAYER_POSITION_X)) / WORLD_SCALE,
		float(packet.decode_s16(offset + PLAYER_POSITION_Y)) / WORLD_SCALE,
		float(packet.decode_s16(offset + PLAYER_POSITION_Z)) / WORLD_SCALE
	)


static func snapshot_player_velocity(packet: PackedByteArray, slot: int) -> Vector3:
	var offset := player_offset(slot)
	return Vector3(
		float(packet.decode_s16(offset + PLAYER_VELOCITY_X)) / WORLD_SCALE,
		float(packet.decode_s16(offset + PLAYER_VELOCITY_Y)) / WORLD_SCALE,
		float(packet.decode_s16(offset + PLAYER_VELOCITY_Z)) / WORLD_SCALE
	)


static func snapshot_player_yaw(packet: PackedByteArray, slot: int) -> float:
	return (
		float(packet.decode_s16(player_offset(slot) + PLAYER_YAW))
		/ NORMALIZED_SCALE
		* PI
	)


static func snapshot_player_body_mask(packet: PackedByteArray, slot: int) -> int:
	return packet.decode_u16(player_offset(slot) + PLAYER_BODY_MASK)


static func _encode_normalized(value: float) -> int:
	return clampi(roundi(clampf(value, -1.0, 1.0) * NORMALIZED_SCALE), -32767, 32767)


static func _encode_angle(value: float) -> int:
	return _encode_normalized(wrapf(value, -PI, PI) / PI)


static func _encode_world(value: float) -> int:
	return clampi(roundi(value * WORLD_SCALE), -32768, 32767)
