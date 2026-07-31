class_name ContentRegistry
extends RefCounted

const CHARACTER_DIRECTORIES := ["res://data/characters", "res://content/characters"]
const MINIGAME_DIRECTORIES := ["res://data/minigames", "res://content/minigames"]


static func load_characters() -> Array:
	var result: Array = []
	for directory in CHARACTER_DIRECTORIES:
		for path in _resource_paths(directory):
			var definition = load(path)
			if definition != null and bool(definition.enabled) and definition.character_scene != null:
				result.append(definition)
	result.sort_custom(func(a, b): return str(a.character_id) < str(b.character_id))
	return result


static func load_minigames() -> Array:
	var result: Array = []
	for directory in MINIGAME_DIRECTORIES:
		for path in _resource_paths(directory):
			var definition = load(path)
			if definition != null and bool(definition.enabled) and definition.map_definition != null:
				result.append(definition)
	result.sort_custom(func(a, b): return str(a.minigame_id) < str(b.minigame_id))
	return result


static func _resource_paths(directory: String) -> PackedStringArray:
	var paths := PackedStringArray()
	var access := DirAccess.open(directory)
	if access == null:
		return paths
	access.list_dir_begin()
	var entry := access.get_next()
	while not entry.is_empty():
		if not access.current_is_dir() and entry.ends_with(".tres"):
			paths.append("%s/%s" % [directory, entry])
		entry = access.get_next()
	access.list_dir_end()
	return paths
