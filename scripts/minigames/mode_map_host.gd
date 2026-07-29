class_name ModeMapHost
extends Node3D

signal map_activated(mode_id: StringName, spawn_transform: Transform3D, has_spawn: bool)

@export var default_map_path: NodePath

var _default_map: Node3D
var _active_map: Node3D
var _cached_maps: Dictionary = {}


func _ready() -> void:
	_default_map = get_node_or_null(default_map_path) as Node3D
	_active_map = _default_map
	if _default_map == null:
		push_error("ModeMapHost requires a default map")


func activate_mode(mode_id: StringName, map_scene: PackedScene) -> void:
	var next_map := _default_map if map_scene == null else _get_or_create_map(map_scene)
	if next_map == null:
		return
	if _active_map == next_map:
		return
	_set_map_enabled(_active_map, false)
	_set_map_enabled(next_map, true)
	_active_map = next_map
	var spawn := _find_spawn(next_map)
	map_activated.emit(
		mode_id,
		spawn.global_transform if spawn != null else Transform3D.IDENTITY,
		spawn != null
	)


func get_cached_map_count() -> int:
	return _cached_maps.size()


func _get_or_create_map(map_scene: PackedScene) -> Node3D:
	var key := map_scene.resource_path
	if key.is_empty():
		key = str(map_scene.get_instance_id())
	if _cached_maps.has(key):
		return _cached_maps[key]
	var instance := map_scene.instantiate() as Node3D
	if instance == null:
		push_error("A minigame map root must inherit Node3D")
		return null
	instance.name = "ModeMap_%s" % _cached_maps.size()
	add_child(instance)
	_cached_maps[key] = instance
	_set_map_enabled(instance, false)
	return instance


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
