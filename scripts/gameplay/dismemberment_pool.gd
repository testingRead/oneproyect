class_name DismembermentPool
extends Node3D

const POOL_SIZE := 12
const PART_LIFETIME := 5.0

var _bodies: Array[RigidBody3D] = []
var _meshes: Array[MeshInstance3D] = []
var _shapes: Array[BoxShape3D] = []
var _lifetimes := PackedFloat32Array()


func _ready() -> void:
	var shared_mesh := BoxMesh.new()
	shared_mesh.size = Vector3.ONE
	for index in POOL_SIZE:
		var body := RigidBody3D.new()
		body.name = "Part%02d" % index
		body.freeze = true
		body.collision_layer = 0
		body.collision_mask = 0
		body.mass = 0.35
		var mesh_instance := MeshInstance3D.new()
		mesh_instance.mesh = shared_mesh
		mesh_instance.visible = false
		mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var material := StandardMaterial3D.new()
		material.roughness = 0.86
		mesh_instance.material_override = material
		var collision := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = Vector3.ONE
		collision.shape = shape
		body.add_child(mesh_instance)
		body.add_child(collision)
		add_child(body)
		_bodies.append(body)
		_meshes.append(mesh_instance)
		_shapes.append(shape)
		_lifetimes.append(0.0)


func _physics_process(delta: float) -> void:
	for index in _bodies.size():
		if _lifetimes[index] <= 0.0:
			continue
		_lifetimes[index] -= delta
		if _lifetimes[index] <= 0.0:
			_deactivate(index)


func spawn_part(
	part_transform: Transform3D,
	part_scale: Vector3,
	color: Color,
	impulse: Vector3
) -> void:
	var slot := _find_slot()
	var body := _bodies[slot]
	body.freeze = true
	body.global_transform = part_transform
	body.scale = Vector3.ONE
	_meshes[slot].scale = part_scale
	_shapes[slot].size = part_scale
	(_meshes[slot].material_override as StandardMaterial3D).albedo_color = color
	_meshes[slot].visible = true
	body.collision_layer = 1
	body.collision_mask = 1
	body.freeze = false
	body.sleeping = false
	body.linear_velocity = Vector3.ZERO
	body.angular_velocity = Vector3.ZERO
	body.apply_central_impulse(impulse)
	body.apply_torque_impulse(Vector3(0.7, 1.1, 0.45))
	_lifetimes[slot] = PART_LIFETIME


func _find_slot() -> int:
	for index in _bodies.size():
		if _lifetimes[index] <= 0.0:
			return index
	var oldest := 0
	for index in range(1, _lifetimes.size()):
		if _lifetimes[index] < _lifetimes[oldest]:
			oldest = index
	_deactivate(oldest)
	return oldest


func _deactivate(index: int) -> void:
	var body := _bodies[index]
	body.freeze = true
	body.collision_layer = 0
	body.collision_mask = 0
	body.scale = Vector3.ONE
	_meshes[index].scale = Vector3.ONE
	_shapes[index].size = Vector3.ONE
	_meshes[index].visible = false
	_lifetimes[index] = 0.0
