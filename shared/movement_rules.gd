class_name MovementRules
extends RefCounted

const NET := preload("res://shared/net_constants.gd")
const MOVE_SPEED := 6.0
const GROUND_ACCELERATION := 28.0
const AIR_ACCELERATION := 8.0
const JUMP_VELOCITY := 7.5
const GRAVITY := 18.0
const PLAYER_RADIUS := 0.5
const MAX_STEP_HEIGHT := 0.62
const CENTER_HALF_EXTENT := 3.0 + PLAYER_RADIUS - 0.05
const CENTER_FLOOR_HEIGHT := NET.FLOOR_HEIGHT + 0.9
const STEP_FLOOR_HEIGHT := NET.FLOOR_HEIGHT + 0.38
const PILLAR_RADIUS := 0.3 + PLAYER_RADIUS
const PILLAR_CENTERS := [
	Vector2(-10.1, -9.6),
	Vector2(-6.5, -6.0),
	Vector2(10.1, 9.6),
	Vector2(6.5, 6.0),
]


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
	var previous := position
	var candidate := position + velocity * delta
	candidate.x = clampf(candidate.x, -NET.ARENA_HALF_EXTENT, NET.ARENA_HALF_EXTENT)
	candidate.z = clampf(candidate.z, -NET.ARENA_HALF_EXTENT, NET.ARENA_HALF_EXTENT)
	var previous_floor := floor_height_at(previous)
	var candidate_floor := floor_height_at(candidate)
	if (
		candidate_floor - previous_floor > MAX_STEP_HEIGHT
		and candidate.y < candidate_floor + 0.05
	):
		var slide_x := Vector3(candidate.x, candidate.y, previous.z)
		var slide_z := Vector3(previous.x, candidate.y, candidate.z)
		candidate.x = (
			slide_x.x
			if floor_height_at(slide_x) - previous_floor <= MAX_STEP_HEIGHT
			else previous.x
		)
		candidate.z = (
			slide_z.z
			if floor_height_at(slide_z) - previous_floor <= MAX_STEP_HEIGHT
			else previous.z
		)
	if _inside_pillar(candidate):
		var slide_x := Vector3(candidate.x, candidate.y, previous.z)
		var slide_z := Vector3(previous.x, candidate.y, candidate.z)
		candidate.x = slide_x.x if not _inside_pillar(slide_x) else previous.x
		candidate.z = slide_z.z if not _inside_pillar(slide_z) else previous.z
	candidate_floor = floor_height_at(candidate)
	candidate.y = maxf(candidate.y, candidate_floor)
	return candidate


static func floor_height_at(position: Vector3) -> float:
	var x := absf(position.x)
	var z := absf(position.z)
	if x <= CENTER_HALF_EXTENT and z <= CENTER_HALF_EXTENT:
		return CENTER_FLOOR_HEIGHT
	var on_north_or_south_step := (
		x <= 1.9
		and absf(z - 3.9) <= 1.5
	)
	var on_east_or_west_step := (
		z <= 1.9
		and absf(x - 3.9) <= 1.5
	)
	return (
		STEP_FLOOR_HEIGHT
		if on_north_or_south_step or on_east_or_west_step
		else NET.FLOOR_HEIGHT
	)


static func _inside_pillar(position: Vector3) -> bool:
	var horizontal := Vector2(position.x, position.z)
	for center: Vector2 in PILLAR_CENTERS:
		if horizontal.distance_squared_to(center) < PILLAR_RADIUS * PILLAR_RADIUS:
			return true
	return false
