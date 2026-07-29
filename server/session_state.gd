class_name ServerSessionState
extends RefCounted

const NET := preload("res://shared/net_constants.gd")
const CODEC := preload("res://shared/net_codec.gd")
const MOVEMENT := preload("res://shared/movement_rules.gd")

var player_id := 0
var room_id := 1
var stable_id := ""
var reconnect_token := ""
var peer_id := 0
var display_name := "Jugador"
var color_index := 0
var ready := false
var connected := false
var reconnect_until_tick := 0

var position := Vector3(0.0, NET.FLOOR_HEIGHT, 8.0)
var velocity := Vector3.ZERO
var facing_yaw := 0.0
var health := 100
var active := true
var score := 0
var body_mask := NET.ALL_BODY_PARTS_MASK
var last_input_sequence := 0

var input_move := Vector2.ZERO
var input_flags := 0
var last_input_tick := 0
var _accepted_input_tick := -1
var _jump_pending := false


func accept_input(packet: PackedByteArray, server_tick: int) -> bool:
	if not connected or not CODEC.is_valid_input(packet):
		return false
	var sequence := CODEC.input_sequence(packet)
	if sequence <= last_input_sequence or _accepted_input_tick == server_tick:
		return false
	var move := MOVEMENT.sanitize_move(CODEC.input_move(packet))
	if move.length_squared() > 1.0001:
		return false
	last_input_sequence = sequence
	input_move = move
	facing_yaw = wrapf(CODEC.input_yaw(packet), -PI, PI)
	input_flags = CODEC.input_flags(packet)
	_jump_pending = _jump_pending or bool(input_flags & NET.InputFlags.JUMP)
	last_input_tick = server_tick
	_accepted_input_tick = server_tick
	return true


func simulate(server_tick: int) -> void:
	if not connected or not active:
		return
	var move := input_move
	if server_tick - last_input_tick > NET.MAX_INPUT_AGE_TICKS:
		move = Vector2.ZERO
	var floor_height := MOVEMENT.floor_height_at(position)
	var on_floor := (
		position.y <= floor_height + 0.001
		and velocity.y <= 0.0
	)
	velocity = MOVEMENT.step_velocity(
		velocity,
		move,
		_jump_pending,
		on_floor,
		NET.SERVER_TICK_DELTA
	)
	_jump_pending = false
	position = MOVEMENT.step_position(position, velocity, NET.SERVER_TICK_DELTA)
	floor_height = MOVEMENT.floor_height_at(position)
	if position.y <= floor_height and velocity.y < 0.0:
		position.y = floor_height
		velocity.y = 0.0


func player_flags() -> int:
	var flags := NET.PlayerFlags.CONNECTED if connected else 0
	flags |= NET.PlayerFlags.ACTIVE if active else NET.PlayerFlags.ELIMINATED
	return flags
