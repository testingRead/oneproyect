class_name LocalRoundController
extends Node

signal phase_changed(phase: Phase, label: String, seconds: float)
signal round_completed(seed: int)

enum Phase {
	IDLE,
	PREPARE,
	RULES,
	COUNTDOWN,
	ACTIVE,
	RESULT,
	CLEANUP,
}

@export_range(0.05, 2.0, 0.05) var duration_multiplier := 1.0

var phase := Phase.IDLE
var round_seed := 0
var map_definition: MinigameMapDefinition
var map_host: LocalMapHost
var football_host
var crown_host
var bomb_host
var player: LocalBaseCharacter
var playable_area: LocalPlayableArea
var minigame_id: StringName = &"futbol_rebote"
var _generation := 0


func configure(
	definition: MinigameMapDefinition,
	map_host_value: LocalMapHost,
	football_host_value,
	crown_host_value,
	bomb_host_value,
	minigame_id_value: StringName,
	player_value: LocalBaseCharacter,
	playable_area_value: LocalPlayableArea
) -> void:
	map_definition = definition
	map_host = map_host_value
	football_host = football_host_value
	crown_host = crown_host_value
	bomb_host = bomb_host_value
	minigame_id = minigame_id_value
	player = player_value
	playable_area = playable_area_value


func start_round(seed: int) -> bool:
	if phase != Phase.IDLE or map_definition == null:
		return false
	_generation += 1
	round_seed = seed
	_run_round(_generation)
	return true


func stop_and_clean() -> void:
	_generation += 1
	if football_host != null:
		football_host.stop_and_clean()
	if crown_host != null:
		crown_host.stop_and_clean()
	if bomb_host != null:
		bomb_host.stop_and_clean()
	if map_host != null:
		map_host.unmount_map()
	if player != null:
		player.controls_enabled = true
		player.set_first_person(false)
		player.reset_to_spawn()
	_transition(Phase.IDLE, 0.0)


func get_phase_name() -> String:
	return Phase.keys()[phase]


func _run_round(generation: int) -> void:
	_transition(Phase.PREPARE, 0.4)
	map_host.mount_map(map_definition, round_seed)
	playable_area.set_area_index(map_definition.playable_area_index)
	playable_area.set_physical_walls_enabled(
		map_definition.boundary_policy
		== MinigameMapDefinition.BoundaryPolicy.PHYSICAL_AREA
	)
	player.controls_enabled = false
	player.set_spawn_transform(map_host.get_spawn_transform(0))
	player.set_facing_direction(Vector3(0.0, 0.0, -1.0))
	player.set_first_person(true)
	if not await _wait_phase(0.4, generation):
		return
	_transition(Phase.RULES, 1.4)
	if not await _wait_phase(1.4, generation):
		return
	_transition(Phase.COUNTDOWN, 3.0)
	if not await _wait_phase(3.0, generation):
		return
	player.controls_enabled = true
	var active_duration := 75.0 if minigame_id == &"futbol_rebote" else 45.0
	if minigame_id == &"bomba_relevo":
		active_duration = 24.0
	_transition(Phase.ACTIVE, active_duration)
	var mounted_map := map_host.get_node_or_null("MountedMap") as Node3D
	var started := false
	if minigame_id == &"futbol_rebote":
		started = football_host.start_match(mounted_map, duration_multiplier, player)
	elif minigame_id == &"corona_central":
		started = crown_host.start_match(mounted_map, player)
	elif minigame_id == &"bomba_relevo":
		started = bomb_host.start_match(mounted_map, player)
	if not started:
		stop_and_clean()
		return
	if not await _wait_active(active_duration, generation):
		return
	player.controls_enabled = false
	if minigame_id == &"futbol_rebote" and football_host.is_tied():
		await football_host.run_penalty_shootout()
		if generation != _generation:
			return
	if minigame_id == &"futbol_rebote":
		football_host.finish_match()
	elif minigame_id == &"corona_central":
		crown_host.finish_match()
	_transition(Phase.RESULT, 1.5)
	if not await _wait_phase(1.5, generation):
		return
	_transition(Phase.CLEANUP, 0.2)
	football_host.stop_and_clean()
	crown_host.stop_and_clean()
	bomb_host.stop_and_clean()
	map_host.unmount_map()
	playable_area.set_physical_walls_enabled(false)
	player.set_first_person(false)
	player.set_spawn_transform(Transform3D(Basis.IDENTITY, Vector3(0.0, 0.02, 8.0)))
	if not await _wait_phase(0.2, generation):
		return
	player.controls_enabled = true
	_transition(Phase.IDLE, 0.0)
	round_completed.emit(round_seed)


func _wait_phase(seconds: float, generation: int) -> bool:
	await get_tree().create_timer(seconds * duration_multiplier).timeout
	return generation == _generation


func _wait_active(seconds: float, generation: int) -> bool:
	var deadline := (
		Time.get_ticks_msec()
		+ int(seconds * duration_multiplier * 1000.0)
	)
	while generation == _generation and Time.get_ticks_msec() < deadline:
		if minigame_id == &"futbol_rebote" and football_host != null and football_host.is_complete():
			return true
		if minigame_id == &"bomba_relevo" and bomb_host != null and bomb_host.is_complete():
			return true
		await get_tree().physics_frame
	return generation == _generation


func _transition(next_phase: Phase, seconds: float) -> void:
	phase = next_phase
	phase_changed.emit(phase, get_phase_name(), seconds * duration_multiplier)
