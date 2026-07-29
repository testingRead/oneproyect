class_name GameplayFeature
extends Node

@export var feature_id: StringName = &"feature"
@export var required_capabilities := PackedStringArray()
@export var provided_capabilities := PackedStringArray()

var feature_context: Dictionary = {}


func activate(context: Dictionary) -> void:
	feature_context = context


func deactivate() -> void:
	feature_context.clear()
