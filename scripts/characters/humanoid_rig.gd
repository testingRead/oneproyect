class_name HumanoidRig
extends RefCounted

const CATALOG := preload("res://scripts/characters/character_catalog.gd")
const MODULAR_AVATAR := preload("res://scripts/characters/modular_avatar.gd")
const SUIT_TEXTURE := preload("res://assets/textures/suit_panels.res")
const ALL_BODY_PARTS_MASK := 0b111111111111
const ALL_LIMBS_MASK := ALL_BODY_PARTS_MASK
const HEAD := 0
const LEFT_ARM := 1
const RIGHT_ARM := 2
const LEFT_HAND := 3
const RIGHT_HAND := 4
const LEFT_LEG := 5
const RIGHT_LEG := 6
const CAP := 7
const BACKPACK := 8
const LEFT_EAR := 9
const RIGHT_EAR := 10
const TAIL := 11
const BODY_PART_NAMES := [
	"Body",
	"Head",
	"LeftArm",
	"RightArm",
	"LeftHand",
	"RightHand",
	"LeftLeg",
	"RightLeg",
	"LeftEar",
	"RightEar",
	"Tail",
]
const ROUNDED_SPHERE_PARTS := ["Head", "LeftHand", "RightHand"]
const ROUNDED_CAPSULE_PARTS := [
	"Body",
	"LeftArm",
	"RightArm",
	"LeftLeg",
	"RightLeg",
	"LeftEar",
	"RightEar",
	"Tail",
]
const DETAIL_PART_NAMES := [
	"Chest",
	"Pelvis",
	"LeftForearm",
	"RightForearm",
	"LeftFoot",
	"RightFoot",
]

static var _rounded_sphere: SphereMesh
static var _rounded_capsule: CapsuleMesh
static var _rounded_cap: CylinderMesh
static var _detail_box: BoxMesh


static func apply_variant(root: Node3D, index: int) -> Color:
	var safe_index := CATALOG.sanitize_index(index)
	var color: Color = CATALOG.COLORS[safe_index]
	var body := root.get_node("Body") as MeshInstance3D
	var material := body.get_active_material(0).duplicate() as StandardMaterial3D
	material.albedo_color = color
	_ensure_detail_parts(root)
	for part_name in BODY_PART_NAMES:
		(root.get_node(part_name) as MeshInstance3D).material_override = material
	for part_name in DETAIL_PART_NAMES:
		(root.get_node(part_name) as MeshInstance3D).material_override = material
	apply_proportions(root, safe_index)
	apply_limb_mask(root, ALL_BODY_PARTS_MASK, safe_index)
	var organic := _ensure_modular_avatar(root)
	organic.configure(safe_index)
	_hide_legacy_parts(root)
	return color


static func apply_proportions(root: Node3D, index: int) -> void:
	root.get_node("Body").scale = Vector3(0.76, 0.78, 0.44)
	root.get_node("Head").scale = Vector3(0.6, 0.56, 0.54)
	root.get_node("LeftArm").position.x = -0.545
	root.get_node("RightArm").position.x = 0.545
	root.get_node("LeftArm").scale = Vector3(0.23, 0.67, 0.32)
	root.get_node("RightArm").scale = Vector3(0.23, 0.67, 0.32)
	root.get_node("LeftLeg").position.x = -0.19
	root.get_node("RightLeg").position.x = 0.19
	root.get_node("LeftLeg").scale = Vector3(0.28, 0.77, 0.36)
	root.get_node("RightLeg").scale = Vector3(0.28, 0.77, 0.36)
	root.get_node("Chest").scale = Vector3(0.7, 0.32, 0.46)
	root.get_node("Pelvis").scale = Vector3(0.62, 0.25, 0.43)
	match index:
		1:
			root.get_node("Body").scale.x = 0.84
			root.get_node("Head").scale = Vector3(0.64, 0.58, 0.56)
		2:
			root.get_node("Body").scale = Vector3(0.68, 0.82, 0.42)
			root.get_node("Head").scale = Vector3(0.66, 0.6, 0.58)
			root.get_node("LeftArm").scale.x = 0.2
			root.get_node("RightArm").scale.x = 0.2
			root.get_node("LeftLeg").scale.x = 0.24
			root.get_node("RightLeg").scale.x = 0.24
		3:
			root.get_node("Body").scale = Vector3(0.9, 0.72, 0.52)
			root.get_node("Head").scale = Vector3(0.68, 0.54, 0.58)
			root.get_node("LeftArm").scale.x = 0.27
			root.get_node("RightArm").scale.x = 0.27
		4:
			root.get_node("Body").scale = Vector3(0.82, 0.84, 0.46)
			root.get_node("Head").scale = Vector3(0.58, 0.58, 0.54)
		CATALOG.PIONEER_INDEX:
			root.get_node("Body").scale = Vector3(0.66, 0.8, 0.42)
			root.get_node("Chest").scale = Vector3(0.7, 0.3, 0.46)
			root.get_node("Pelvis").scale = Vector3(0.72, 0.27, 0.46)
			root.get_node("Head").scale = Vector3(0.58, 0.57, 0.54)
			root.get_node("LeftArm").position.x = -0.49
			root.get_node("RightArm").position.x = 0.49
			root.get_node("LeftArm").scale = Vector3(0.2, 0.68, 0.29)
			root.get_node("RightArm").scale = Vector3(0.2, 0.68, 0.29)
			root.get_node("LeftLeg").position.x = -0.21
			root.get_node("RightLeg").position.x = 0.21
			root.get_node("LeftLeg").scale = Vector3(0.25, 0.79, 0.34)
			root.get_node("RightLeg").scale = Vector3(0.25, 0.79, 0.34)


static func animate(
	root: Node3D,
	delta: float,
	horizontal_speed: float,
	walk_phase: float,
	on_floor: bool,
	push_weight := 0.0,
	hurt_weight := 0.0,
	aim_weight := 0.0,
	shoot_weight := 0.0,
	reload_weight := 0.0
) -> float:
	var detail_quality := int(root.get_meta(&"detail_quality", 0))
	var secondary_weight := 1.0 if detail_quality >= 1 else 0.35
	var high_weight := 1.0 if detail_quality >= 2 else 0.0
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
	left_arm_target = lerpf(left_arm_target, -1.52, push_weight)
	right_arm_target = lerpf(right_arm_target, -1.52, push_weight)
	left_arm_target = lerpf(left_arm_target, -1.28, aim_weight)
	right_arm_target = lerpf(right_arm_target, -1.42 + shoot_weight * 0.16, aim_weight)
	left_arm_target = lerpf(left_arm_target, -0.72, reload_weight)
	right_arm_target = lerpf(right_arm_target, -0.96, reload_weight)
	left_leg_target = lerpf(left_leg_target, 0.16, push_weight)
	right_leg_target = lerpf(right_leg_target, -0.16, push_weight)
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
	root.get_node("LeftArm").rotation.z = lerpf(
		root.get_node("LeftArm").rotation.z,
		(-0.34 * aim_weight + 0.52 * reload_weight) * secondary_weight,
		delta * 12.0
	)
	root.get_node("RightArm").rotation.z = lerpf(
		root.get_node("RightArm").rotation.z,
		(0.18 * aim_weight - 0.35 * reload_weight) * secondary_weight,
		delta * 12.0
	)
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
	root.get_node("Body").rotation.x = lerpf(
		root.get_node("Body").rotation.x,
		-0.30 * push_weight,
		delta * 18.0
	)
	root.get_node("Body").rotation.y = lerpf(
		root.get_node("Body").rotation.y,
		-0.08 * shoot_weight * high_weight + 0.12 * reload_weight * high_weight,
		delta * 16.0
	)
	root.get_node("Head").rotation.x = lerpf(
		root.get_node("Head").rotation.x,
		0.18 * push_weight,
		delta * 18.0
	)
	root.get_node("Head").rotation.z = lerpf(
		root.get_node("Head").rotation.z,
		0.06 * shoot_weight * high_weight,
		delta * 16.0
	)
	root.get_node("Head").position.y = 1.04 + bob
	root.get_node("Visor").position.y = 1.03 + bob
	root.get_node("Cap").position.y = 1.43 + bob
	root.get_node("LeftEar").position.y = 1.43 + bob
	root.get_node("RightEar").position.y = 1.43 + bob
	root.get_node("Tail").rotation.y = sin(walk_phase * 0.5) * 0.3 * movement_weight
	_update_detail_pose(root, bob)
	var organic := root.get_node_or_null("OrganicAvatar") as ModularAvatar
	if organic != null:
		organic.update_motion(
			horizontal_speed,
			on_floor,
			push_weight,
			aim_weight,
			shoot_weight,
			reload_weight,
			root.scale.y < 0.9
		)
	return walk_phase


static func apply_limb_mask(root: Node3D, mask: int, variant_index: int) -> void:
	var safe_mask := mask & ALL_BODY_PARTS_MASK
	var head_attached := _has_limb(safe_mask, HEAD)
	var left_arm_attached := _has_limb(safe_mask, LEFT_ARM)
	var right_arm_attached := _has_limb(safe_mask, RIGHT_ARM)
	root.get_node("Head").visible = head_attached
	root.get_node("Visor").visible = head_attached
	root.get_node("Cap").visible = (
		head_attached
		and variant_index in [0, 4]
		and _has_limb(safe_mask, CAP)
	)
	root.get_node("Backpack").visible = (
		variant_index in [1, 3]
		and _has_limb(safe_mask, BACKPACK)
	)
	root.get_node("LeftEar").visible = (
		head_attached
		and variant_index == 2
		and _has_limb(safe_mask, LEFT_EAR)
	)
	root.get_node("RightEar").visible = (
		head_attached
		and variant_index == 2
		and _has_limb(safe_mask, RIGHT_EAR)
	)
	root.get_node("Tail").visible = (
		variant_index == 2
		and _has_limb(safe_mask, TAIL)
	)
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
	if root.has_node("Chest"):
		var detail_visible := int(root.get_meta(&"detail_quality", 0)) >= 1
		root.get_node("Chest").visible = detail_visible
		root.get_node("Pelvis").visible = detail_visible
		root.get_node("LeftForearm").visible = detail_visible and left_arm_attached
		root.get_node("RightForearm").visible = detail_visible and right_arm_attached
		root.get_node("LeftFoot").visible = detail_visible and _has_limb(safe_mask, LEFT_LEG)
		root.get_node("RightFoot").visible = detail_visible and _has_limb(safe_mask, RIGHT_LEG)
	var organic := root.get_node_or_null("OrganicAvatar") as ModularAvatar
	if organic != null:
		organic.set_limb_mask(safe_mask)
		_hide_legacy_parts(root)


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
	for part_name in BODY_PART_NAMES + ["Cap", "Backpack"] + DETAIL_PART_NAMES:
		(root.get_node(part_name) as GeometryInstance3D).cast_shadow = shadow_mode
	var organic := root.get_node_or_null("OrganicAvatar") as ModularAvatar
	if organic != null:
		organic.set_shadow_quality(enabled)


static func set_model_quality(root: Node3D, rounded: bool) -> void:
	_ensure_rounded_meshes()
	for part_name in ROUNDED_SPHERE_PARTS + ROUNDED_CAPSULE_PARTS:
		var part := root.get_node(part_name) as MeshInstance3D
		if not part.has_meta(&"low_mesh"):
			part.set_meta(&"low_mesh", part.mesh)
		if rounded:
			part.mesh = (
				_rounded_sphere
				if part_name in ROUNDED_SPHERE_PARTS
				else _rounded_capsule
			)
		else:
			part.mesh = part.get_meta(&"low_mesh") as Mesh
	var cap := root.get_node("Cap") as MeshInstance3D
	if not cap.has_meta(&"low_mesh"):
		cap.set_meta(&"low_mesh", cap.mesh)
	cap.mesh = _rounded_cap if rounded else cap.get_meta(&"low_mesh") as Mesh


static func set_detail_quality(root: Node3D, level: int) -> void:
	_ensure_detail_parts(root)
	_ensure_rounded_meshes()
	root.set_meta(&"detail_quality", level)
	for part_name in DETAIL_PART_NAMES:
		var part := root.get_node(part_name) as MeshInstance3D
		part.visible = level >= 1
		part.mesh = _rounded_capsule if level >= 2 else _detail_box


static func _ensure_rounded_meshes() -> void:
	if _rounded_sphere != null:
		return
	_rounded_sphere = SphereMesh.new()
	_rounded_sphere.radius = 0.5
	_rounded_sphere.height = 1.0
	_rounded_sphere.radial_segments = 16
	_rounded_sphere.rings = 8
	_rounded_capsule = CapsuleMesh.new()
	_rounded_capsule.radius = 0.5
	_rounded_capsule.height = 1.0
	_rounded_capsule.radial_segments = 16
	_rounded_capsule.rings = 8
	_rounded_cap = CylinderMesh.new()
	_rounded_cap.top_radius = 0.36
	_rounded_cap.bottom_radius = 0.48
	_rounded_cap.height = 0.18
	_rounded_cap.radial_segments = 20
	_detail_box = BoxMesh.new()
	_detail_box.size = Vector3.ONE


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
	hand.position.x = arm.position.x
	hand.position.y = arm.position.y - 0.435 * cos(arm_angle)
	hand.position.z = 0.02 - 0.435 * sin(arm_angle)


static func _ensure_detail_parts(root: Node3D) -> void:
	if root.has_node("Chest"):
		return
	if _detail_box == null:
		_detail_box = BoxMesh.new()
		_detail_box.size = Vector3.ONE
	var definitions := {
		"Chest": [Vector3(0, 0.52, 0), Vector3(0.7, 0.32, 0.46)],
		"Pelvis": [Vector3(0, -0.02, 0), Vector3(0.62, 0.25, 0.43)],
		"LeftForearm": [Vector3(-0.545, -0.02, -0.1), Vector3(0.19, 0.42, 0.25)],
		"RightForearm": [Vector3(0.545, -0.02, -0.1), Vector3(0.19, 0.42, 0.25)],
		"LeftFoot": [Vector3(-0.19, -0.96, -0.12), Vector3(0.27, 0.2, 0.46)],
		"RightFoot": [Vector3(0.19, -0.96, -0.12), Vector3(0.27, 0.2, 0.46)],
	}
	for part_name in DETAIL_PART_NAMES:
		var part := MeshInstance3D.new()
		part.name = part_name
		part.mesh = _detail_box
		part.position = definitions[part_name][0]
		part.scale = definitions[part_name][1]
		part.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		part.visible = false
		root.add_child(part)


static func _update_detail_pose(root: Node3D, bob: float) -> void:
	if not root.has_node("Chest"):
		return
	root.get_node("Chest").position.y = 0.52 + bob
	root.get_node("Pelvis").position.y = -0.02 + bob * 0.5
	for side in ["Left", "Right"]:
		var arm := root.get_node(side + "Arm") as Node3D
		var hand := root.get_node(side + "Hand") as Node3D
		var forearm := root.get_node(side + "Forearm") as Node3D
		forearm.position = arm.position.lerp(hand.position, 0.62)
		forearm.rotation = arm.rotation
		var leg := root.get_node(side + "Leg") as Node3D
		var foot := root.get_node(side + "Foot") as Node3D
		foot.position.x = leg.position.x
		foot.position.y = leg.position.y - 0.45 * cos(leg.rotation.x)
		foot.position.z = -0.12 - 0.45 * sin(leg.rotation.x)
		foot.rotation.x = leg.rotation.x * 0.45


static func _ensure_modular_avatar(root: Node3D) -> ModularAvatar:
	var existing := root.get_node_or_null("OrganicAvatar") as ModularAvatar
	if existing != null:
		return existing
	var organic := MODULAR_AVATAR.new() as ModularAvatar
	organic.name = "OrganicAvatar"
	root.add_child(organic)
	return organic


static func _hide_legacy_parts(root: Node3D) -> void:
	for part_name in (
		BODY_PART_NAMES
		+ ["Visor", "Cap", "Backpack"]
		+ DETAIL_PART_NAMES
	):
		var part := root.get_node_or_null(part_name) as GeometryInstance3D
		if part != null:
			part.visible = false
