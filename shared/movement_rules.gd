class_name MovementRules
extends RefCounted

const NET := preload("res://shared/net_constants.gd")
const MOVE_SPEED := 6.0
const GROUND_ACCELERATION := 28.0
const AIR_ACCELERATION := 8.0
const JUMP_VELOCITY := 7.5
const GRAVITY := 18.0


static func sanitize_move(move: Vector2) -> Vector2:
	if not move.is_finite():
		return Vector2.ZERO
	return move.limit_length(1.0)


static func step_velocity(
	velocity: Vector3,
	move: Vector2,
	jump: bool,
	on_floor: bool,
	delta: float
) -> Vector3:
	var safe_move := sanitize_move(move)
	var acceleration := GROUND_ACCELERATION if on_floor else AIR_ACCELERATION
	velocity.x = move_toward(velocity.x, safe_move.x * MOVE_SPEED, acceleration * delta)
	velocity.z = move_toward(velocity.z, safe_move.y * MOVE_SPEED, acceleration * delta)
	if on_floor:
		velocity.y = JUMP_VELOCITY if jump else 0.0
	else:
		velocity.y -= GRAVITY * delta
	return velocity


static func step_position(position: Vector3, velocity: Vector3, delta: float) -> Vector3:
	position += velocity * delta
	position.x = clampf(position.x, -NET.ARENA_HALF_EXTENT, NET.ARENA_HALF_EXTENT)
	position.z = clampf(position.z, -NET.ARENA_HALF_EXTENT, NET.ARENA_HALF_EXTENT)
	position.y = maxf(position.y, NET.FLOOR_HEIGHT)
	return position
