class_name ClientPrediction
extends RefCounted

const NET := preload("res://shared/net_constants.gd")
const MOVEMENT := preload("res://shared/movement_rules.gd")

var predicted_position := Vector3(0.0, NET.FLOOR_HEIGHT, 8.0)
var predicted_velocity := Vector3.ZERO

var _sequences := PackedInt32Array()
var _moves := PackedVector2Array()
var _flags := PackedByteArray()


func reset(position: Vector3, velocity := Vector3.ZERO) -> void:
	predicted_position = position
	predicted_velocity = velocity
	_sequences.clear()
	_moves.clear()
	_flags.clear()


func predict(sequence: int, move: Vector2, flags: int) -> void:
	_sequences.append(sequence)
	_moves.append(MOVEMENT.sanitize_move(move))
	_flags.append(flags & 0xff)
	_step(_moves[-1], _flags[-1])
	if _sequences.size() > NET.INPUT_SEND_RATE * 2:
		_sequences.remove_at(0)
		_moves.remove_at(0)
		_flags.remove_at(0)


func reconcile(
	authoritative_position: Vector3,
	authoritative_velocity: Vector3,
	ack_sequence: int
) -> Vector3:
	predicted_position = authoritative_position
	predicted_velocity = authoritative_velocity
	while not _sequences.is_empty() and _sequences[0] <= ack_sequence:
		_sequences.remove_at(0)
		_moves.remove_at(0)
		_flags.remove_at(0)
	for index in _sequences.size():
		_step(_moves[index], _flags[index])
	return predicted_position


func pending_count() -> int:
	return _sequences.size()


func apply_external_impulse(direction: Vector3, force: float) -> void:
	var safe_direction := direction
	safe_direction.y = 0.0
	if not safe_direction.is_finite() or safe_direction.length_squared() < 0.01:
		return
	safe_direction = safe_direction.normalized()
	predicted_velocity.x += safe_direction.x * force
	predicted_velocity.z += safe_direction.z * force
	predicted_velocity.y = maxf(predicted_velocity.y, force * 0.42)


func _step(move: Vector2, flags: int) -> void:
	var floor_height := MOVEMENT.floor_height_at(predicted_position)
	var on_floor := (
		predicted_position.y <= floor_height + 0.001
		and predicted_velocity.y <= 0.0
	)
	predicted_velocity = MOVEMENT.step_velocity(
		predicted_velocity,
		move,
		bool(flags & NET.InputFlags.JUMP),
		on_floor,
		NET.SERVER_TICK_DELTA
	)
	predicted_position = MOVEMENT.step_position(
		predicted_position,
		predicted_velocity,
		NET.SERVER_TICK_DELTA
	)
	floor_height = MOVEMENT.floor_height_at(predicted_position)
	if predicted_position.y <= floor_height and predicted_velocity.y < 0.0:
		predicted_position.y = floor_height
		predicted_velocity.y = 0.0
