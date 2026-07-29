class_name ShooterControlsFeature
extends "res://scripts/features/gameplay_feature.gd"

var _player: GrayboxPlayer
var _shoot_button: Control
var _network: Variant
var _disaster: DisasterController
var _previous_first_person := false
var _active := false
var _cooldown := 0.0
var _weapon_root: Node3D
var _weapon_base_position := Vector3(0.34, -0.28, -0.62)
var _recoil := 0.0


func _ready() -> void:
	feature_id = &"shooter_controls"
	required_capabilities = PackedStringArray(["aim", "shoot"])


func activate(context: Dictionary) -> void:
	super.activate(context)
	_player = context.get("player") as GrayboxPlayer
	var hud := context.get("hud") as CanvasLayer
	_network = get_node("/root/Network")
	var world := context.get("world") as Node3D
	_disaster = (
		world.get_node_or_null("DisasterController") as DisasterController
		if world != null
		else null
	)
	_shoot_button = hud.get_node_or_null("Shoot") as Control if hud != null else null
	if _shoot_button != null:
		_shoot_button.visible = true
		if not _shoot_button.action_pressed.is_connected(_request_shot):
			_shoot_button.action_pressed.connect(_request_shot)
	if _player != null:
		_previous_first_person = _player.is_first_person()
		_player.set_first_person(true)
		_ensure_weapon()
		_weapon_root.visible = true
	_active = true
	set_process(true)


func deactivate() -> void:
	_active = false
	set_process(false)
	if _shoot_button != null:
		_shoot_button.visible = false
	if _player != null:
		_player.set_first_person(_previous_first_person)
	if _weapon_root != null:
		_weapon_root.visible = false
	super.deactivate()


func _process(delta: float) -> void:
	_cooldown = maxf(0.0, _cooldown - delta)
	_recoil = move_toward(_recoil, 0.0, delta * 8.0)
	if _weapon_root != null:
		_weapon_root.position = _weapon_base_position + Vector3(0.0, -_recoil * 0.025, _recoil * 0.11)
		_weapon_root.rotation.x = -_recoil * 0.09
	if _active and Input.is_action_just_pressed("shoot"):
		_request_shot()


func _request_shot() -> void:
	if not _active or _player == null or _cooldown > 0.0:
		return
	_cooldown = 0.24
	_recoil = 1.0
	var origin := _player.get_shoot_origin()
	var direction := _player.get_shoot_direction()
	if _network.is_online():
		_network.send_shot(origin, direction)
	elif _disaster != null:
		_disaster.spawn_network_shot(origin, origin + direction * 32.0)


func _ensure_weapon() -> void:
	if _weapon_root != null or _player == null:
		return
	var camera := _player.get_node_or_null("CameraRig/SpringArm/Camera") as Camera3D
	if camera == null:
		return
	_weapon_root = Node3D.new()
	_weapon_root.name = "ClientWeapon"
	_weapon_root.position = _weapon_base_position
	camera.add_child(_weapon_root)

	var dark := StandardMaterial3D.new()
	dark.albedo_color = Color(0.075, 0.09, 0.105)
	dark.metallic = 0.72
	dark.roughness = 0.34
	var accent := StandardMaterial3D.new()
	accent.albedo_color = Color(0.96, 0.31, 0.07)
	accent.metallic = 0.35
	accent.roughness = 0.42

	_add_box("Receiver", Vector3(0.22, 0.17, 0.52), Vector3.ZERO, dark)
	_add_box("Stock", Vector3(0.18, 0.20, 0.26), Vector3(0.0, -0.015, 0.36), dark)
	_add_box("Grip", Vector3(0.11, 0.25, 0.14), Vector3(0.0, -0.18, 0.13), accent, -0.22)
	_add_box("Sight", Vector3(0.065, 0.07, 0.13), Vector3(0.0, 0.12, -0.08), accent)
	var barrel_mesh := CylinderMesh.new()
	barrel_mesh.top_radius = 0.035
	barrel_mesh.bottom_radius = 0.044
	barrel_mesh.height = 0.48
	barrel_mesh.radial_segments = 12
	var barrel := MeshInstance3D.new()
	barrel.name = "Barrel"
	barrel.mesh = barrel_mesh
	barrel.material_override = dark
	barrel.position = Vector3(0.0, 0.01, -0.50)
	barrel.rotation.x = PI * 0.5
	barrel.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_weapon_root.add_child(barrel)


func _add_box(
	part_name: String,
	size: Vector3,
	part_position: Vector3,
	material: Material,
	rotation_x := 0.0
) -> void:
	var box_mesh := BoxMesh.new()
	box_mesh.size = size
	var part := MeshInstance3D.new()
	part.name = part_name
	part.mesh = box_mesh
	part.material_override = material
	part.position = part_position
	part.rotation.x = rotation_x
	part.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_weapon_root.add_child(part)
