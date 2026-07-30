class_name ShockwaveMinigame
extends "res://scripts/minigames/minigame_mode.gd"

signal shockwave_warning
signal shockwave_started

const SHOCKWAVE_SCENE := preload("res://scenes/components/shockwave_ring.tscn")
const DIFFICULTY := preload("res://shared/difficulty_rules.gd")

@onready var network: Variant = get_node("/root/Network")

var _shockwave: ShockwaveRing
var _spawn_cooldown := 0.0
var _difficulty := DIFFICULTY.Level.NORMAL


func _ready() -> void:
	mode_id = &"shockwave"
	round_duration = 34.0
	upcoming_title = "PRÓXIMO: PULSO SÍSMICO"
	upcoming_detail = "Sube al centro o salta por encima del anillo"
	active_title = "PULSO SÍSMICO"
	active_detail = "¡Salta el anillo celeste o busca altura!"
	required_map_tags = PackedStringArray(["common", "elevation"])
	_shockwave = SHOCKWAVE_SCENE.instantiate()
	add_child(_shockwave)
	_shockwave.warning_started.connect(shockwave_warning.emit)
	_shockwave.wave_started.connect(shockwave_started.emit)


func begin_round(_round_number: int) -> void:
	_difficulty = DIFFICULTY.from_round_seed(
		int(experience_plan.get("round_seed", 0))
	)
	_spawn_cooldown = 0.25


func tick_round(
	delta: float,
	_time_left: float,
	intensity: float,
	authoritative: bool
) -> void:
	if not authoritative:
		return
	_spawn_cooldown -= delta
	if _spawn_cooldown > 0.0:
		return
	var start_cooldown := 4.4
	var end_cooldown := 3.25
	if _difficulty == DIFFICULTY.Level.EASY:
		start_cooldown = 5.0
		end_cooldown = 4.0
	elif _difficulty == DIFFICULTY.Level.HARD:
		start_cooldown = 3.0
		end_cooldown = 2.15
	_spawn_cooldown = lerpf(start_cooldown, end_cooldown, intensity)
	if not _shockwave.is_available():
		return
	if network.is_online():
		network.broadcast_shockwave()
	else:
		spawn_network_shockwave()


func finish_round() -> void:
	_shockwave.reset_ring()


func spawn_network_shockwave() -> void:
	if _shockwave.is_available():
		match _difficulty:
			DIFFICULTY.Level.EASY:
				_shockwave.launch(0.58, 15, 7.2, 10.5)
			DIFFICULTY.Level.HARD:
				_shockwave.launch(0.28, 26, 11.8, 17.0)
			_:
				_shockwave.launch(0.42, 20, 9.2, 13.5)
