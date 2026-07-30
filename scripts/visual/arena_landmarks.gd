class_name ArenaLandmarks
extends Node3D

@export_enum("DroneDepot", "HighDocks") var layout := 0

var _steel: StandardMaterial3D
var _accent: StandardMaterial3D
var _mesh: BoxMesh
var _shape: BoxShape3D


func _ready() -> void:
	_steel = StandardMaterial3D.new()
	_steel.albedo_color = Color(0.12, 0.17, 0.22)
	_steel.metallic = 0.42
	_steel.roughness = 0.6
	_accent = StandardMaterial3D.new()
	_accent.albedo_color = (
		Color(0.78, 0.2, 0.08) if layout == 0 else Color(0.08, 0.48, 0.62)
	)
	_accent.roughness = 0.7
	_mesh = BoxMesh.new()
	_mesh.size = Vector3.ONE
	_shape = BoxShape3D.new()
	_shape.size = Vector3.ONE
	if layout == 0:
		_build_drone_depot()
	else:
		_build_high_docks()


func _build_drone_depot() -> void:
	_add_box("CentralHangar", Vector3(0, 2.25, 0), Vector3(9.0, 4.5, 7.0), _steel)
	_add_box("HangarRoof", Vector3(0, 5.05, 0), Vector3(11.0, 1.1, 8.5), _accent)
	for index in 4:
		var angle := TAU * float(index) / 4.0 + PI * 0.25
		var position := Vector3(cos(angle) * 17.0, 1.4, sin(angle) * 17.0)
		_add_box("CargoTower%02d" % index, position, Vector3(4.2, 2.8, 4.2), _steel)
		_add_box(
			"CargoTop%02d" % index,
			position + Vector3(0, 2.1, 0),
			Vector3(5.0, 1.4, 5.0),
			_accent
		)
	for index in 6:
		_add_box(
			"Barrier%02d" % index,
			Vector3(-22.0 + index * 8.8, 0.65, -11.5 if index % 2 == 0 else 11.5),
			Vector3(4.8, 1.3, 1.0),
			_accent
		)


func _build_high_docks() -> void:
	for index in 3:
		var x := -18.0 + index * 18.0
		var height := 2.2 + index * 0.65
		_add_box(
			"Dock%02d" % index,
			Vector3(x, height * 0.5, -4.0 + index * 4.0),
			Vector3(12.0, height, 9.0),
			_steel
		)
		_add_box(
			"DockDeck%02d" % index,
			Vector3(x, height + 0.25, -4.0 + index * 4.0),
			Vector3(13.2, 0.5, 10.2),
			_accent
		)
	_add_box("NorthBridge", Vector3(0, 3.8, -19), Vector3(30, 0.75, 4.0), _steel)
	_add_box("SouthBridge", Vector3(0, 2.6, 20), Vector3(24, 0.75, 4.0), _accent)
	for index in 5:
		var z := -16.0 + index * 8.0
		_add_box(
			"Container%02d" % index,
			Vector3(-27.0 if index % 2 == 0 else 27.0, 1.3, z),
			Vector3(7.0, 2.6, 3.2),
			_accent if index % 2 == 0 else _steel
		)


func _add_box(
	node_name: String,
	box_position: Vector3,
	size: Vector3,
	material: Material
) -> void:
	var body := StaticBody3D.new()
	body.name = node_name
	body.position = box_position
	add_child(body)
	var visual := MeshInstance3D.new()
	visual.mesh = _mesh
	visual.scale = size
	visual.material_override = material
	visual.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	body.add_child(visual)
	var collision := CollisionShape3D.new()
	collision.shape = _shape
	collision.scale = size
	body.add_child(collision)
