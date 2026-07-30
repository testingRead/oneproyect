class_name GameplayScale
extends RefCounted

## Official local gameplay measurements. One Godot unit equals one metre.
const CHARACTER_HEIGHT := 1.80
const CHARACTER_WIDTH := 0.72
const CHARACTER_MASS := 70.0
const COLLISION_HEIGHT := 1.72
const COLLISION_RADIUS := 0.34
const VISUAL_GROUND_OFFSET := 0.0
const FOOT_REFERENCE_HEIGHT := 0.0
const STEP_HEIGHT := 0.30
const FLOOR_SNAP_DISTANCE := 0.28

const WALK_SPEED := 3.60
const RUN_SPEED := 6.00
const GROUND_ACCELERATION := 24.0
const GROUND_DECELERATION := 30.0
const AIR_ACCELERATION := 7.0
const GRAVITY := 18.0
const JUMP_HEIGHT := 1.35
const JUMP_VELOCITY := sqrt(2.0 * GRAVITY * JUMP_HEIGHT)
const APPROXIMATE_JUMP_DISTANCE := RUN_SPEED * (2.0 * JUMP_VELOCITY / GRAVITY)

const STANDARD_PLATFORM_HEIGHT := 0.45
const MINIMUM_DOOR_HEIGHT := 2.20
const MINIMUM_PASSAGE_WIDTH := 1.10
const SMALL_OBJECT_SIZE := 0.40
const MEDIUM_OBJECT_SIZE := 1.00
const LARGE_OBJECT_SIZE := 2.00

const PHYSICAL_WORLD_SIZE := 150.0
const ISLAND_SIZE := 120.0
const PLAYABLE_AREA_SMALL := 30.0
const PLAYABLE_AREA_MEDIUM := 60.0
const PLAYABLE_AREA_LARGE := 100.0

const STATURE_SHORT := 0.86
const STATURE_STANDARD := 1.0
const STATURE_TALL := 1.14


static func collision_bottom(root_y: float, stature := STATURE_STANDARD) -> float:
	var height := COLLISION_HEIGHT * stature
	return root_y + height * 0.5 - height * 0.5


static func playable_bounds(size: float, center := Vector2.ZERO) -> Rect2:
	var safe_size := clampf(size, PLAYABLE_AREA_SMALL, PLAYABLE_AREA_LARGE)
	return Rect2(center - Vector2.ONE * safe_size * 0.5, Vector2.ONE * safe_size)
