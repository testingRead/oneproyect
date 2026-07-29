class_name NetConstants
extends RefCounted

const PROTOCOL_VERSION := 3
const DEFAULT_PORT := 9999
const MAX_ROOMS := 5
const MAX_PLAYERS_PER_ROOM := 5
const MAX_SERVER_CONNECTIONS := MAX_ROOMS * MAX_PLAYERS_PER_ROOM
const MIN_PLAYERS_TO_START := 2
const SERVER_TICK_RATE := 20
const SERVER_TICK_DELTA := 1.0 / SERVER_TICK_RATE
const STATE_SEND_RATE := 20
const SNAPSHOT_RATE := 10
const SNAPSHOT_INTERVAL_TICKS := SERVER_TICK_RATE / SNAPSHOT_RATE
const RECONNECT_SECONDS := 60
const RECONNECT_TICKS := RECONNECT_SECONDS * SERVER_TICK_RATE

const CHANNEL_SESSION := 0
const CHANNEL_STATE := 1
const CHANNEL_EVENTS := 2
const ENET_CHANNEL_COUNT := 3

const OWNED_STATE_PACKET_SIZE := 22
const SNAPSHOT_HEADER_SIZE := 20
const SNAPSHOT_PLAYER_SIZE := 24
const SNAPSHOT_PACKET_SIZE := (
	SNAPSHOT_HEADER_SIZE + MAX_PLAYERS_PER_ROOM * SNAPSHOT_PLAYER_SIZE
)

const ARENA_HALF_EXTENT := 12.2
const FLOOR_HEIGHT := 1.2
const ALL_BODY_PARTS_MASK := 0b111111111111

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
		_:
			return "meteors"


static func mode_duration_ticks(mode_id: int) -> int:
	match mode_id:
		ModeId.SHOCKWAVE:
			return 34 * SERVER_TICK_RATE
		ModeId.FLOOD:
			return 36 * SERVER_TICK_RATE
		_:
			return 42 * SERVER_TICK_RATE
