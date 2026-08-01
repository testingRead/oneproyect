class_name MinigameMapDefinition
extends Resource

enum BoundaryPolicy {
	ISLAND_SHORE,
	PHYSICAL_AREA,
	LOGICAL_AREA,
}

@export var map_id: StringName = &"map"
@export var tags := PackedStringArray(["common"])
@export_range(0.1, 10.0, 0.1) var selection_weight := 1.0
@export_range(1, 32, 1) var maximum_players := 5
@export var map_scene: PackedScene
@export var footprint := Vector2(60.0, 60.0)
@export_range(0, 2, 1) var playable_area_index := 1
@export var boundary_policy := BoundaryPolicy.PHYSICAL_AREA
@export var spawn_points := PackedVector3Array()
@export var team_spawns_home := PackedVector3Array()
@export var team_spawns_away := PackedVector3Array()
@export var safe_zone_centres := PackedVector3Array()
@export var event_points := PackedVector3Array()
@export var navigation_points := PackedVector3Array()
@export var available_objects := PackedStringArray()
@export var compatible_disasters := PackedStringArray()
@export var compatible_minigames := PackedStringArray()
@export var modular_slots := PackedStringArray()


func is_compatible(required_tags: PackedStringArray, blocked_tags: PackedStringArray) -> bool:
	for required_tag in required_tags:
		if required_tag not in tags:
			return false
	for blocked_tag in blocked_tags:
		if blocked_tag in tags:
			return false
	return true


func supports_disaster(disaster_id: StringName) -> bool:
	return String(disaster_id) in compatible_disasters


func supports_minigame(minigame_id: StringName) -> bool:
	return String(minigame_id) in compatible_minigames


func has_team_layout() -> bool:
	return not team_spawns_home.is_empty() and not team_spawns_away.is_empty()


func get_team_for_slot(slot: int) -> StringName:
	return &"home" if posmod(slot, 2) == 0 else &"away"


func get_spawn_for_slot(slot: int) -> Vector3:
	if not has_team_layout():
		if spawn_points.is_empty():
			return Vector3(0.0, 0.02, 8.0)
		return spawn_points[posmod(slot, spawn_points.size())]
	var points := team_spawns_home if get_team_for_slot(slot) == &"home" else team_spawns_away
	var team_index := posmod(slot, maximum_players) >> 1
	return points[posmod(team_index, points.size())]


func get_team_facing_for_slot(slot: int) -> Vector3:
	if not has_team_layout():
		if spawn_points.size() <= 1:
			return Vector3(0.0, 0.0, -1.0)
		var spawn := get_spawn_for_slot(slot)
		var spawn_centre := Vector3.ZERO
		for point in spawn_points:
			spawn_centre += point
		spawn_centre /= float(spawn_points.size())
		var centre_facing := spawn_centre - spawn
		centre_facing.y = 0.0
		return (
			centre_facing.normalized()
			if centre_facing.length_squared() > 0.01
			else Vector3(0.0, 0.0, -1.0)
		)
	var spawn := get_spawn_for_slot(slot)
	var centre := Vector3.ZERO
	var count := 0
	for point in team_spawns_home:
		centre += point
		count += 1
	for point in team_spawns_away:
		centre += point
		count += 1
	centre /= maxf(1.0, float(count))
	var facing := centre - spawn
	facing.y = 0.0
	return facing.normalized() if facing.length_squared() > 0.01 else Vector3(0.0, 0.0, -1.0)


func variation_signature(seed: int) -> PackedByteArray:
	var signature := PackedByteArray()
	signature.resize(modular_slots.size())
	var generator := RandomNumberGenerator.new()
	generator.seed = seed
	for index in modular_slots.size():
		signature[index] = generator.randi_range(0, 1)
	return signature
