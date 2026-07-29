class_name DisasterController
extends Node3D

const NET := preload("res://shared/net_constants.gd")

signal state_changed(title: String, detail: String)
signal clock_changed(seconds_left: int)
signal round_survived(round_number: int)
signal round_started(round_number: int)
signal experience_selected(plan: Dictionary)
signal experience_ended
signal meteor_warning
signal meteor_impact
signal shockwave_warning
signal shockwave_started

enum RoundState {
	COUNTDOWN,
	ACTIVE,
	RESULT,
}

@export var countdown_duration := 5.0
@export var result_duration := 6.0

@onready var network: Variant = get_node("/root/Network")
@onready var map_host: Node3D = $"../ModeMapHost"

var state := RoundState.COUNTDOWN
var round_number := 0
var current_mode_id: StringName = &""
var _time_left := 0.0
var _last_clock_second := -1
var _network_sync_elapsed := 0.0
var _modes: Array[Node3D] = []
var _active_mode: Node3D
var _upcoming_plan: Dictionary = {}
var _current_plan: Dictionary = {}
var _last_mode_id: StringName = &""
var _random := RandomNumberGenerator.new()


func _ready() -> void:
	_random.randomize()
	for child in get_children():
		if (
			child is Node3D
			and child.has_method("begin_round")
			and child.has_method("tick_round")
			and child.has_method("finish_round")
		):
			_register_mode(child)
	if _modes.is_empty():
		push_error("DisasterController requires at least one MinigameMode child")
		set_physics_process(false)
		return
	_begin_countdown()


func _physics_process(delta: float) -> void:
	_time_left -= delta
	var displayed_second := maxi(0, ceili(_time_left))
	if displayed_second != _last_clock_second:
		_last_clock_second = displayed_second
		clock_changed.emit(displayed_second)

	var authoritative: bool = not network.is_online() or network.is_simulation_host()
	if state == RoundState.ACTIVE and _active_mode != null:
		var intensity := 1.0 - clampf(_time_left / _active_mode.round_duration, 0.0, 1.0)
		_active_mode.tick_round(delta, _time_left, intensity, authoritative)

	if not authoritative:
		return
	if network.is_simulation_host():
		_network_sync_elapsed += delta
		if _network_sync_elapsed >= 1.0:
			_network_sync_elapsed = 0.0
			_sync_round_state()

	match state:
		RoundState.COUNTDOWN:
			if _time_left <= 0.0:
				_begin_active_round()
		RoundState.ACTIVE:
			if _time_left <= 0.0:
				_begin_result()
		RoundState.RESULT:
			if _time_left <= 0.0:
				_begin_countdown()


func restart_cycle() -> void:
	for mode in _modes:
		mode.reset_mode()
	round_number = 0
	_active_mode = null
	_upcoming_plan.clear()
	_current_plan.clear()
	_last_mode_id = &""
	current_mode_id = &""
	_begin_countdown()


func spawn_network_meteor(
	target: Vector3,
	drift: Vector2,
	damage: int,
	blast_force: float
) -> void:
	var mode := _find_mode_with_method(&"spawn_network_meteor")
	if mode != null:
		mode.call("spawn_network_meteor", target, drift, damage, blast_force)


func spawn_network_shockwave() -> void:
	var mode := _find_mode_with_method(&"spawn_network_shockwave")
	if mode != null:
		mode.call("spawn_network_shockwave")


func spawn_network_shot(origin: Vector3, hit_position: Vector3) -> void:
	var mode := _find_mode_by_id(&"shooter")
	if mode != null and mode.has_method("spawn_network_shot"):
		mode.call("spawn_network_shot", origin, hit_position)


func apply_network_state(
	network_state: int,
	network_round: int,
	network_time_left: float,
	mode_id: String,
	map_id: String,
	round_seed: int,
	feature_ids: PackedStringArray,
	player_profile_id: String,
	spawn_policy_id: String,
	spectator_policy_id: String
) -> void:
	if not network.is_online() or network.is_simulation_host():
		return
	var selected_mode := _find_mode_by_id(StringName(mode_id))
	if selected_mode == null:
		push_warning("Ignoring unknown synchronized mode: %s" % mode_id)
		return
	var compatible_maps: Array[StringName] = map_host.get_compatible_map_ids(
		selected_mode.required_map_tags,
		selected_mode.blocked_map_tags,
		selected_mode.pinned_map_id,
		maxi(1, network.get_player_count())
	)
	if StringName(map_id) not in compatible_maps:
		push_warning(
			"Ignoring incompatible synchronized map %s for mode %s"
			% [map_id, mode_id]
		)
		return
	var plan := _make_plan(
		selected_mode,
		StringName(map_id),
		round_seed,
		feature_ids,
		StringName(player_profile_id),
		StringName(spawn_policy_id),
		StringName(spectator_policy_id)
	)
	var previous_state := state
	var previous_round := round_number
	var mapped_state := _round_state_from_network(network_state)
	if mapped_state < 0:
		return
	state = mapped_state as RoundState
	round_number = maxi(0, network_round)
	_time_left = maxf(0.0, network_time_left)
	_last_clock_second = -1
	match state:
		RoundState.COUNTDOWN:
			_finish_all_modes()
			_active_mode = null
			_upcoming_plan = plan
			_emit_mode_text(selected_mode, true)
		RoundState.ACTIVE:
			if (
				previous_state != RoundState.ACTIVE
				or previous_round != round_number
				or _active_mode != selected_mode
				or _current_plan.get("map_id", &"") != plan.map_id
			):
				_activate_plan(plan)
				round_started.emit(round_number)
			else:
				_emit_mode_text(selected_mode, false)
		RoundState.RESULT:
			_finish_all_modes()
			_active_mode = null
			_current_plan = plan
			state_changed.emit("RONDA TERMINADA", "Calculando clasificación…")
			if previous_state != RoundState.RESULT or previous_round != round_number:
				round_survived.emit(round_number)


func _round_state_from_network(network_state: int) -> int:
	match network_state:
		NET.RoomPhase.COUNTDOWN:
			return RoundState.COUNTDOWN
		NET.RoomPhase.ACTIVE:
			return RoundState.ACTIVE
		NET.RoomPhase.RESULT:
			return RoundState.RESULT
		_:
			push_warning("Ignoring non-gameplay room phase: %d" % network_state)
			return -1


func sync_as_host() -> void:
	_sync_round_state()


func get_registered_mode_ids() -> Array[StringName]:
	var ids: Array[StringName] = []
	for mode in _modes:
		ids.append(mode.mode_id)
	return ids


func get_current_plan() -> Dictionary:
	return _current_plan.duplicate(true)


func get_upcoming_plan() -> Dictionary:
	return _upcoming_plan.duplicate(true)


func _register_mode(mode: Node3D) -> void:
	_modes.append(mode)
	if mode.has_signal("meteor_warning"):
		mode.connect("meteor_warning", meteor_warning.emit)
	if mode.has_signal("meteor_impact"):
		mode.connect("meteor_impact", meteor_impact.emit)
	if mode.has_signal("shockwave_warning"):
		mode.connect("shockwave_warning", shockwave_warning.emit)
	if mode.has_signal("shockwave_started"):
		mode.connect("shockwave_started", shockwave_started.emit)


func _begin_countdown() -> void:
	state = RoundState.COUNTDOWN
	_time_left = countdown_duration
	_last_clock_second = -1
	_finish_all_modes()
	_active_mode = null
	if not network.is_online() or network.is_simulation_host():
		_upcoming_plan = _select_next_plan()
	if not _upcoming_plan.is_empty():
		_emit_mode_text(_find_mode_by_id(_upcoming_plan.mode_id), true)
	_sync_round_state()


func _begin_active_round() -> void:
	state = RoundState.ACTIVE
	round_number += 1
	if _upcoming_plan.is_empty():
		_upcoming_plan = _select_next_plan()
	_activate_plan(_upcoming_plan)
	_upcoming_plan = {}
	_time_left = _active_mode.round_duration
	_last_clock_second = -1
	round_started.emit(round_number)
	_sync_round_state()


func _begin_result() -> void:
	state = RoundState.RESULT
	_time_left = result_duration
	_last_clock_second = -1
	_finish_all_modes()
	_active_mode = null
	state_changed.emit("RONDA TERMINADA", "Ronda %d completada" % round_number)
	round_survived.emit(round_number)
	_sync_round_state()


func _activate_plan(plan: Dictionary) -> void:
	var mode := _find_mode_by_id(StringName(plan.get("mode_id", &"")))
	if mode == null:
		return
	_finish_all_modes()
	_active_mode = mode
	_current_plan = plan.duplicate(true)
	current_mode_id = mode.mode_id
	_last_mode_id = current_mode_id
	mode.configure_experience(_current_plan)
	experience_selected.emit(_current_plan.duplicate(true))
	mode.begin_round(round_number)
	_emit_mode_text(mode, false)


func _select_next_plan() -> Dictionary:
	var mode := _choose_random_mode()
	var map_ids: Array[StringName] = map_host.get_compatible_map_ids(
		mode.required_map_tags,
		mode.blocked_map_tags,
		mode.pinned_map_id,
		maxi(1, network.get_player_count())
	)
	if map_ids.is_empty():
		push_warning("No compatible map for mode %s; using default" % mode.mode_id)
		map_ids = [StringName(map_host.default_map_id)]
	var map_id := _choose_weighted_map(map_ids)
	var round_seed := int(_random.randi() & 0x7fffffff)
	return _make_plan(
		mode,
		map_id,
		round_seed,
		mode.feature_ids,
		mode.player_profile_id,
		mode.spawn_policy_id,
		mode.spectator_policy_id
	)


func _choose_random_mode() -> Node3D:
	var candidates: Array[Node3D] = []
	var total_weight := 0.0
	for mode in _modes:
		if _modes.size() > 1 and mode.mode_id == _last_mode_id:
			continue
		candidates.append(mode)
		total_weight += maxf(0.1, float(mode.selection_weight))
	var roll := _random.randf_range(0.0, total_weight)
	for mode in candidates:
		roll -= maxf(0.1, float(mode.selection_weight))
		if roll <= 0.0:
			return mode
	return candidates.back()


func _choose_weighted_map(map_ids: Array[StringName]) -> StringName:
	var total_weight := 0.0
	for map_id in map_ids:
		total_weight += map_host.get_map_weight(map_id)
	var roll := _random.randf_range(0.0, total_weight)
	for map_id in map_ids:
		roll -= map_host.get_map_weight(map_id)
		if roll <= 0.0:
			return map_id
	return map_ids.back()


func _make_plan(
	mode: Node3D,
	map_id: StringName,
	round_seed: int,
	feature_ids: PackedStringArray,
	player_profile_id: StringName,
	spawn_policy_id: StringName,
	spectator_policy_id: StringName
) -> Dictionary:
	return {
		"mode_id": mode.mode_id,
		"map_id": map_id,
		"round_seed": maxi(0, round_seed),
		"category": int(mode.category),
		"feature_ids": feature_ids,
		"player_profile_id": player_profile_id,
		"spawn_policy_id": spawn_policy_id,
		"spectator_policy_id": spectator_policy_id,
	}


func _finish_all_modes() -> void:
	for mode in _modes:
		mode.finish_round()
	experience_ended.emit()


func _emit_mode_text(mode: Node3D, upcoming: bool) -> void:
	if mode == null:
		return
	if upcoming:
		state_changed.emit(mode.upcoming_title, mode.upcoming_detail)
	else:
		state_changed.emit(mode.active_title, mode.active_detail)


func _sync_round_state() -> void:
	if not network.is_simulation_host():
		return
	var plan := _upcoming_plan if state == RoundState.COUNTDOWN else _current_plan
	if plan.is_empty():
		return
	network.broadcast_round_state(
		state,
		round_number,
		_time_left,
		str(plan.mode_id),
		str(plan.map_id),
		int(plan.round_seed),
		plan.feature_ids,
		str(plan.player_profile_id),
		str(plan.spawn_policy_id),
		str(plan.spectator_policy_id)
	)


func _find_mode_by_id(mode_id: StringName) -> Node3D:
	for mode in _modes:
		if mode.mode_id == mode_id:
			return mode
	return null


func _find_mode_with_method(method_name: StringName) -> Node3D:
	for mode in _modes:
		if mode.has_method(method_name):
			return mode
	return null
