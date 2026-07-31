class_name LocalCrownHost
extends Node

signal crown_holder_changed(holder_name: String)
signal match_completed(holder_name: String)

var _active := false
var _crown: Area3D
var _holder: Node3D
var _generation := 0
var _crown_parent: Node


func start_match(map_root: Node3D, player: LocalBaseCharacter) -> bool:
	stop_and_clean()
	_generation += 1
	_crown = _find_descendant(map_root, &"crown_collectible") as Area3D
	if _crown == null:
		return false
	_crown_parent = _crown.get_parent()
	_crown.body_entered.connect(_on_crown_body_entered)
	_active = true
	crown_holder_changed.emit("NADIE")
	return true


func _physics_process(_delta: float) -> void:
	if not _active or not is_instance_valid(_holder):
		return
	for candidate in get_tree().get_nodes_in_group(&"local_base_character"):
		if candidate != _holder and candidate is Node3D:
			if (candidate as Node3D).global_position.distance_to(_holder.global_position) < 1.0:
				_assign_holder(candidate as Node3D)
				return


func finish_match() -> void:
	if not _active:
		return
	_active = false
	match_completed.emit(_holder.name if is_instance_valid(_holder) else "NADIE")


func get_winner() -> int:
	return 1 if is_instance_valid(_holder) else -1


func get_holder_name() -> String:
	return _holder.name if is_instance_valid(_holder) else "NADIE"


func stop_and_clean() -> void:
	_generation += 1
	_active = false
	if is_instance_valid(_crown) and is_instance_valid(_crown_parent):
		_crown.reparent(_crown_parent, true)
	_holder = null
	_crown = null
	_crown_parent = null


func _on_crown_body_entered(body: Node3D) -> void:
	if _active and body.is_in_group(&"local_base_character"):
		call_deferred("_assign_holder", body)


func _assign_holder(next_holder: Node3D) -> void:
	if next_holder == _holder or not is_instance_valid(_crown):
		return
	_holder = next_holder
	var anchor := next_holder.get_node_or_null("AnchorPoints/Head") as Node3D
	if anchor != null:
		_crown.reparent(anchor, false)
		_crown.position = Vector3(0.0, 0.22, 0.0)
		_crown.rotation = Vector3.ZERO
	_crown.monitoring = false
	crown_holder_changed.emit(next_holder.name)


func _find_descendant(root: Node, group: StringName) -> Node:
	if root == null:
		return null
	if root.is_in_group(group):
		return root
	for child in root.get_children():
		var found := _find_descendant(child, group)
		if found != null:
			return found
	return null
