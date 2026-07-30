class_name MeteorMinigame
extends "res://scripts/minigames/minigame_mode.gd"

signal meteor_warning
signal meteor_impact

const METEOR_SCENE := preload("res://scenes/components/meteor.tscn")
const DIFFICULTY := preload("res://shared/difficulty_rules.gd")

@export var pool_size := 8

@onready var network: Variant = get_node("/root/Network")
@onready var map_host: Node3D = $"../../ModeMapHost"

var _pool: Array[MeteorSlot] = []
var _spawn_cooldown := 0.0
var _random := RandomNumberGenerator.new()
var _difficulty := DIFFICULTY.Level.NORMAL
var _playable_bounds := Rect2(Vector2(-23.2, -23.2), Vector2(46.4, 46.4))


func _ready() -> void:
	mode_id = &"meteors"
	round_duration = 42.0
	upcoming_title = "PRÓXIMO: METEORITOS"
	upcoming_detail = "Busca refugio y mira las marcas del suelo"
	active_title = "LLUVIA DE METEORITOS"
	active_detail = "¡Usa los refugios y sobrevive!"
	required_map_tags = PackedStringArray(["common", "survival", "open_sky"])
	_random.seed = 20260729
	for index in pool_size:
		var meteor: MeteorSlot = METEOR_SCENE.instantiate()
		meteor.name = "Meteor%02d" % index
		add_child(meteor)
		meteor.warning_started.connect(meteor_warning.emit)
		meteor.impacted.connect(meteor_impact.emit)
		_pool.append(meteor)


func begin_round(_round_number: int) -> void:
	_difficulty = DIFFICULTY.from_round_seed(
		int(experience_plan.get("round_seed", 0))
	)
	_playable_bounds = map_host.get_active_playable_bounds(1.4)
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
	var difficulty_scale := DIFFICULTY.intensity(_difficulty)
	_spawn_cooldown = lerpf(1.45, 0.72, intensity) / difficulty_scale
	var target := Vector3(
		_random.randf_range(
			_playable_bounds.position.x,
			_playable_bounds.end.x
		),
		0.06,
		_random.randf_range(
			_playable_bounds.position.y,
			_playable_bounds.end.y
		)
	)
	var drift := Vector2(
		_random.randf_range(-1.1, 1.1),
		_random.randf_range(-1.1, 1.1)
	) * difficulty_scale
	var damage := roundi(22.0 * difficulty_scale)
	var force := 10.5 * difficulty_scale
	if network.is_online():
		network.broadcast_meteor(target, drift, damage, force)
	else:
		spawn_network_meteor(target, drift, damage, force)


func finish_round() -> void:
	for meteor in _pool:
		meteor.reset_slot()


func spawn_network_meteor(
	target: Vector3,
	drift: Vector2,
	damage: int,
	blast_force: float
) -> void:
	var meteor := _find_available_meteor()
	if meteor != null:
		meteor.launch(target, drift, 0.92, damage, blast_force)


func _find_available_meteor() -> MeteorSlot:
	for meteor in _pool:
		if meteor.is_available():
			return meteor
	return null
