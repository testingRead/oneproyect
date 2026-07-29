class_name HumanoidRig
extends RefCounted

const CATALOG := preload("res://scripts/characters/character_catalog.gd")
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

static var _rounded_sphere: SphereMesh
static var _rounded_capsule: CapsuleMesh
static var _rounded_cap: CylinderMesh


static func apply_variant(root: Node3D, index: int) -> Color:
	var safe_index := CATALOG.sanitize_index(index)
	var color: Color = CATALOG.COLORS[safe_index]
	var body := root.get_node("Body") as MeshInstance3D
	var material := body.get_active_material(0).duplicate() as StandardMaterial3D
	material.albedo_color = color
	for part_name in BODY_PART_NAMES:
		(root.get_node(part_name) as MeshInstance3D).material_override = material
	apply_proportions(root, safe_index)
	apply_limb_mask(root, ALL_BODY_PARTS_MASK, safe_index)
	return color


static func apply_proportions(root: Node3D, index: int) -> void:
	root.get_node("Body").scale = Vector3(0.76, 0.78, 0.44)
	root.get_node("Head").scale = Vector3(0.6, 0.56, 0.54)
	root.get_node("LeftArm").scale = Vector3(0.23, 0.67, 0.32)
	root.get_node("RightArm").scale = Vector3(0.23, 0.67, 0.32)
	root.get_node("LeftLeg").scale = Vector3(0.28, 0.77, 0.36)
	root.get_node("RightLeg").scale = Vector3(0.28, 0.77, 0.36)
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
	left_arm_target = lerpf(left_arm_target, -1.18, push_weight)
	right_arm_target = lerpf(right_arm_target, -1.18, push_weight)
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
		-0.12 * push_weight,
		delta * 18.0
	)
	root.get_node("Head").rotation.x = lerpf(
		root.get_node("Head").rotation.x,
		0.08 * push_weight,
		delta * 18.0
	)
	root.get_node("Head").position.y = 1.04 + bob
	root.get_node("Visor").position.y = 1.03 + bob
	root.get_node("Cap").position.y = 1.43 + bob
	root.get_node("LeftEar").position.y = 1.43 + bob
	root.get_node("RightEar").position.y = 1.43 + bob
	root.get_node("Tail").rotation.y = sin(walk_phase * 0.5) * 0.3 * movement_weight
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
	for part_name in BODY_PART_NAMES + ["Cap", "Backpack"]:
		(root.get_node(part_name) as GeometryInstance3D).cast_shadow = shadow_mode


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
