class_name ModularAvatar
extends Node3D

const CATALOG := preload("res://scripts/characters/character_catalog.gd")
const AVATAR_SCENES := [
	preload("res://assets/models/avatars/human_male.glb"),
	preload("res://assets/models/avatars/human_female.glb"),
	preload("res://assets/models/avatars/lynx_male.glb"),
	preload("res://assets/models/avatars/lynx_female.glb"),
]
const LOOPING_ANIMATIONS := [&"Idle", &"Walk"]
const ALL_BODY_PARTS_MASK := 0b111111111111
const BONE_MASKS := {
	"head": 1 << 0,
	"upper_arm.L": 1 << 1,
	"forearm.L": 1 << 1,
	"hand.L": 1 << 3,
	"upper_arm.R": 1 << 2,
	"forearm.R": 1 << 2,
	"hand.R": 1 << 4,
	"thigh.L": 1 << 5,
	"shin.L": 1 << 5,
	"foot.L": 1 << 5,
	"thigh.R": 1 << 6,
	"shin.R": 1 << 6,
	"foot.R": 1 << 6,
	"tail.01": 1 << 11,
	"tail.02": 1 << 11,
	"tail.03": 1 << 11,
	"ear.L": 1 << 9,
	"ear.R": 1 << 10,
}

var _model: Node3D
var _models_by_archetype: Dictionary = {}
var _animation_player: AnimationPlayer
var _skeleton: Skeleton3D
var _variant_index := -1
var _limb_mask := ALL_BODY_PARTS_MASK
var _motion_state: StringName = &""
var _one_shot_locked := false


func configure(variant_index: int) -> void:
	var safe_index := CATALOG.sanitize_index(variant_index)
	var archetype_index: int = CATALOG.ARCHETYPES[safe_index]
	if archetype_index < 0:
		if _model != null:
			_model.visible = false
		_variant_index = safe_index
		visible = false
		return
	visible = true
	if _model == null or _variant_index < 0 or CATALOG.ARCHETYPES[_variant_index] != archetype_index:
		_replace_model(archetype_index)
	_variant_index = safe_index
	_apply_palette()
	set_limb_mask(_limb_mask)


func update_motion(
	speed: float,
	on_floor: bool,
	push_weight: float,
	aim_weight: float,
	shoot_weight: float,
	reload_weight: float,
	crouched := false
) -> void:
	if _animation_player == null:
		return
	var next_state: StringName = &"Idle"
	if push_weight > 0.08:
		next_state = &"Push"
	elif shoot_weight > 0.08 or aim_weight > 0.55 or reload_weight > 0.3:
		next_state = &"Shoot"
	elif crouched:
		next_state = &"Crouch"
	elif on_floor and speed > 0.18:
		next_state = &"Walk"
	if next_state in [&"Push", &"Shoot"]:
		if _motion_state != next_state:
			_play(next_state, 0.08)
			_one_shot_locked = true
		return
	if _one_shot_locked and _animation_player.is_playing():
		return
	_one_shot_locked = false
	if _motion_state != next_state or not _animation_player.is_playing():
		_play(next_state, 0.16)
	if next_state == &"Walk":
		_animation_player.speed_scale = clampf(speed / 4.5, 0.65, 1.5)
	else:
		_animation_player.speed_scale = 1.0


func set_limb_mask(mask: int) -> void:
	_limb_mask = mask & ALL_BODY_PARTS_MASK
	if _skeleton == null:
		return
	for bone_name: String in BONE_MASKS:
		var bone_index := _skeleton.find_bone(bone_name)
		if bone_index < 0:
			continue
		var attached := (_limb_mask & int(BONE_MASKS[bone_name])) != 0
		_skeleton.set_bone_pose_scale(
			bone_index,
			Vector3.ONE if attached else Vector3(0.001, 0.001, 0.001)
		)


func set_shadow_quality(enabled: bool) -> void:
	if _model == null:
		return
	var mode := (
		GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		if enabled
		else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	)
	for mesh: Node in _model.find_children("*", "MeshInstance3D", true, false):
		(mesh as GeometryInstance3D).cast_shadow = mode


func get_archetype_index() -> int:
	return (
		CATALOG.ARCHETYPES[_variant_index]
		if _variant_index >= 0
		else -1
	)


func get_model_mesh_count() -> int:
	return (
		_model.find_children("*", "MeshInstance3D", true, false).size()
		if _model != null
		else 0
	)


func get_limb_mask() -> int:
	return _limb_mask


func _replace_model(archetype_index: int) -> void:
	if _model != null:
		_model.visible = false
	if _models_by_archetype.has(archetype_index):
		_model = _models_by_archetype[archetype_index] as Node3D
		_model.visible = true
	else:
		_model = AVATAR_SCENES[archetype_index].instantiate()
		_model.name = "OrganicModel%d" % archetype_index
		# Network/player origins are capsule centers; Blender models use feet.
		_model.position.y = -1.10
		add_child(_model)
		_models_by_archetype[archetype_index] = _model
	var animation_players := _model.find_children("*", "AnimationPlayer", true, false)
	_animation_player = (
		animation_players[0] as AnimationPlayer
		if not animation_players.is_empty()
		else null
	)
	var skeletons := _model.find_children("*", "Skeleton3D", true, false)
	_skeleton = skeletons[0] as Skeleton3D if not skeletons.is_empty() else null
	if _animation_player != null:
		for animation_name: StringName in LOOPING_ANIMATIONS:
			var animation := _animation_player.get_animation(animation_name)
			if animation != null:
				animation.loop_mode = Animation.LOOP_LINEAR
		_play(&"Idle", 0.0)


func _apply_palette() -> void:
	if _model == null or _variant_index < 0:
		return
	# Godot's dummy headless renderer has no material instance storage. Asset
	# structure and animation are still tested headlessly; palettes are a
	# client-only rendering concern.
	if DisplayServer.get_name() == "headless":
		return
	for child: Node in _model.find_children("*", "MeshInstance3D", true, false):
		var mesh := child as MeshInstance3D
		if mesh.name.contains("BodyContinuous"):
			_override_surface_color(mesh, 0, CATALOG.SKIN_COLORS[_variant_index])
		elif mesh.name.contains("OutfitStreet"):
			_override_surface_color(mesh, 0, CATALOG.OUTFIT_COLORS[_variant_index])


func _override_surface_color(mesh: MeshInstance3D, surface: int, color: Color) -> void:
	var source := mesh.mesh.surface_get_material(surface) as StandardMaterial3D
	if source == null:
		return
	var customized := source.duplicate() as StandardMaterial3D
	customized.albedo_color = color
	mesh.set_surface_override_material(surface, customized)


func _play(animation_name: StringName, blend: float) -> void:
	if _animation_player == null or not _animation_player.has_animation(animation_name):
		return
	_motion_state = animation_name
	_animation_player.play(animation_name, blend)
