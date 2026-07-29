class_name ShooterMinigame
extends "res://scripts/minigames/minigame_mode.gd"

const TRACER_POOL_SIZE := 10

var _tracers: Array[MeshInstance3D] = []
var _tracer_lifetimes := PackedFloat32Array()


func _ready() -> void:
	mode_id = &"shooter"
	category = ModeCategory.UNIQUE
	round_duration = 46.0
	upcoming_title = "PRÓXIMO: TODOS CONTRA TODOS"
	upcoming_detail = "Campo industrial · una vida · sin equipos"
	active_title = "SHOOTER INDIVIDUAL"
	active_detail = "¡El último en pie obtiene la mayor puntuación!"
	required_map_tags = PackedStringArray(["shooter", "free_for_all"])
	pinned_map_id = &"campo_tiro"
	feature_ids = PackedStringArray(["shooter_controls"])
	player_profile_id = &"shooter"
	spawn_policy_id = &"separated"
	for index in TRACER_POOL_SIZE:
		var tracer := MeshInstance3D.new()
		tracer.name = "Tracer%02d" % index
		var mesh := CylinderMesh.new()
		mesh.top_radius = 0.025
		mesh.bottom_radius = 0.025
		mesh.height = 1.0
		mesh.radial_segments = 6
		var material := StandardMaterial3D.new()
		material.albedo_color = Color(1.0, 0.72, 0.16)
		material.emission_enabled = true
		material.emission = Color(1.0, 0.28, 0.03)
		material.emission_energy_multiplier = 2.2
		mesh.material = material
		tracer.mesh = mesh
		tracer.visible = false
		tracer.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(tracer)
		_tracers.append(tracer)
		_tracer_lifetimes.append(0.0)
	set_process(false)


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
	for index in _tracers.size():
		_tracers[index].visible = false
		_tracer_lifetimes[index] = 0.0
	set_process(false)


func spawn_network_shot(origin: Vector3, hit_position: Vector3) -> void:
	var direction := hit_position - origin
	var length := direction.length()
	if length < 0.05:
		return
	var slot := _find_tracer_slot()
	var tracer := _tracers[slot]
	var midpoint := origin + direction * 0.5
	tracer.global_position = midpoint
	tracer.scale = Vector3(1.0, length, 1.0)
	tracer.look_at(hit_position, Vector3.UP)
	tracer.rotate_object_local(Vector3.RIGHT, PI * 0.5)
	tracer.visible = true
	_tracer_lifetimes[slot] = 0.12
	set_process(true)


func _process(delta: float) -> void:
	var any_active := false
	for index in _tracers.size():
		if _tracer_lifetimes[index] <= 0.0:
			continue
		_tracer_lifetimes[index] -= delta
		if _tracer_lifetimes[index] <= 0.0:
			_tracers[index].visible = false
		else:
			any_active = true
	set_process(any_active)


func _find_tracer_slot() -> int:
	for index in _tracer_lifetimes.size():
		if _tracer_lifetimes[index] <= 0.0:
			return index
	var oldest := 0
	for index in range(1, _tracer_lifetimes.size()):
		if _tracer_lifetimes[index] < _tracer_lifetimes[oldest]:
			oldest = index
	return oldest
