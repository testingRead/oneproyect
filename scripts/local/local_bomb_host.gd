class_name LocalBombHost
extends Node

signal bomb_holder_changed(holder_name: String)
signal bomb_timer_changed(remaining: float)
signal bomb_exploded(holder_name: String)
signal match_completed(winner_name: String)
signal bomb_holder_peer_changed(peer_id: int, remaining_msec: int)
signal bomb_explosion_authorized(loser_peer_id: int, position: Vector3)

var _active := false
var _complete := false
var _bomb
var _holder: Node3D
var _bomb_parent: Node
var _map_root: Node3D
var _local_player: LocalBaseCharacter
var _session_authority := true
var _transfer_cooldown := 0.0

const TRANSFER_COOLDOWN_SECONDS := 0.7


func start_match(
	map_root: Node3D,
	player: LocalBaseCharacter,
	round_seed := 0,
	time_scale := 1.0
) -> bool:
	stop_and_clean()
	_bomb = _find_descendant(map_root, &"bomb_collectible")
	if _bomb == null or player == null:
		return false
	_map_root = map_root
	_local_player = player
	_bomb_parent = _bomb.get_parent()
	_bomb.exploded.connect(_on_bomb_exploded)
	_active = true
	_complete = false
	_transfer_cooldown = 0.0
	_bomb.arm(_session_authority, time_scale)
	if _session_authority:
		_assign_holder(_select_initial_holder(player, round_seed))
	bomb_timer_changed.emit(_bomb.get_remaining())
	return true


func _physics_process(delta: float) -> void:
	if not _active or not is_instance_valid(_bomb):
		return
	bomb_timer_changed.emit(_bomb.get_remaining())
	if not _session_authority or not is_instance_valid(_holder):
		return
	_transfer_cooldown = maxf(0.0, _transfer_cooldown - delta)
	if _transfer_cooldown > 0.0:
		return
	for candidate in get_tree().get_nodes_in_group(&"local_base_character"):
		if candidate != _holder and candidate is Node3D:
			if _characters_touch(candidate as Node3D, _holder):
				_assign_holder(candidate as Node3D)
				return


func is_complete() -> bool:
	return _complete


func get_winner() -> int:
	if not _complete or not is_instance_valid(_local_player):
		return 0
	return -1 if _holder == _local_player else 1


func get_holder_name() -> String:
	if not is_instance_valid(_holder):
		return "NADIE"
	var display_name := str(_holder.get_meta(&"display_name", "")).strip_edges()
	return display_name if not display_name.is_empty() else "JUGADOR"


func get_holder_peer_id() -> int:
	return int(_holder.get_meta(&"lan_peer_id", 1)) if is_instance_valid(_holder) else 0


func get_remaining() -> float:
	return _bomb.get_remaining() if is_instance_valid(_bomb) else 0.0


func is_holder(character: LocalBaseCharacter) -> bool:
	return is_instance_valid(character) and character == _holder


func is_active() -> bool:
	return _active and is_instance_valid(_bomb)


func set_session_authority(enabled: bool) -> void:
	_session_authority = enabled


func apply_authoritative_holder(next_holder: Node3D, remaining_msec: int) -> void:
	if not is_instance_valid(_bomb):
		return
	_bomb.synchronize_remaining(float(maxi(0, remaining_msec)) / 1000.0)
	if is_instance_valid(next_holder):
		_assign_holder(next_holder, false)
	else:
		_clear_holder(false)


func apply_authoritative_explosion(loser: Node3D, position_value: Vector3) -> void:
	if not _active or _complete:
		return
	if is_instance_valid(loser):
		_assign_holder(loser, false)
	_complete_explosion(position_value, false)


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
	_local_player = null
	_transfer_cooldown = 0.0


func _assign_holder(next_holder: Node3D, announce := true) -> void:
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
	_transfer_cooldown = TRANSFER_COOLDOWN_SECONDS
	_set_holder_pose(true)
	bomb_holder_changed.emit(get_holder_name())
	if announce:
		bomb_holder_peer_changed.emit(
			int(next_holder.get_meta(&"lan_peer_id", 1)),
			roundi(_bomb.get_remaining() * 1000.0)
		)


func _clear_holder(announce := true) -> void:
	_set_holder_pose(false)
	if is_instance_valid(_bomb) and is_instance_valid(_bomb_parent):
		_bomb.reparent(_bomb_parent, true)
	_holder = null
	bomb_holder_changed.emit("NADIE")
	if announce:
		bomb_holder_peer_changed.emit(0, roundi(get_remaining() * 1000.0))


func _set_holder_pose(enabled: bool) -> void:
	if is_instance_valid(_holder) and _holder is LocalBaseCharacter:
		(_holder as LocalBaseCharacter).visual_root.set_heavy_carry(enabled)


func _on_bomb_exploded() -> void:
	if not _active:
		return
	var blast_position: Vector3 = _bomb.global_position if is_instance_valid(_bomb) else Vector3.ZERO
	_complete_explosion(blast_position, true)


func _complete_explosion(blast_position: Vector3, announce: bool) -> void:
	var holder_name := get_holder_name()
	var loser_peer_id := int(_holder.get_meta(&"lan_peer_id", 1)) if is_instance_valid(_holder) else 0
	_active = false
	_complete = true
	_set_holder_pose(false)
	_create_explosion(blast_position)
	bomb_exploded.emit(holder_name)
	match_completed.emit(holder_name)
	if announce:
		bomb_explosion_authorized.emit(loser_peer_id, blast_position)


func _select_initial_holder(fallback: LocalBaseCharacter, round_seed: int) -> Node3D:
	var candidates: Array[Node3D] = []
	for candidate in get_tree().get_nodes_in_group(&"local_base_character"):
		if candidate is Node3D:
			candidates.append(candidate as Node3D)
	if candidates.is_empty():
		return fallback
	candidates.sort_custom(func(a: Node3D, b: Node3D) -> bool:
		return int(a.get_meta(&"lan_slot", 0)) < int(b.get_meta(&"lan_slot", 0))
	)
	return candidates[posmod(round_seed, candidates.size())]


func _characters_touch(a: Node3D, b: Node3D) -> bool:
	var offset := a.global_position - b.global_position
	var vertical_distance := absf(offset.y)
	offset.y = 0.0
	return vertical_distance <= 1.85 and offset.length() <= 1.05


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
	flash.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_map_root.add_child(flash)
	flash.global_position = position_value
	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.32, 0.05)
	light.light_energy = 5.0
	light.omni_range = 7.0
	light.shadow_enabled = false
	flash.add_child(light)
	var tween := flash.create_tween()
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
