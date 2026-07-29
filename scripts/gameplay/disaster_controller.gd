class_name DisasterController
extends Node3D

signal state_changed(title: String, detail: String)
signal clock_changed(seconds_left: int)
signal round_survived(round_number: int)
signal meteor_warning
signal meteor_impact
signal shockwave_warning
signal shockwave_started

enum RoundState {
	COUNTDOWN,
	ACTIVE,
	RESULT,
}

enum DisasterMode {
	METEORS,
	SHOCKWAVES,
}

const METEOR_SCENE := preload("res://scenes/components/meteor.tscn")
const SHOCKWAVE_SCENE := preload("res://scenes/components/shockwave_ring.tscn")
const POOL_SIZE := 8

@export var active_duration := 42.0
@export var countdown_duration := 5.0
@export var result_duration := 6.0
@export var arena_half_extent := 10.8

@onready var network: Variant = get_node("/root/Network")

var state := RoundState.COUNTDOWN
var round_number := 0
var current_mode := DisasterMode.METEORS
var _time_left := 0.0
var _spawn_cooldown := 0.0
var _last_clock_second := -1
var _network_sync_elapsed := 0.0
var _pool: Array[MeteorSlot] = []
var _shockwave: ShockwaveRing
var _random := RandomNumberGenerator.new()


func _ready() -> void:
	_random.seed = 20260729
	for index in POOL_SIZE:
		var meteor: MeteorSlot = METEOR_SCENE.instantiate()
		meteor.name = "Meteor%02d" % index
		add_child(meteor)
		meteor.warning_started.connect(_on_meteor_warning)
		meteor.impacted.connect(_on_meteor_impact)
		_pool.append(meteor)
	_shockwave = SHOCKWAVE_SCENE.instantiate()
	add_child(_shockwave)
	_shockwave.warning_started.connect(shockwave_warning.emit)
	_shockwave.wave_started.connect(shockwave_started.emit)
	_begin_countdown()


func _physics_process(delta: float) -> void:
	_time_left -= delta
	var displayed_second := maxi(0, ceili(_time_left))
	if displayed_second != _last_clock_second:
		_last_clock_second = displayed_second
		clock_changed.emit(displayed_second)

	if network.is_online() and not network.is_simulation_host():
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
			_spawn_cooldown -= delta
			if _spawn_cooldown <= 0.0:
				if current_mode == DisasterMode.METEORS:
					_spawn_meteor()
				else:
					_spawn_shockwave()
				var intensity: float = 1.0 - clampf(_time_left / active_duration, 0.0, 1.0)
				if current_mode == DisasterMode.METEORS:
					_spawn_cooldown = lerpf(1.45, 0.72, intensity)
				else:
					_spawn_cooldown = lerpf(4.5, 3.25, intensity)
			if _time_left <= 0.0:
				_begin_result()
		RoundState.RESULT:
			if _time_left <= 0.0:
				_begin_countdown()


func restart_cycle() -> void:
	for meteor in _pool:
		meteor.reset_slot()
	_shockwave.reset_ring()
	round_number = 0
	_begin_countdown()


func _begin_countdown() -> void:
	state = RoundState.COUNTDOWN
	_time_left = countdown_duration
	_last_clock_second = -1
	var next_mode := _mode_for_round(round_number + 1)
	if next_mode == DisasterMode.METEORS:
		state_changed.emit("PRÓXIMO: METEORITOS", "Busca refugio y mira las marcas del suelo")
	else:
		state_changed.emit("PRÓXIMO: PULSO SÍSMICO", "Sube al centro o salta por encima del anillo")
	_sync_round_state()


func _begin_active_round() -> void:
	state = RoundState.ACTIVE
	round_number += 1
	current_mode = _mode_for_round(round_number)
	_time_left = active_duration if current_mode == DisasterMode.METEORS else 34.0
	_spawn_cooldown = 0.25
	_last_clock_second = -1
	if current_mode == DisasterMode.METEORS:
		state_changed.emit("LLUVIA DE METEORITOS", "¡Usa los refugios y sobrevive!")
	else:
		state_changed.emit("PULSO SÍSMICO", "¡Salta el anillo celeste o busca altura!")
	_sync_round_state()


func _begin_result() -> void:
	state = RoundState.RESULT
	_time_left = result_duration
	_last_clock_second = -1
	for meteor in _pool:
		meteor.reset_slot()
	_shockwave.reset_ring()
	state_changed.emit("¡SOBREVIVISTE!", "Ronda %d completada" % round_number)
	round_survived.emit(round_number)
	_sync_round_state()


func _spawn_meteor() -> void:
	if network.is_online() and not network.is_simulation_host():
		return
	var target := Vector3(
		_random.randf_range(-arena_half_extent, arena_half_extent),
		0.06,
		_random.randf_range(-arena_half_extent, arena_half_extent)
	)
	var drift := Vector2(_random.randf_range(-1.1, 1.1), _random.randf_range(-1.1, 1.1))
	if network.is_online():
		network.broadcast_meteor(target, drift, 22, 10.5)
	else:
		spawn_network_meteor(target, drift, 22, 10.5)


func spawn_network_meteor(target: Vector3, drift: Vector2, damage: int, blast_force: float) -> void:
	var meteor := _find_available_meteor()
	if meteor == null:
		return
	meteor.launch(target, drift, 0.92, damage, blast_force)


func _spawn_shockwave() -> void:
	if not _shockwave.is_available():
		return
	if network.is_online():
		network.broadcast_shockwave()
	else:
		spawn_network_shockwave()


func spawn_network_shockwave() -> void:
	_shockwave.launch()


func apply_network_state(network_state: int, network_round: int, network_time_left: float) -> void:
	if not network.is_online() or network.is_simulation_host():
		return
	state = clampi(network_state, RoundState.COUNTDOWN, RoundState.RESULT) as RoundState
	round_number = maxi(0, network_round)
	current_mode = _mode_for_round(maxi(1, round_number))
	_time_left = maxf(0.0, network_time_left)
	_last_clock_second = -1
	match state:
		RoundState.COUNTDOWN:
			var next_mode := _mode_for_round(round_number + 1)
			if next_mode == DisasterMode.METEORS:
				state_changed.emit("PRÓXIMO: METEORITOS", "Busca refugio y mira las marcas del suelo")
			else:
				state_changed.emit("PRÓXIMO: PULSO SÍSMICO", "Sube al centro o salta por encima del anillo")
		RoundState.ACTIVE:
			if current_mode == DisasterMode.METEORS:
				state_changed.emit("LLUVIA DE METEORITOS", "¡Usa los refugios y sobrevive!")
			else:
				state_changed.emit("PULSO SÍSMICO", "¡Salta el anillo celeste o busca altura!")
		RoundState.RESULT:
			for meteor in _pool:
				meteor.reset_slot()
			_shockwave.reset_ring()
			state_changed.emit("¡SOBREVIVISTE!", "Ronda %d completada" % round_number)


func sync_as_host() -> void:
	_sync_round_state()


func _sync_round_state() -> void:
	if network.is_simulation_host():
		network.broadcast_round_state(state, round_number, _time_left)


func _mode_for_round(number: int) -> DisasterMode:
	return DisasterMode.METEORS if number % 2 == 1 else DisasterMode.SHOCKWAVES


func _find_available_meteor() -> MeteorSlot:
	for meteor in _pool:
		if meteor.is_available():
			return meteor
	return null


func _on_meteor_warning() -> void:
	meteor_warning.emit()


func _on_meteor_impact() -> void:
	meteor_impact.emit()
