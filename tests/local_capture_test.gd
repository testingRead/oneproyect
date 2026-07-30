extends SceneTree

const LAB_SCENE := preload("res://scenes/local/local_lab.tscn")

var _lab: LocalDevelopmentLab
var _camera: Camera3D
var _output_directory := "/tmp/oneproyect-local-captures"


func _init() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--output-dir="):
			_output_directory = argument.trim_prefix("--output-dir=")
	call_deferred("_run")


func _run() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("LOCAL_CAPTURE_FAIL: a real display driver is required")
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute(_output_directory)
	_lab = LAB_SCENE.instantiate() as LocalDevelopmentLab
	root.add_child(_lab)
	await process_frame
	(_lab.player.get_node("CameraPivot/SpringArm/Camera") as Camera3D).current = false
	_camera = Camera3D.new()
	_camera.name = "ValidationCamera"
	_camera.fov = 58.0
	_camera.near = 0.03
	_camera.far = 180.0
	_camera.current = true
	_lab.get_node("World").add_child(_camera)
	_lab.player.controls_enabled = false
	_lab.player.global_position = Vector3.ZERO
	for frame in 30:
		await physics_frame

	await _capture_from(
		"01_personaje_frontal",
		Vector3(0.0, 1.05, 4.2),
		Vector3(0.0, 0.9, 0.0)
	)
	await _capture_from(
		"02_personaje_lateral",
		Vector3(4.2, 1.05, 0.0),
		Vector3(0.0, 0.9, 0.0)
	)
	await _capture_from(
		"03_pies_en_suelo",
		Vector3(2.1, 0.32, 2.0),
		Vector3(0.0, 0.16, 0.0)
	)

	_lab.player.controls_enabled = true
	_lab.player.set_touch_move(Vector2(0.0, -1.0))
	for frame in 75:
		await physics_frame
		var arm := _lab.player.get_node(
			"VisualRoot/Model/LeftArmPivot"
		) as Node3D
		if absf(arm.rotation.x) > 0.54:
			break
	var running_position := _lab.player.global_position
	await _capture_from(
		"04_personaje_corriendo",
		running_position + Vector3(4.0, 1.35, 1.6),
		running_position + Vector3(0.0, 0.9, 0.0)
	)
	_lab.player.set_touch_move(Vector2.ZERO)
	_lab.player.request_jump()
	for frame in 18:
		await physics_frame
	var jumping_position := _lab.player.global_position
	await _capture_from(
		"05_personaje_saltando",
		jumping_position + Vector3(3.6, 1.0, 4.0),
		jumping_position + Vector3(0.0, 0.7, 0.0)
	)

	_lab.player.controls_enabled = false
	_lab.player.global_position = Vector3(-7.0, 2.2, 3.0)
	_lab.player.velocity = Vector3.ZERO
	for frame in 90:
		await physics_frame
	await _capture_from(
		"06_personaje_en_pendiente",
		Vector3(-2.8, 1.8, 6.8),
		_lab.player.global_position + Vector3(0.0, 0.8, 0.0)
	)

	_lab.set_playable_area_index(0)
	await _capture_from(
		"07_limite_pequeno",
		Vector3(22.0, 25.0, 22.0),
		Vector3.ZERO
	)
	_lab.set_playable_area_index(2)
	await _capture_from(
		"08_limite_grande",
		Vector3(64.0, 72.0, 64.0),
		Vector3.ZERO
	)

	var medium_box := _lab.get_node("World/TestCourse/MediumBox") as RigidBody3D
	medium_box.apply_central_impulse(Vector3(-4.0, 3.0, -2.0))
	for frame in 12:
		await physics_frame
	await _capture_from(
		"09_objeto_impactando",
		Vector3(10.0, 4.0, 10.0),
		Vector3(4.5, 0.8, 3.0)
	)
	_lab.round_controller.duration_multiplier = 0.08
	_lab.start_reference_round(4242)
	while _lab.round_controller.phase != LocalRoundController.Phase.IDLE:
		await physics_frame
	await _capture_from(
		"10_fin_de_ronda_limpio",
		Vector3(22.0, 24.0, 22.0),
		Vector3.ZERO
	)
	print(
		"LOCAL_CAPTURE_OK directory=%s captures=10 renderer=%s"
		% [_output_directory, RenderingServer.get_rendering_device() == null]
	)
	quit(0)


func _capture_from(
	capture_name: String,
	camera_position: Vector3,
	target: Vector3
) -> void:
	_camera.global_position = camera_position
	_camera.look_at(target, Vector3.UP)
	for frame in 4:
		await process_frame
	var image := root.get_texture().get_image()
	var output_path := "%s/%s.png" % [_output_directory, capture_name]
	var error := image.save_png(output_path)
	if error != OK:
		push_error("LOCAL_CAPTURE_FAIL: %s error=%d" % [output_path, error])
		quit(1)
