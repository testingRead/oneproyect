class_name MinigameMapDefinition
extends Resource

@export var map_id: StringName = &"map"
@export var tags := PackedStringArray(["common"])
@export_range(0.1, 10.0, 0.1) var selection_weight := 1.0
@export_range(1, 32, 1) var maximum_players := 5
@export var map_scene: PackedScene


func is_compatible(required_tags: PackedStringArray, blocked_tags: PackedStringArray) -> bool:
	for required_tag in required_tags:
		if required_tag not in tags:
			return false
	for blocked_tag in blocked_tags:
		if blocked_tag in tags:
			return false
	return true
