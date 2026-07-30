class_name DroneHuntMinigame
extends "res://scripts/minigames/minigame_mode.gd"

const DIFFICULTY := preload("res://shared/difficulty_rules.gd")
const DRONE_COUNT := 4

var _drones: Array[Node3D] = []
var _velocities := PackedVector3Array()
var _attack_cooldowns := PackedFloat32Array()
var _difficulty := DIFFICULTY.Level.NORMAL
var _active := false
var _random := RandomNumberGenerator.new()


func _ready() -> void:
	mode_id = &"drone_hunt"
	category = ModeCategory.CUSTOM
	round_duration = 40.0
	upcoming_title = "PRÓXIMO: CACERÍA DE DRONES"
	upcoming_detail = "Drones personales te perseguirán; usa coberturas y altura"
	active_title = "CACERÍA DE DRONES"
	active_detail = "¡Esquiva a tus perseguidores y no dejes que te rodeen!"
	required_map_tags = PackedStringArray(["drone", "custom", "elevation"])
	pinned_map_id = &"deposito_drones"
	spawn_policy_id = &"separated"
	_velocities.resize(DRONE_COUNT)
	_attack_cooldowns.resize(DRONE_COUNT)
	for index in DRONE_COUNT:
		var drone := _build_drone(index)
		add_child(drone)
		_drones.append(drone)
		drone.visible = false


func begin_round(_round_number: int) -> void:
	_difficulty = DIFFICULTY.from_round_seed(
		int(experience_plan.get("round_seed", 0))
	)
	_random.seed = int(experience_plan.get("round_seed", 1)) + 701
	for index in DRONE_COUNT:
		var angle := TAU * float(index) / float(DRONE_COUNT) + _random.randf_range(-0.3, 0.3)
		_drones[index].global_position = Vector3(
			cos(angle) * (15.0 + index * 1.8),
			2.0 + float(index % 2) * 0.55,
			sin(angle) * (15.0 + index * 1.8)
		)
		_drones[index].visible = true
		_velocities[index] = Vector3.ZERO
		_attack_cooldowns[index] = 0.7 + index * 0.18
	_active = true


func tick_round(
	delta: float,
	_time_left: float,
	_intensity: float,
	_authoritative: bool
) -> void:
	if not _active:
		return
	var player := get_tree().get_first_node_in_group("players") as GrayboxPlayer
	if player == null or player.is_defeated():
		return
	var speed := 3.7
	var damage := 8
	if _difficulty == DIFFICULTY.Level.EASY:
		speed = 3.0
		damage = 6
	elif _difficulty == DIFFICULTY.Level.HARD:
		speed = 5.0
		damage = 12
	for index in _drones.size():
		var drone := _drones[index]
		_attack_cooldowns[index] = maxf(0.0, _attack_cooldowns[index] - delta)
		var target := player.global_position + Vector3(0.0, 0.75, 0.0)
		var offset := target - drone.global_position
		var flat := Vector3(offset.x, 0.0, offset.z)
		var direction := flat.normalized() if flat.length_squared() > 0.01 else Vector3.ZERO
		var desired := direction * speed
		_velocities[index] = _velocities[index].move_toward(desired, delta * 7.0)
		drone.global_position += _velocities[index] * delta
		drone.global_position.y = lerpf(
			drone.global_position.y,
			1.85 + sin(Time.get_ticks_msec() * 0.004 + index) * 0.22,
			delta * 4.0
		)
		if direction.length_squared() > 0.1:
			drone.rotation.y = lerp_angle(
				drone.rotation.y,
				atan2(direction.x, direction.z),
				delta * 8.0
			)
		if flat.length() <= 1.2 and _attack_cooldowns[index] <= 0.0:
			player.apply_damage_and_knockback(drone.global_position, 5.5, damage)
			_attack_cooldowns[index] = 1.15


func finish_round() -> void:
	_active = false
	for drone in _drones:
		drone.visible = false


func _build_drone(index: int) -> Node3D:
	var root := Node3D.new()
	root.name = "HunterDrone%02d" % index
	var shell_material := StandardMaterial3D.new()
	shell_material.albedo_color = Color(0.12, 0.16, 0.2)
	shell_material.metallic = 0.62
	shell_material.roughness = 0.36
	var eye_material := StandardMaterial3D.new()
	eye_material.albedo_color = Color(1.0, 0.16, 0.05)
	eye_material.emission_enabled = true
	eye_material.emission = Color(0.8, 0.03, 0.0)
	eye_material.emission_energy_multiplier = 1.5
	var body_mesh := SphereMesh.new()
	body_mesh.radius = 0.52
	body_mesh.height = 0.82
	body_mesh.radial_segments = 10
	body_mesh.rings = 6
	var body := MeshInstance3D.new()
	body.mesh = body_mesh
	body.scale = Vector3(1.25, 0.72, 1.0)
	body.material_override = shell_material
	body.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(body)
	var eye_mesh := SphereMesh.new()
	eye_mesh.radius = 0.13
	eye_mesh.height = 0.26
	eye_mesh.radial_segments = 8
	eye_mesh.rings = 4
	var eye := MeshInstance3D.new()
	eye.mesh = eye_mesh
	eye.position = Vector3(0.0, 0.02, 0.43)
	eye.material_override = eye_material
	eye.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(eye)
	for side in [-1.0, 1.0]:
		var rotor_mesh := CylinderMesh.new()
		rotor_mesh.top_radius = 0.42
		rotor_mesh.bottom_radius = 0.42
		rotor_mesh.height = 0.035
		rotor_mesh.radial_segments = 8
		var rotor := MeshInstance3D.new()
		rotor.mesh = rotor_mesh
		rotor.position = Vector3(side * 0.75, 0.05, 0.0)
		rotor.material_override = shell_material
		rotor.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(rotor)
	return root
