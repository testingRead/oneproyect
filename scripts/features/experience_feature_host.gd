class_name ExperienceFeatureHost
extends Node

@export var player_path: NodePath
@export var world_path: NodePath
@export var hud_path: NodePath

var _features: Dictionary = {}
var _active_features: Dictionary = {}


func _ready() -> void:
	for child in get_children():
		if child.has_method("activate") and child.has_method("deactivate"):
			register_feature(child)


func register_feature(feature: Node) -> void:
	var feature_id := StringName(feature.get("feature_id"))
	if feature_id.is_empty():
		push_warning("Ignoring gameplay feature without feature_id")
		return
	if feature.get_parent() != self:
		add_child(feature)
	_features[feature_id] = feature


func apply_experience(plan: Dictionary) -> void:
	var requested_ids := PackedStringArray(plan.get("feature_ids", PackedStringArray()))
	for feature_id: StringName in _active_features.keys():
		if str(feature_id) not in requested_ids:
			_deactivate_feature(feature_id)
	var context := {
		"plan": plan.duplicate(true),
		"player": get_node_or_null(player_path),
		"world": get_node_or_null(world_path),
		"hud": get_node_or_null(hud_path),
	}
	for requested_id in requested_ids:
		var feature_id := StringName(requested_id)
		if _active_features.has(feature_id):
			continue
		var feature: Node = _features.get(feature_id)
		if feature == null:
			push_warning("Experience requested unknown feature: %s" % feature_id)
			continue
		feature.call("activate", context)
		_active_features[feature_id] = feature


func clear_experience() -> void:
	for feature_id: StringName in _active_features.keys():
		_deactivate_feature(feature_id)


func get_active_feature_ids() -> Array[StringName]:
	var ids: Array[StringName] = []
	for feature_id: StringName in _active_features:
		ids.append(feature_id)
	return ids


func _deactivate_feature(feature_id: StringName) -> void:
	var feature: Node = _active_features.get(feature_id)
	if feature != null:
		feature.call("deactivate")
	_active_features.erase(feature_id)
