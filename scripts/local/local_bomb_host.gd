class_name LocalBombHost
extends Node

signal bomb_holder_changed(holder_name: String)
signal bomb_timer_changed(remaining: float)
signal bomb_exploded(holder_name: String)
signal match_completed(winner_name: String)

var _active := false
var _complete := false
var _bomb
var _holder: Node3D
var _bomb_parent: Node
var _map_root: Node3D


func start_match(map_root: Node3D, player: LocalBaseCharacter) -> bool:
	stop_and_clean()
	_bomb = _find_descendant(map_root, &"bomb_collectible")
	if _bomb == null or player == null:
		return false
	_map_root = map_root
	_bomb_parent = _bomb.get_parent()
	_bomb.exploded.connect(_on_bomb_exploded)
	_active = true
	_complete = false
	_assign_holder(player)
	_bomb.arm()
	bomb_timer_changed.emit(_bomb.get_remaining())
	return true


func _physics_process(_delta: float) -> void:
	if not _active or not is_instance_valid(_holder) or not is_instance_valid(_bomb):
		return
	bomb_timer_changed.emit(_bomb.get_remaining())
	for candidate in get_tree().get_nodes_in_group(&"local_base_character"):
		if candidate != _holder and candidate is Node3D:
			if (candidate as Node3D).global_position.distance_to(_holder.global_position) < 1.15:
				_assign_holder(candidate as Node3D)
				return


func is_complete() -> bool:
	return _complete


func get_winner() -> int:
	return -1 if _complete else 1


func get_holder_name() -> String:
	return str(_holder.get_meta(&"display_name", _holder.name)) if is_instance_valid(_holder) else "NADIE"


func get_remaining() -> float:
	return _bomb.get_remaining() if is_instance_valid(_bomb) else 0.0


func finish_match() -> void:
	if not _active:
		return
	_active = false
	match_completed.emit(get_holder_name())


func stop_and_clean() -> void:
	_active = false
	_complete = false
	_set_holder_pose(false)
	if is_instance_valid(_bomb) and is_instance_valid(_bomb_parent):
		_bomb.reparent(_bomb_parent, true)
		_bomb.monitoring = true
	_holder = null
	_bomb = null
	_bomb_parent = null
	_map_root = null


func _assign_holder(next_holder: Node3D) -> void:
	if next_holder == _holder or not is_instance_valid(_bomb):
		return
	_set_holder_pose(false)
	_holder = next_holder
	var anchor := next_holder.get_node_or_null("AnchorPoints/HeldItem") as Node3D
	if anchor != null:
		_bomb.reparent(anchor, false)
		_bomb.position = Vector3(0.0, 0.0, -0.02)
		_bomb.rotation = Vector3.ZERO
	_bomb.monitoring = false
	_set_holder_pose(true)
	bomb_holder_changed.emit(get_holder_name())


func _set_holder_pose(enabled: bool) -> void:
	if is_instance_valid(_holder) and _holder is LocalBaseCharacter:
		(_holder as LocalBaseCharacter).visual_root.set_heavy_carry(enabled)


func _on_bomb_exploded() -> void:
	if not _active:
		return
	var holder_name := get_holder_name()
	var blast_position: Vector3 = _bomb.global_position if is_instance_valid(_bomb) else Vector3.ZERO
	_active = false
	_complete = true
	_set_holder_pose(false)
	_create_explosion(blast_position)
	bomb_exploded.emit(holder_name)
	match_completed.emit(holder_name)


func _create_explosion(position_value: Vector3) -> void:
	if not is_instance_valid(_map_root):
		return
	var flash := MeshInstance3D.new()
	flash.name = "BombExplosion"
	var sphere := SphereMesh.new()
	sphere.radius = 0.45
	sphere.height = 0.9
	flash.mesh = sphere
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(1.0, 0.28, 0.03, 0.92)
	material.emission_enabled = true
	material.emission = Color(1.0, 0.16, 0.01)
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	flash.material_override = material
	flash.global_position = position_value
	flash.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_map_root.add_child(flash)
	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.32, 0.05)
	light.light_energy = 5.0
	light.omni_range = 7.0
	light.shadow_enabled = false
	flash.add_child(light)
	var tween := create_tween()
	tween.tween_property(flash, "scale", Vector3.ONE * 5.0, 0.28)
	tween.parallel().tween_property(material, "albedo_color:a", 0.0, 0.28)
	tween.tween_callback(flash.queue_free)


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
