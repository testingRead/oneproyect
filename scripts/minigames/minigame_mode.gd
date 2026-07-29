class_name MinigameMode
extends Node3D

@export var mode_id: StringName = &"minigame"
@export var round_duration := 30.0
@export var upcoming_title := "PRÓXIMO MINIJUEGO"
@export_multiline var upcoming_detail := "Prepárate"
@export var active_title := "MINIJUEGO"
@export_multiline var active_detail := "¡Sobrevive!"
@export var map_scene: PackedScene


func begin_round(_round_number: int) -> void:
	pass


func tick_round(
	_delta: float,
	_time_left: float,
	_intensity: float,
	_authoritative: bool
) -> void:
	pass


func finish_round() -> void:
	pass


func reset_mode() -> void:
	finish_round()
