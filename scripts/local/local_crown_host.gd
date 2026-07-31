class_name LocalCrownHost
extends Node

signal crown_holder_changed(holder_name: String)
signal match_completed(holder_name: String)
signal crown_holder_peer_changed(peer_id: int)

var _active := false
var _crown: Area3D
var _holder: Node3D
var _generation := 0
var _crown_parent: Node
var _local_player: LocalBaseCharacter
var _session_authority := true
var _transfer_cooldown := 0.0

const TRANSFER_COOLDOWN_SECONDS := 0.65


func start_match(map_root: Node3D, player: LocalBaseCharacter) -> bool:
	stop_and_clean()
	_generation += 1
	_crown = _find_descendant(map_root, &"crown_collectible") as Area3D
	if _crown == null:
		return false
	_crown_parent = _crown.get_parent()
	_local_player = player
	_crown.body_entered.connect(_on_crown_body_entered)
	_active = true
	crown_holder_changed.emit("NADIE")
	if _session_authority:
		crown_holder_peer_changed.emit(0)
	return true


func _physics_process(delta: float) -> void:
	if not _active or not _session_authority or not is_instance_valid(_holder):
		return
	_transfer_cooldown = maxf(0.0, _transfer_cooldown - delta)
	if _transfer_cooldown > 0.0:
		return
	for candidate in get_tree().get_nodes_in_group(&"local_base_character"):
		if candidate != _holder and candidate is Node3D:
			if _characters_touch(candidate as Node3D, _holder):
				_assign_holder(candidate as Node3D)
				return


func finish_match() -> void:
	if not _active:
		return
	_active = false
	match_completed.emit(get_holder_name())


func get_winner() -> int:
	if not is_instance_valid(_holder):
		return 0
	return 1 if _holder == _local_player else -1


func is_active() -> bool:
	return _active and is_instance_valid(_crown)


func get_holder_name() -> String:
	if not is_instance_valid(_holder):
		return "NADIE"
	var display_name := str(_holder.get_meta(&"display_name", "")).strip_edges()
	return display_name if not display_name.is_empty() else "JUGADOR"


func set_session_authority(enabled: bool) -> void:
	_session_authority = enabled


func apply_authoritative_holder(next_holder: Node3D) -> void:
	if is_instance_valid(next_holder):
		_assign_holder(next_holder, false)
	else:
		_clear_holder(false)


func stop_and_clean() -> void:
	_generation += 1
	_active = false
	if is_instance_valid(_crown) and is_instance_valid(_crown_parent):
		_crown.reparent(_crown_parent, true)
	_holder = null
	_transfer_cooldown = 0.0
	_local_player = null
	_crown = null
	_crown_parent = null


func _on_crown_body_entered(body: Node3D) -> void:
	if _active and _session_authority and body.is_in_group(&"local_base_character"):
		call_deferred("_assign_holder", body)


func _assign_holder(next_holder: Node3D, announce := true) -> void:
	if next_holder == _holder or not is_instance_valid(_crown):
		return
	_holder = next_holder
	_transfer_cooldown = TRANSFER_COOLDOWN_SECONDS
	var anchor := next_holder.get_node_or_null("AnchorPoints/Head") as Node3D
	if anchor != null:
		_crown.reparent(anchor, false)
		_crown.position = Vector3(0.0, 0.22, 0.0)
		_crown.rotation = Vector3.ZERO
	_crown.monitoring = false
	crown_holder_changed.emit(get_holder_name())
	if announce:
		crown_holder_peer_changed.emit(int(next_holder.get_meta(&"lan_peer_id", 1)))


func _clear_holder(announce := true) -> void:
	if is_instance_valid(_crown) and is_instance_valid(_crown_parent):
		_crown.reparent(_crown_parent, true)
		_crown.monitoring = _session_authority
	_holder = null
	crown_holder_changed.emit("NADIE")
	if announce:
		crown_holder_peer_changed.emit(0)


func _characters_touch(a: Node3D, b: Node3D) -> bool:
	var offset := a.global_position - b.global_position
	var vertical_distance := absf(offset.y)
	offset.y = 0.0
	return vertical_distance <= 1.85 and offset.length() <= 1.05


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
