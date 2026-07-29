class_name DomainMinigame
extends "res://scripts/minigames/minigame_mode.gd"

const ZONE_RADIUS := 6.5

var _ring: MeshInstance3D
var _phase := 0.0


func _ready() -> void:
	mode_id = &"domain"
	category = ModeCategory.CUSTOM
	round_duration = 44.0
	upcoming_title = "PRÓXIMO: DOMINIO"
	upcoming_detail = "Ocupa el núcleo · cada segundo cuenta"
	active_title = "DOMINIO DEL NÚCLEO"
	active_detail = "¡Mantente dentro del círculo para sumar control!"
	required_map_tags = PackedStringArray(["domain", "custom"])
	pinned_map_id = &"nucleo_tactico"
	feature_ids = PackedStringArray(["domain_tracker"])
	spawn_policy_id = &"separated"
	_build_zone()
	set_process(false)


func begin_round(_round_number: int) -> void:
	_ring.visible = true
	set_process(true)


func finish_round() -> void:
	_ring.visible = false
	set_process(false)


func _process(delta: float) -> void:
	_phase = fmod(_phase + delta * 1.8, TAU)
	var pulse := 1.0 + sin(_phase) * 0.035
	_ring.scale = Vector3(pulse, 1.0, pulse)


func _build_zone() -> void:
	_ring = MeshInstance3D.new()
	_ring.name = "CaptureZone"
	var mesh := CylinderMesh.new()
	mesh.top_radius = ZONE_RADIUS
	mesh.bottom_radius = ZONE_RADIUS
	mesh.height = 0.045
	mesh.radial_segments = 32
	var material := StandardMaterial3D.new()
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = Color(0.08, 0.85, 0.92, 0.34)
	material.emission_enabled = true
	material.emission = Color(0.02, 0.38, 0.48)
	material.emission_energy_multiplier = 1.3
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mesh.material = material
	_ring.mesh = mesh
	_ring.position.y = 0.08
	_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_ring)
