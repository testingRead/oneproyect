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


func variation_signature(seed: int) -> PackedByteArray:
	var signature := PackedByteArray()
	signature.resize(modular_slots.size())
	var generator := RandomNumberGenerator.new()
	generator.seed = seed
	for index in modular_slots.size():
		signature[index] = generator.randi_range(0, 1)
	return signature
