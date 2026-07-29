class_name DisasterController
extends Node3D

signal state_changed(title: String, detail: String)
signal clock_changed(seconds_left: int)
signal round_survived(round_number: int)
signal round_started(round_number: int)
signal mode_selected(mode_id: StringName, map_scene: PackedScene)
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

var state := RoundState.COUNTDOWN
var round_number := 0
var current_mode_id: StringName = &""
var _time_left := 0.0
var _last_clock_second := -1
var _network_sync_elapsed := 0.0
var _modes: Array[Node3D] = []
var _active_mode: Node3D


func _ready() -> void:
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


func apply_network_state(
	network_state: int,
	network_round: int,
	network_time_left: float
) -> void:
	if not network.is_online() or network.is_simulation_host():
		return
	var previous_state := state
	var previous_round := round_number
	state = clampi(network_state, RoundState.COUNTDOWN, RoundState.RESULT) as RoundState
	round_number = maxi(0, network_round)
	_time_left = maxf(0.0, network_time_left)
	_last_clock_second = -1
	match state:
		RoundState.COUNTDOWN:
			_finish_all_modes()
			_active_mode = null
			_emit_mode_text(_mode_for_round(round_number + 1), true)
		RoundState.ACTIVE:
			var selected_mode := _mode_for_round(maxi(1, round_number))
			if (
				previous_state != RoundState.ACTIVE
				or previous_round != round_number
				or _active_mode != selected_mode
			):
				_activate_mode(selected_mode)
				round_started.emit(round_number)
			else:
				_emit_mode_text(selected_mode, false)
		RoundState.RESULT:
			_finish_all_modes()
			_active_mode = null
			state_changed.emit("¡SOBREVIVISTE!", "Ronda %d completada" % round_number)
			if previous_state != RoundState.RESULT or previous_round != round_number:
				round_survived.emit(round_number)


func sync_as_host() -> void:
	_sync_round_state()


func get_registered_mode_ids() -> Array[StringName]:
	var ids: Array[StringName] = []
	for mode in _modes:
		ids.append(mode.mode_id)
	return ids


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
	_emit_mode_text(_mode_for_round(round_number + 1), true)
	_sync_round_state()


func _begin_active_round() -> void:
	state = RoundState.ACTIVE
	round_number += 1
	_activate_mode(_mode_for_round(round_number))
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
	state_changed.emit("¡SOBREVIVISTE!", "Ronda %d completada" % round_number)
	round_survived.emit(round_number)
	_sync_round_state()


func _activate_mode(mode: Node3D) -> void:
	_finish_all_modes()
	_active_mode = mode
	current_mode_id = mode.mode_id
	mode.begin_round(round_number)
	mode_selected.emit(mode.mode_id, mode.map_scene)
	_emit_mode_text(mode, false)


func _finish_all_modes() -> void:
	for mode in _modes:
		mode.finish_round()


func _mode_for_round(number: int) -> Node3D:
	return _modes[(maxi(1, number) - 1) % _modes.size()]


func _emit_mode_text(mode: Node3D, upcoming: bool) -> void:
	if upcoming:
		state_changed.emit(mode.upcoming_title, mode.upcoming_detail)
	else:
		state_changed.emit(mode.active_title, mode.active_detail)


func _sync_round_state() -> void:
	if network.is_simulation_host():
		network.broadcast_round_state(state, round_number, _time_left)


func _find_mode_with_method(method_name: StringName) -> Node3D:
	for mode in _modes:
		if mode.has_method(method_name):
			return mode
	return null
