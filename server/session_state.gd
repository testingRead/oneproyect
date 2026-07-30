class_name ServerSessionState
extends RefCounted

const NET := preload("res://shared/net_constants.gd")
const CODEC := preload("res://shared/net_codec.gd")
const MAX_RELAY_POSITION := 80.0
const MAX_RELAY_SPEED := 80.0

var player_id := 0
var room_id := 1
var stable_id := ""
var reconnect_token := ""
var peer_id := 0
var display_name := "Jugador"
var color_index := 0
var profile_victories := 0
var profile_experience := 0
var ready := false
var excluded_mode_id := -1
var connected := false
var reconnect_until_tick := 0

var position := Vector3(0.0, NET.FLOOR_HEIGHT, 8.0)
var velocity := Vector3.ZERO
var facing_yaw := 0.0
var health := 100
var active := true
var score := 0
var round_points := 0
var body_mask := NET.ALL_BODY_PARTS_MASK
var last_state_sequence := 0
var last_state_tick := 0
var last_shot_tick := -1000
var objective_ticks := 0
var weapon_shots := 0
var weapon_reload_until_tick := 0


func accept_owned_state(
	packet: PackedByteArray,
	server_tick: int,
	lock_authoritative_health := false
) -> bool:
	if not connected or not CODEC.is_valid_owned_state(packet):
		return false
	var sequence := CODEC.owned_state_sequence(packet)
	if sequence <= last_state_sequence:
		return false
	var next_position := CODEC.owned_state_position(packet)
	var next_velocity := CODEC.owned_state_velocity(packet)
	if (
		not next_position.is_finite()
		or not next_velocity.is_finite()
		or absf(next_position.x) > MAX_RELAY_POSITION
		or absf(next_position.y) > MAX_RELAY_POSITION
		or absf(next_position.z) > MAX_RELAY_POSITION
		or next_velocity.length() > MAX_RELAY_SPEED
	):
		return false
	last_state_sequence = sequence
	last_state_tick = server_tick
	position = next_position
	velocity = next_velocity
	facing_yaw = wrapf(CODEC.owned_state_yaw(packet), -PI, PI)
	var reported_health := clampi(CODEC.owned_state_health(packet), 0, 100)
	# Once eliminated, a client cannot revive itself until the room opens
	# the next round. Physics remain client-owned; this is only a round rule.
	health = (
		mini(health, reported_health)
		if lock_authoritative_health and active
		else (0 if not active else reported_health)
	)
	body_mask = CODEC.owned_state_body_mask(packet) & NET.ALL_BODY_PARTS_MASK
	active = health > 0
	return true


func prepare_next_round() -> void:
	health = 100
	active = true
	round_points = 0
	body_mask = NET.ALL_BODY_PARTS_MASK
	last_shot_tick = -1000
	objective_ticks = 0
	weapon_shots = 0
	weapon_reload_until_tick = 0


func player_flags() -> int:
	var flags := NET.PlayerFlags.CONNECTED if connected else 0
	flags |= NET.PlayerFlags.ACTIVE if active else NET.PlayerFlags.ELIMINATED
	return flags
