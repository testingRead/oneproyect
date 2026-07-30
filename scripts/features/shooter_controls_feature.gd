class_name ShooterControlsFeature
extends "res://scripts/features/gameplay_feature.gd"

const WEAPONS := preload("res://shared/weapon_profiles.gd")

var _player: GrayboxPlayer
var _shoot_button: Control
var _reload_button: Control
var _weapon_label: Label
var _network: Variant
var _disaster: DisasterController
var _sounds: SoundBank
var _previous_first_person := false
var _active := false
var _cooldown := 0.0
var _weapon_root: Node3D
var _weapon_base_position := Vector3(0.34, -0.28, -0.62)
var _recoil := 0.0
var _weapon_id := 0
var _ammo := 0
var _reload_remaining := 0.0
var _reload_duration := 1.0


func _ready() -> void:
	feature_id = &"shooter_controls"
	required_capabilities = PackedStringArray(["aim", "shoot"])


func activate(context: Dictionary) -> void:
	super.activate(context)
	_player = context.get("player") as GrayboxPlayer
	var hud := context.get("hud") as CanvasLayer
	var plan := context.get("plan", {}) as Dictionary
	_weapon_id = WEAPONS.from_round_seed(int(plan.get("round_seed", 0)))
	_ammo = WEAPONS.magazine_size(_weapon_id)
	_reload_duration = WEAPONS.reload_seconds(_weapon_id)
	_reload_remaining = 0.0
	_network = get_node("/root/Network")
	var world := context.get("world") as Node3D
	_disaster = (
		world.get_node_or_null("DisasterController") as DisasterController
		if world != null
		else null
	)
	_sounds = (
		world.get_parent().get_node_or_null("SoundBank") as SoundBank
		if world != null and world.get_parent() != null
		else null
	)
	_shoot_button = hud.get_node_or_null("Shoot") as Control if hud != null else null
	_reload_button = hud.get_node_or_null("Reload") as Control if hud != null else null
	if _shoot_button != null:
		_shoot_button.visible = true
		if not _shoot_button.action_pressed.is_connected(_request_shot):
			_shoot_button.action_pressed.connect(_request_shot)
	if _reload_button != null:
		_reload_button.visible = true
		if not _reload_button.action_pressed.is_connected(_begin_reload):
			_reload_button.action_pressed.connect(_begin_reload)
	_ensure_weapon_label(hud)
	if _player != null:
		_previous_first_person = _player.is_first_person()
		_player.set_first_person(true)
		_player.set_combat_pose(true)
		_rebuild_weapon()
		_weapon_root.visible = true
	_active = true
	set_process(true)


func deactivate() -> void:
	_active = false
	set_process(false)
	if _shoot_button != null:
		_shoot_button.visible = false
	if _reload_button != null:
		_reload_button.visible = false
	if _player != null:
		_player.set_first_person(_previous_first_person)
		_player.set_combat_pose(false)
	if _weapon_root != null:
		_weapon_root.visible = false
	if _weapon_label != null:
		_weapon_label.visible = false
	super.deactivate()


func _process(delta: float) -> void:
	_cooldown = maxf(0.0, _cooldown - delta)
	if _reload_remaining > 0.0:
		_reload_remaining = maxf(0.0, _reload_remaining - delta)
		if _reload_remaining <= 0.0:
			_ammo = WEAPONS.magazine_size(_weapon_id)
			_update_weapon_label()
	_recoil = move_toward(_recoil, 0.0, delta * 8.0)
	if _weapon_root != null:
		var reload_weight := (
			sin(PI * (1.0 - _reload_remaining / _reload_duration))
			if _reload_remaining > 0.0
			else 0.0
		)
		_weapon_root.position = (
			_weapon_base_position
			+ Vector3(0.0, -_recoil * 0.025 - reload_weight * 0.26, _recoil * 0.11)
		)
		_weapon_root.rotation = Vector3(
			-_recoil * 0.09 + reload_weight * 0.32,
			0.0,
			reload_weight * 0.42
		)
	if _active and Input.is_action_just_pressed("reload"):
		_begin_reload()
	if _active and Input.is_action_just_pressed("shoot"):
		_request_shot()


func _request_shot() -> void:
	if (
		not _active
		or _player == null
		or _cooldown > 0.0
		or _reload_remaining > 0.0
	):
		return
	if _ammo <= 0:
		_begin_reload()
		return
	_cooldown = WEAPONS.cooldown_seconds(_weapon_id)
	_ammo -= 1
	_recoil = 1.0
	_player.play_shoot_animation()
	_update_weapon_label()
	var origin := _player.get_shoot_origin()
	var direction := _player.get_shoot_direction()
	if _network.is_online():
		_network.send_shot(origin, direction)
	elif _disaster != null:
		_disaster.spawn_network_shot(
			origin,
			origin + direction * WEAPONS.maximum_range(_weapon_id),
			_weapon_id
		)
		if _sounds != null:
			_sounds.play_weapon_shot(_weapon_id)
	if _ammo <= 0:
		_begin_reload()


func _rebuild_weapon() -> void:
	if _player == null:
		return
	var camera := _player.get_node_or_null("CameraRig/SpringArm/Camera") as Camera3D
	if camera == null:
		return
	if _weapon_root != null:
		_weapon_root.queue_free()
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
	match _weapon_id:
		WEAPONS.Id.C16:
			_build_carbine(dark, accent)
		WEAPONS.Id.T12:
			_build_shotgun(dark, accent)
		_:
			_build_pistol(dark, accent)


func _build_pistol(dark: Material, accent: Material) -> void:
	_add_box("Slide", Vector3(0.18, 0.14, 0.48), Vector3(0, 0.03, -0.08), dark)
	_add_box("Frame", Vector3(0.16, 0.11, 0.34), Vector3(0, -0.07, 0), accent)
	_add_box("Grip", Vector3(0.14, 0.30, 0.17), Vector3(0, -0.24, 0.11), dark, -0.18)
	_add_box("FrontSight", Vector3(0.035, 0.035, 0.045), Vector3(0, 0.12, -0.25), accent)
	_add_barrel(Vector3(0, 0.03, -0.34), 0.24, 0.024, dark)


func _build_carbine(dark: Material, accent: Material) -> void:
	_add_box("UpperReceiver", Vector3(0.20, 0.17, 0.58), Vector3.ZERO, dark)
	_add_box("Handguard", Vector3(0.17, 0.15, 0.46), Vector3(0, 0.01, -0.49), accent)
	_add_box("Stock", Vector3(0.18, 0.20, 0.34), Vector3(0, -0.01, 0.43), dark)
	_add_box("Magazine", Vector3(0.13, 0.30, 0.18), Vector3(0, -0.23, -0.02), accent, 0.13)
	_add_box("Grip", Vector3(0.11, 0.27, 0.15), Vector3(0, -0.20, 0.22), dark, -0.22)
	_add_box("Sight", Vector3(0.07, 0.09, 0.18), Vector3(0, 0.15, -0.10), accent)
	_add_barrel(Vector3(0, 0.015, -0.84), 0.42, 0.028, dark)


func _build_shotgun(dark: Material, accent: Material) -> void:
	_add_box("Receiver", Vector3(0.21, 0.18, 0.50), Vector3(0, 0, 0.05), dark)
	_add_box("Stock", Vector3(0.20, 0.22, 0.48), Vector3(0, -0.02, 0.48), accent)
	_add_box("Pump", Vector3(0.22, 0.20, 0.34), Vector3(0, -0.02, -0.42), accent)
	_add_box("Grip", Vector3(0.12, 0.25, 0.15), Vector3(0, -0.20, 0.18), dark, -0.20)
	_add_barrel(Vector3(0, 0.055, -0.80), 0.86, 0.036, dark)
	_add_barrel(Vector3(0, -0.045, -0.65), 0.62, 0.029, accent)


func _add_barrel(
	part_position: Vector3,
	length: float,
	radius: float,
	material: Material
) -> void:
	var barrel_mesh := CylinderMesh.new()
	barrel_mesh.top_radius = radius
	barrel_mesh.bottom_radius = radius * 1.08
	barrel_mesh.height = length
	barrel_mesh.radial_segments = 12
	var barrel := MeshInstance3D.new()
	barrel.name = "Barrel"
	barrel.mesh = barrel_mesh
	barrel.material_override = material
	barrel.position = part_position
	barrel.rotation.x = PI * 0.5
	barrel.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_weapon_root.add_child(barrel)


func _ensure_weapon_label(hud: CanvasLayer) -> void:
	if hud == null:
		return
	if _weapon_label == null:
		_weapon_label = Label.new()
		_weapon_label.name = "WeaponStatus"
		_weapon_label.set_anchors_preset(Control.PRESET_TOP_RIGHT)
		_weapon_label.position = Vector2(-330.0, 82.0)
		_weapon_label.size = Vector2(300.0, 54.0)
		_weapon_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		_weapon_label.add_theme_font_size_override("font_size", 18)
		_weapon_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
		hud.add_child(_weapon_label)
	_update_weapon_label()
	_weapon_label.visible = true


func _update_weapon_label() -> void:
	if _weapon_label == null:
		return
	_weapon_label.text = "%s · %d/%d\n%s%s" % [
		WEAPONS.display_name(_weapon_id),
		_ammo,
		WEAPONS.magazine_size(_weapon_id),
		WEAPONS.reference_name(_weapon_id),
		" · RECARGANDO" if _reload_remaining > 0.0 else "",
	]


func _begin_reload() -> void:
	if (
		not _active
		or _player == null
		or _reload_remaining > 0.0
		or _ammo >= WEAPONS.magazine_size(_weapon_id)
	):
		return
	_reload_remaining = _reload_duration
	_player.play_reload_animation(_reload_duration)
	_update_weapon_label()


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
