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
var event_host: LocalEventHost
var player: LocalBaseCharacter
var playable_area: LocalPlayableArea
var _generation := 0


func configure(
	definition: MinigameMapDefinition,
	map_host_value: LocalMapHost,
	event_host_value: LocalEventHost,
	player_value: LocalBaseCharacter,
	playable_area_value: LocalPlayableArea
) -> void:
	map_definition = definition
	map_host = map_host_value
	event_host = event_host_value
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
	if event_host != null:
		event_host.stop_and_clean()
	if map_host != null:
		map_host.unmount_map()
	if player != null:
		player.controls_enabled = true
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
	if not await _wait_phase(0.4, generation):
		return
	_transition(Phase.RULES, 1.4)
	if not await _wait_phase(1.4, generation):
		return
	_transition(Phase.COUNTDOWN, 3.0)
	if not await _wait_phase(3.0, generation):
		return
	player.controls_enabled = true
	_transition(Phase.ACTIVE, 7.0)
	event_host.start_reference_event(round_seed, map_definition.event_points)
	if not await _wait_phase(7.0, generation):
		return
	player.controls_enabled = false
	_transition(Phase.RESULT, 1.5)
	if not await _wait_phase(1.5, generation):
		return
	_transition(Phase.CLEANUP, 0.2)
	event_host.stop_and_clean()
	map_host.unmount_map()
	playable_area.set_physical_walls_enabled(false)
	player.set_spawn_transform(Transform3D(Basis.IDENTITY, Vector3(0.0, 0.02, 8.0)))
	if not await _wait_phase(0.2, generation):
		return
	player.controls_enabled = true
	_transition(Phase.IDLE, 0.0)
	round_completed.emit(round_seed)


func _wait_phase(seconds: float, generation: int) -> bool:
	await get_tree().create_timer(seconds * duration_multiplier).timeout
	return generation == _generation


func _transition(next_phase: Phase, seconds: float) -> void:
	phase = next_phase
	phase_changed.emit(phase, get_phase_name(), seconds * duration_multiplier)
