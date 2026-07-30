class_name LocalEventHost
extends Node3D

signal event_started(seed: int)
signal event_impact(position: Vector3)
signal event_finished

const METEOR_COUNT := 3

var _meteors: Array[LocalReferenceMeteor] = []
var _running := false
var _impact_count := 0


func _ready() -> void:
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.22, 0.16, 0.12)
	material.roughness = 0.96
	for index in METEOR_COUNT:
		var meteor := LocalReferenceMeteor.new()
		meteor.name = "Meteor%d" % index
		var collision := CollisionShape3D.new()
		var shape := SphereShape3D.new()
		shape.radius = 0.48
		collision.shape = shape
		meteor.add_child(collision)
		var mesh := MeshInstance3D.new()
		var sphere := SphereMesh.new()
		sphere.radius = 0.48
		sphere.height = 0.96
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


func start_reference_event(
	seed: int,
	event_points: PackedVector3Array
) -> void:
	stop_and_clean()
	_running = true
	_impact_count = 0
	var generator := RandomNumberGenerator.new()
	generator.seed = seed
	for index in _meteors.size():
		var target := Vector3(float(index - 1) * 4.0, 0.0, -18.0)
		if not event_points.is_empty():
			target = event_points[index % event_points.size()]
		target.x += generator.randf_range(-1.2, 1.2)
		target.z += generator.randf_range(-1.2, 1.2)
		var start := target + Vector3(
			generator.randf_range(-1.5, 1.5),
			generator.randf_range(7.0, 9.0),
			generator.randf_range(-1.5, 1.5)
		)
		_meteors[index].launch(start, (target - start).normalized() * 9.0)
	event_started.emit(seed)


func stop_and_clean() -> void:
	_running = false
	for meteor in _meteors:
		meteor.deactivate()


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
	event_impact.emit(meteor.global_position)


func _on_meteor_deactivated(_meteor: LocalReferenceMeteor) -> void:
	if _running and get_active_count() == 0:
		_running = false
		event_finished.emit()
