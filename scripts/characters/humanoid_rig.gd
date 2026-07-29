class_name HumanoidRig
extends RefCounted

const CATALOG := preload("res://scripts/characters/character_catalog.gd")
const SUIT_TEXTURE := preload("res://assets/textures/suit_panels.res")
const ALL_LIMBS_MASK := 0b1111111
const HEAD := 0
const LEFT_ARM := 1
const RIGHT_ARM := 2
const LEFT_HAND := 3
const RIGHT_HAND := 4
const LEFT_LEG := 5
const RIGHT_LEG := 6


static func apply_variant(root: Node3D, index: int) -> Color:
	var safe_index := CATALOG.sanitize_index(index)
	var color: Color = CATALOG.COLORS[safe_index]
	var body := root.get_node("Body") as MeshInstance3D
	var material := body.get_active_material(0).duplicate() as StandardMaterial3D
	material.albedo_color = color
	for part_name in [
		"Body",
		"Head",
		"LeftArm",
		"RightArm",
		"LeftHand",
		"RightHand",
		"LeftLeg",
		"RightLeg",
	]:
		(root.get_node(part_name) as MeshInstance3D).material_override = material
	apply_proportions(root, safe_index)
	apply_limb_mask(root, ALL_LIMBS_MASK, safe_index)
	return color


static func apply_proportions(root: Node3D, index: int) -> void:
	root.get_node("Body").scale = Vector3(0.76, 0.78, 0.44)
	root.get_node("Head").scale = Vector3(0.6, 0.56, 0.54)
	root.get_node("LeftLeg").scale = Vector3(0.28, 0.77, 0.36)
	root.get_node("RightLeg").scale = Vector3(0.28, 0.77, 0.36)
	match index:
		1:
			root.get_node("Body").scale.x = 0.84
			root.get_node("Head").scale = Vector3(0.64, 0.58, 0.56)
		2:
			root.get_node("Body").scale.x = 0.68
			root.get_node("LeftLeg").scale.x = 0.24
			root.get_node("RightLeg").scale.x = 0.24
		3:
			root.get_node("Body").scale.z = 0.52
			root.get_node("Head").scale.x = 0.66


static func animate(
	root: Node3D,
	delta: float,
	horizontal_speed: float,
	walk_phase: float,
	on_floor: bool,
	push_weight := 0.0,
	hurt_weight := 0.0
) -> float:
	var movement_weight := clampf(horizontal_speed / 6.0, 0.0, 1.0)
	if movement_weight > 0.03 and on_floor:
		walk_phase = fmod(walk_phase + delta * (7.0 + horizontal_speed * 0.65), TAU)
	var swing := sin(walk_phase) * 0.7 * movement_weight
	var left_arm_target := swing
	var right_arm_target := -swing
	var left_leg_target := -swing
	var right_leg_target := swing
	if not on_floor:
		left_arm_target = -0.38
		right_arm_target = -0.38
		left_leg_target = 0.2
		right_leg_target = -0.2
	left_arm_target = lerpf(left_arm_target, 1.25, push_weight)
	right_arm_target = lerpf(right_arm_target, 1.25, push_weight)
	root.get_node("LeftArm").rotation.x = lerpf(
		root.get_node("LeftArm").rotation.x,
		left_arm_target,
		delta * 12.0
	)
	root.get_node("RightArm").rotation.x = lerpf(
		root.get_node("RightArm").rotation.x,
		right_arm_target,
		delta * 12.0
	)
	root.get_node("LeftHand").rotation.x = root.get_node("LeftArm").rotation.x
	root.get_node("RightHand").rotation.x = root.get_node("RightArm").rotation.x
	root.get_node("LeftLeg").rotation.x = lerpf(
		root.get_node("LeftLeg").rotation.x,
		left_leg_target,
		delta * 12.0
	)
	root.get_node("RightLeg").rotation.x = lerpf(
		root.get_node("RightLeg").rotation.x,
		right_leg_target,
		delta * 12.0
	)
	_update_hand_position(root, "LeftArm", "LeftHand")
	_update_hand_position(root, "RightArm", "RightHand")
	var bob := absf(sin(walk_phase * 2.0)) * 0.035 * movement_weight
	root.get_node("Body").position.y = 0.31 + bob
	root.get_node("Body").rotation.z = lerpf(
		root.get_node("Body").rotation.z,
		-0.18 * hurt_weight,
		delta * 18.0
	)
	root.get_node("Head").position.y = 1.04 + bob
	root.get_node("Visor").position.y = 1.03 + bob
	return walk_phase


static func apply_limb_mask(root: Node3D, mask: int, variant_index: int) -> void:
	var safe_mask := mask & ALL_LIMBS_MASK
	var head_attached := _has_limb(safe_mask, HEAD)
	var left_arm_attached := _has_limb(safe_mask, LEFT_ARM)
	var right_arm_attached := _has_limb(safe_mask, RIGHT_ARM)
	root.get_node("Head").visible = head_attached
	root.get_node("Visor").visible = head_attached
	root.get_node("Cap").visible = head_attached and variant_index % 2 == 0
	root.get_node("Backpack").visible = variant_index % 2 == 1
	root.get_node("LeftArm").visible = left_arm_attached
	root.get_node("RightArm").visible = right_arm_attached
	root.get_node("LeftHand").visible = (
		left_arm_attached and _has_limb(safe_mask, LEFT_HAND)
	)
	root.get_node("RightHand").visible = (
		right_arm_attached and _has_limb(safe_mask, RIGHT_HAND)
	)
	root.get_node("LeftLeg").visible = _has_limb(safe_mask, LEFT_LEG)
	root.get_node("RightLeg").visible = _has_limb(safe_mask, RIGHT_LEG)


static func set_texture_detail(root: Node3D, enabled: bool) -> void:
	var material := (
		(root.get_node("Body") as MeshInstance3D).material_override
		as StandardMaterial3D
	)
	if material != null:
		material.albedo_texture = SUIT_TEXTURE if enabled else null


static func set_shadow_quality(root: Node3D, enabled: bool) -> void:
	var shadow_mode := (
		GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		if enabled
		else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	)
	for part_name in [
		"Body",
		"Head",
		"LeftArm",
		"RightArm",
		"LeftHand",
		"RightHand",
		"LeftLeg",
		"RightLeg",
	]:
		(root.get_node(part_name) as GeometryInstance3D).cast_shadow = shadow_mode


static func _has_limb(mask: int, limb: int) -> bool:
	return (mask & (1 << limb)) != 0


static func _update_hand_position(
	root: Node3D,
	arm_name: String,
	hand_name: String
) -> void:
	var arm := root.get_node(arm_name) as Node3D
	var hand := root.get_node(hand_name) as Node3D
	var arm_angle := arm.rotation.x
	hand.position.y = arm.position.y - 0.435 * cos(arm_angle)
	hand.position.z = 0.02 - 0.435 * sin(arm_angle)
