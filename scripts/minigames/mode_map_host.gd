class_name ModeMapHost
extends Node3D

const MAP_DEFINITION_SCRIPT := preload("res://scripts/minigames/map_definition.gd")

signal map_activated(
	mode_id: StringName,
	map_id: StringName,
	spawn_transform: Transform3D,
	has_spawn: bool
)

@export var default_map_path: NodePath
@export var default_map_id: StringName = &"plaza_caos"
@export var map_definitions: Array[Resource] = []

var _default_map: Node3D
var _active_map: Node3D
var _active_map_id: StringName = &""
var _cached_maps: Dictionary = {}
var _definition_by_id: Dictionary = {}


func _ready() -> void:
	_default_map = get_node_or_null(default_map_path) as Node3D
	_active_map = _default_map
	_active_map_id = default_map_id
	if _default_map == null:
		push_error("ModeMapHost requires a default map")
	_ensure_registry()


func get_compatible_map_ids(
	required_tags: PackedStringArray,
	blocked_tags: PackedStringArray,
	pinned_map_id: StringName = &"",
	player_count := 1
) -> Array[StringName]:
	_ensure_registry()
	var ids: Array[StringName] = []
	for map_id: StringName in _definition_by_id:
		if not pinned_map_id.is_empty() and map_id != pinned_map_id:
			continue
		var definition: Resource = _definition_by_id[map_id]
		if player_count > int(definition.get("maximum_players")):
			continue
		if definition.call("is_compatible", required_tags, blocked_tags):
			ids.append(map_id)
	return ids


func get_map_weight(map_id: StringName) -> float:
	_ensure_registry()
	var definition: Resource = _definition_by_id.get(map_id)
	return maxf(0.1, float(definition.get("selection_weight"))) if definition != null else 0.1


func get_registered_map_ids() -> Array[StringName]:
	_ensure_registry()
	var ids: Array[StringName] = []
	for map_id: StringName in _definition_by_id:
		ids.append(map_id)
	return ids


func activate_selection(mode_id: StringName, map_id: StringName) -> void:
	_ensure_registry()
	var definition: Resource = _definition_by_id.get(map_id)
	if definition == null:
		push_warning("Unknown minigame map: %s" % map_id)
		return
	var map_scene := definition.get("map_scene") as PackedScene
	var next_map := (
		_default_map
		if map_id == default_map_id and map_scene == null
		else _get_or_create_map(map_id, map_scene)
	)
	_activate_map(mode_id, map_id, next_map)


func register_runtime_map(
	map_id: StringName,
	map_scene: PackedScene,
	tags: PackedStringArray,
	selection_weight := 1.0,
	maximum_players := 5
) -> void:
	var definition: Resource = MAP_DEFINITION_SCRIPT.new()
	definition.set("map_id", map_id)
	definition.set("map_scene", map_scene)
	definition.set("tags", tags)
	definition.set("selection_weight", maxf(0.1, selection_weight))
	definition.set("maximum_players", clampi(maximum_players, 1, 32))
	_definition_by_id[map_id] = definition


func get_cached_map_count() -> int:
	return _cached_maps.size()


func _ensure_registry() -> void:
	if not _definition_by_id.is_empty():
		return
	for definition in map_definitions:
		if definition == null:
			continue
		var map_id := StringName(definition.get("map_id"))
		if map_id.is_empty() or _definition_by_id.has(map_id):
			continue
		_definition_by_id[map_id] = definition


func _get_or_create_map(map_id: StringName, map_scene: PackedScene) -> Node3D:
	if map_scene == null:
		push_error("Non-default map %s requires a PackedScene" % map_id)
		return null
	if _cached_maps.has(map_id):
		return _cached_maps[map_id]
	var instance := map_scene.instantiate() as Node3D
	if instance == null:
		push_error("A minigame map root must inherit Node3D")
		return null
	instance.name = "ModeMap_%s" % map_id
	add_child(instance)
	_cached_maps[map_id] = instance
	_set_map_enabled(instance, false)
	return instance


func _activate_map(mode_id: StringName, map_id: StringName, next_map: Node3D) -> void:
	if next_map == null:
		return
	if _active_map == next_map:
		_active_map_id = map_id
		return
	_set_map_enabled(_active_map, false)
	_set_map_enabled(next_map, true)
	_active_map = next_map
	_active_map_id = map_id
	var spawn := _find_spawn(next_map)
	map_activated.emit(
		mode_id,
		map_id,
		spawn.global_transform if spawn != null else Transform3D.IDENTITY,
		spawn != null
	)


func _set_map_enabled(map_root: Node3D, enabled: bool) -> void:
	if map_root == null:
		return
	map_root.visible = enabled
	map_root.process_mode = (
		Node.PROCESS_MODE_INHERIT if enabled else Node.PROCESS_MODE_DISABLED
	)
	_set_collisions_recursive(map_root, enabled)


func _set_collisions_recursive(node: Node, enabled: bool) -> void:
	if node is CollisionObject3D:
		var collision_object := node as CollisionObject3D
		if not collision_object.has_meta(&"original_collision_layer"):
			collision_object.set_meta(&"original_collision_layer", collision_object.collision_layer)
			collision_object.set_meta(&"original_collision_mask", collision_object.collision_mask)
		collision_object.collision_layer = (
			int(collision_object.get_meta(&"original_collision_layer")) if enabled else 0
		)
		collision_object.collision_mask = (
			int(collision_object.get_meta(&"original_collision_mask")) if enabled else 0
		)
	for child in node.get_children():
		_set_collisions_recursive(child, enabled)


func _find_spawn(node: Node) -> Node3D:
	if node is Node3D and node.is_in_group(&"player_spawn"):
		return node as Node3D
	for child in node.get_children():
		var found := _find_spawn(child)
		if found != null:
			return found
	return null
