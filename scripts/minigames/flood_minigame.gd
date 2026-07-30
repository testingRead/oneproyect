class_name FloodMinigame
extends "res://scripts/minigames/minigame_mode.gd"

const FLOOD_SCENE := preload("res://scenes/components/flood_hazard.tscn")
const DIFFICULTY := preload("res://shared/difficulty_rules.gd")

var _flood: Node3D


func _ready() -> void:
	mode_id = &"flood"
	round_duration = 36.0
	upcoming_title = "PRÓXIMO: INUNDACIÓN"
	upcoming_detail = "Prepárate para buscar las zonas más altas"
	active_title = "INUNDACIÓN ASCENDENTE"
	active_detail = "¡Sube antes de que el agua te alcance!"
	required_map_tags = PackedStringArray(["common", "elevation"])
	_flood = FLOOD_SCENE.instantiate()
	add_child(_flood)


func begin_round(_round_number: int) -> void:
	_flood.stop()
	_flood.configure_difficulty(
		DIFFICULTY.from_round_seed(int(experience_plan.get("round_seed", 0)))
	)


func tick_round(
	_delta: float,
	time_left: float,
	_intensity: float,
	_authoritative: bool
) -> void:
	_flood.sync_active(time_left, round_duration)


func finish_round() -> void:
	_flood.stop()
