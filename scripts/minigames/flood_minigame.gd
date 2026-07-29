class_name FloodMinigame
extends "res://scripts/minigames/minigame_mode.gd"

const FLOOD_SCENE := preload("res://scenes/components/flood_hazard.tscn")

var _flood: Node3D


func _ready() -> void:
	mode_id = &"flood"
	round_duration = 36.0
	upcoming_title = "PRÓXIMO: INUNDACIÓN"
	upcoming_detail = "Prepárate para buscar las zonas más altas"
	active_title = "INUNDACIÓN ASCENDENTE"
	active_detail = "¡Sube antes de que el agua te alcance!"
	_flood = FLOOD_SCENE.instantiate()
	add_child(_flood)


func begin_round(_round_number: int) -> void:
	_flood.stop()


func tick_round(
	_delta: float,
	time_left: float,
	_intensity: float,
	_authoritative: bool
) -> void:
	_flood.sync_active(time_left, round_duration)


func finish_round() -> void:
	_flood.stop()
