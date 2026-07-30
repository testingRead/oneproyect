class_name NetConstants
extends RefCounted

const PROTOCOL_VERSION := 9
const DEFAULT_PORT := 9999
const MAX_ROOMS := 5
const MAX_PLAYERS_PER_ROOM := 5
const CHARACTER_VARIANT_COUNT := 6
const MAX_SERVER_CONNECTIONS := MAX_ROOMS * MAX_PLAYERS_PER_ROOM
const MIN_PLAYERS_TO_START := 2
const SERVER_TICK_RATE := 20
const SERVER_TICK_DELTA := 1.0 / SERVER_TICK_RATE
const STATE_SEND_RATE := 20
const IDLE_STATE_SEND_RATE := 5
const SNAPSHOT_RATE := 10
const SNAPSHOT_INTERVAL_TICKS := SERVER_TICK_RATE / SNAPSHOT_RATE
const RECONNECT_SECONDS := 60
const RECONNECT_TICKS := RECONNECT_SECONDS * SERVER_TICK_RATE

const CHANNEL_SESSION := 0
const CHANNEL_STATE := 1
const CHANNEL_EVENTS := 2
const ENET_CHANNEL_COUNT := 3

const OWNED_STATE_PACKET_SIZE := 22
const SNAPSHOT_HEADER_SIZE := 24
const SNAPSHOT_PLAYER_SIZE := 24
const SNAPSHOT_PACKET_SIZE := (
	SNAPSHOT_HEADER_SIZE + MAX_PLAYERS_PER_ROOM * SNAPSHOT_PLAYER_SIZE
)

const ARENA_HALF_EXTENT := 25.2
const FLOOR_HEIGHT := 1.2
const ALL_BODY_PARTS_MASK := 0b111111111111
const DEFAULT_MATCH_ROUNDS := 5
const MATCH_ROUND_OPTIONS := [3, 5, 7]
const ROUND_PLACE_POINTS := [5, 4, 3, 2, 1]

enum RoomPhase {
	WAITING,
	COUNTDOWN,
	ACTIVE,
	RESULT,
}

enum ModeId {
	METEORS,
	SHOCKWAVE,
	FLOOD,
	SHOOTER,
	DOMAIN,
}

enum PlayerFlags {
	CONNECTED = 1,
	ACTIVE = 2,
	ELIMINATED = 4,
}


static func mode_name(mode_id: int) -> String:
	match mode_id:
		ModeId.SHOCKWAVE:
			return "shockwave"
		ModeId.FLOOD:
			return "flood"
		ModeId.SHOOTER:
			return "shooter"
		ModeId.DOMAIN:
			return "domain"
		_:
			return "meteors"


static func mode_duration_ticks(mode_id: int) -> int:
	match mode_id:
		ModeId.SHOCKWAVE:
			return 34 * SERVER_TICK_RATE
		ModeId.FLOOD:
			return 36 * SERVER_TICK_RATE
		ModeId.SHOOTER:
			return 46 * SERVER_TICK_RATE
		ModeId.DOMAIN:
			return 44 * SERVER_TICK_RATE
		_:
			return 42 * SERVER_TICK_RATE


static func mode_map_name(mode_id: int) -> String:
	if mode_id == ModeId.SHOOTER:
		return "campo_tiro"
	if mode_id == ModeId.DOMAIN:
		return "nucleo_tactico"
	return "plaza_caos"


static func mode_feature_ids(mode_id: int) -> PackedStringArray:
	if mode_id == ModeId.SHOOTER:
		return PackedStringArray(["shooter_controls"])
	if mode_id == ModeId.DOMAIN:
		return PackedStringArray(["domain_tracker"])
	return PackedStringArray()


static func mode_player_profile(mode_id: int) -> String:
	return "shooter" if mode_id == ModeId.SHOOTER else "default"


static func mode_spawn_policy(mode_id: int) -> String:
	return (
		"separated"
		if mode_id == ModeId.SHOOTER or mode_id == ModeId.DOMAIN
		else "spread"
	)
