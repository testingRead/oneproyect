class_name MinigameMode
extends Node3D

enum ModeCategory {
	COMMON,
	CUSTOM,
	UNIQUE,
}

@export var mode_id: StringName = &"minigame"
@export var category := ModeCategory.COMMON
@export_range(0.1, 10.0, 0.1) var selection_weight := 1.0
@export var round_duration := 30.0
@export var upcoming_title := "PRÓXIMO MINIJUEGO"
@export_multiline var upcoming_detail := "Prepárate"
@export var active_title := "MINIJUEGO"
@export_multiline var active_detail := "¡Sobrevive!"
@export var required_map_tags := PackedStringArray(["common"])
@export var blocked_map_tags := PackedStringArray()
@export var pinned_map_id: StringName = &""
@export var feature_ids := PackedStringArray()
@export var player_profile_id: StringName = &"default"
@export var spawn_policy_id: StringName = &"spread"
@export var spectator_policy_id: StringName = &"overhead"

var experience_plan: Dictionary = {}


func configure_experience(plan: Dictionary) -> void:
	experience_plan = plan.duplicate(true)


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
