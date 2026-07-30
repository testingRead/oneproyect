class_name LocalEventHost
extends Node3D

signal event_started(seed: int)
signal event_warning(position: Vector3, index: int)
signal event_impact(position: Vector3)
signal event_finished

const METEOR_COUNT := 3
const WARNING_SECONDS := 0.9
const LAUNCH_GAP_SECONDS := 1.25

var _meteors: Array[LocalReferenceMeteor] = []
var _warning_markers: Array[MeshInstance3D] = []
var _running := false
var _impact_count := 0
var _generation := 0
var _sequence_complete := false


func _ready() -> void:
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.95, 0.22, 0.05)
	material.emission_enabled = true
	material.emission = Color(1.0, 0.12, 0.02)
	material.emission_energy_multiplier = 2.2
	material.roughness = 0.72
	for index in METEOR_COUNT:
		var meteor := LocalReferenceMeteor.new()
		meteor.name = "Meteor%d" % index
		meteor.set_meta(&"pool_index", index)
		var collision := CollisionShape3D.new()
		var shape := SphereShape3D.new()
		shape.radius = 0.64
		collision.shape = shape
		meteor.add_child(collision)
		var mesh := MeshInstance3D.new()
		var sphere := SphereMesh.new()
		sphere.radius = 0.64
		sphere.height = 1.28
		sphere.radial_segments = 12
		sphere.rings = 6
		mesh.mesh = sphere
		mesh.material_override = material
		mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		meteor.add_child(mesh)
		add_child(meteor)
		meteor.impacted.connect(_on_meteor_impacted)
		meteor.deactivated.connect(_on_meteor_deactivated)
		_meteors.append(meteor)
		_warning_markers.append(_create_warning_marker(index))


func start_reference_event(
	seed: int,
	event_points: PackedVector3Array,
	time_scale := 1.0
) -> void:
	stop_and_clean()
	_generation += 1
	_running = true
	_sequence_complete = false
	_impact_count = 0
	var generator := RandomNumberGenerator.new()
	generator.seed = seed
	var targets := PackedVector3Array()
	var starts := PackedVector3Array()
	for index in _meteors.size():
		var target := Vector3(float(index - 1) * 4.0, 0.0, -18.0)
		if not event_points.is_empty():
			target = event_points[index % event_points.size()]
		target.x += generator.randf_range(-1.2, 1.2)
		target.z += generator.randf_range(-1.2, 1.2)
		target.y = 0.46
		var start := target + Vector3(
			generator.randf_range(-1.5, 1.5),
			generator.randf_range(9.0, 11.0),
			generator.randf_range(-1.5, 1.5)
		)
		targets.append(target)
		starts.append(start)
	_launch_sequence(_generation, targets, starts, maxf(0.05, time_scale))
	event_started.emit(seed)


func stop_and_clean() -> void:
	_generation += 1
	_running = false
	_sequence_complete = false
	for meteor in _meteors:
		meteor.deactivate()
	for marker in _warning_markers:
		marker.hide()


func get_active_count() -> int:
	var count := 0
	for meteor in _meteors:
		count += int(meteor.active)
	return count


func get_pool_size() -> int:
	return _meteors.size()


func get_impact_count() -> int:
	return _impact_count


func _on_meteor_impacted(meteor: LocalReferenceMeteor, _body: Node) -> void:
	_impact_count += 1
	var index := int(meteor.get_meta(&"pool_index", -1))
	if index >= 0 and index < _warning_markers.size():
		var marker := _warning_markers[index]
		marker.scale = Vector3.ONE * 1.35
		var material := marker.material_override as StandardMaterial3D
		material.albedo_color = Color(1.0, 0.64, 0.05, 0.9)
		material.emission = Color(1.0, 0.24, 0.02)
		_hide_marker_after(index, _generation, 0.32)
	event_impact.emit(meteor.global_position)


func _on_meteor_deactivated(_meteor: LocalReferenceMeteor) -> void:
	if _running and _sequence_complete and get_active_count() == 0:
		_running = false
		event_finished.emit()


func _launch_sequence(
	generation: int,
	targets: PackedVector3Array,
	starts: PackedVector3Array,
	time_scale: float
) -> void:
	for index in _meteors.size():
		if generation != _generation or not _running:
			return
		var marker := _warning_markers[index]
		marker.global_position = targets[index]
		marker.scale = Vector3.ONE
		var material := marker.material_override as StandardMaterial3D
		material.albedo_color = Color(0.96, 0.04, 0.03, 0.62)
		material.emission = Color(0.95, 0.02, 0.01)
		marker.show()
		event_warning.emit(targets[index], index)
		await get_tree().create_timer(WARNING_SECONDS * time_scale).timeout
		if generation != _generation or not _running:
			return
		_meteors[index].launch(
			starts[index],
			(targets[index] - starts[index]).normalized() * 15.0
		)
		if index < _meteors.size() - 1:
			await get_tree().create_timer(LAUNCH_GAP_SECONDS * time_scale).timeout
	_sequence_complete = true
	if get_active_count() == 0:
		_running = false
		event_finished.emit()


func _hide_marker_after(index: int, generation: int, seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout
	if generation == _generation and index < _warning_markers.size():
		_warning_markers[index].hide()


func _create_warning_marker(index: int) -> MeshInstance3D:
	var marker := MeshInstance3D.new()
	marker.name = "Warning%d" % index
	var disc := CylinderMesh.new()
	disc.top_radius = 1.55
	disc.bottom_radius = 1.55
	disc.height = 0.035
	disc.radial_segments = 24
	marker.mesh = disc
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.96, 0.04, 0.03, 0.62)
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.emission_enabled = true
	material.emission = Color(0.95, 0.02, 0.01)
	material.emission_energy_multiplier = 1.7
	marker.material_override = material
	marker.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	marker.hide()
	add_child(marker)
	return marker
