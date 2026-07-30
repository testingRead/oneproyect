class_name FloodHazard
extends Node3D

const START_HEIGHT := -0.38
const END_HEIGHT := 1.58
const DIFFICULTY := preload("res://shared/difficulty_rules.gd")

@onready var water: MeshInstance3D = $Water

var _active := false
var _damage_cooldown := 0.0
var _damage := 12
var _lift := 3.2
var _height_scale := 1.0


func _ready() -> void:
	visible = false
	position.y = START_HEIGHT
	configure_bounds(Rect2(Vector2(-25.7, -25.7), Vector2(51.4, 51.4)))


func configure_bounds(bounds: Rect2) -> void:
	var center := bounds.get_center()
	position.x = center.x
	position.z = center.y
	water.scale = Vector3(
		maxf(1.0, bounds.size.x),
		1.0,
		maxf(1.0, bounds.size.y)
	)


func _physics_process(delta: float) -> void:
	if not _active:
		return
	_damage_cooldown = maxf(0.0, _damage_cooldown - delta)
	if _damage_cooldown > 0.0:
		return
	for node in get_tree().get_nodes_in_group("players"):
		var player := node as GrayboxPlayer
		if player != null and player.global_position.y < global_position.y + 0.82:
			player.apply_hazard_damage(_damage, _lift)
			_damage_cooldown = 0.72 if _damage >= 15 else 0.9


func sync_active(time_left: float, duration: float) -> void:
	_active = true
	visible = true
	var progress := 1.0 - clampf(time_left / duration, 0.0, 1.0)
	position.y = lerpf(
		START_HEIGHT,
		lerpf(START_HEIGHT, END_HEIGHT, _height_scale),
		pow(progress, 1.15)
	)


func configure_difficulty(level: int) -> void:
	_damage = 9 if level == DIFFICULTY.Level.EASY else (
		16 if level == DIFFICULTY.Level.HARD else 12
	)
	_lift = 2.6 if level == DIFFICULTY.Level.EASY else (
		4.0 if level == DIFFICULTY.Level.HARD else 3.2
	)
	_height_scale = 0.84 if level == DIFFICULTY.Level.EASY else (
		1.16 if level == DIFFICULTY.Level.HARD else 1.0
	)


func stop() -> void:
	_active = false
	visible = false
	_damage_cooldown = 0.0
	position.y = START_HEIGHT


func is_active() -> bool:
	return _active
