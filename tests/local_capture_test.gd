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
	_lab.player.global_position = Vector3(0.0, 0.02, 8.0)
	for frame in 30:
		await physics_frame
	await _capture_from(
		"01_isla_limpia",
		Vector3(18.0, 16.0, 22.0),
		Vector3(0.0, 0.0, 0.0)
	)
	await _capture_from(
		"02_personaje_escala",
		Vector3(4.2, 1.05, 4.2),
		Vector3(0.0, 0.9, 8.0)
	)

	_lab.round_controller.duration_multiplier = 0.08
	_lab.start_reference_round(4242)
	while _lab.round_controller.phase != LocalRoundController.Phase.RULES:
		await physics_frame
	await _capture_from(
		"03_cancha_dos_arcos",
		Vector3(20.0, 17.0, 5.0),
		Vector3(0.0, 0.0, -20.0)
	)
	while _lab.round_controller.phase != LocalRoundController.Phase.ACTIVE:
		await physics_frame
	var player_camera := _lab.player.get_node(
		"CameraPivot/SpringArm/Camera"
	) as Camera3D
	_camera.current = false
	player_camera.current = true
	for frame in 4:
		await process_frame
	await _capture_current("04_primera_persona_mira")
	player_camera.current = false
	_camera.current = true
	_lab.reset_lab()
	for frame in 20:
		await physics_frame
	await _capture_from(
		"05_fin_limpio",
		Vector3(22.0, 20.0, 22.0),
		Vector3(0.0, 0.0, 0.0)
	)
	print(
		"LOCAL_CAPTURE_OK directory=%s captures=5 renderer=%s"
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
	await _capture_current(capture_name)


func _capture_current(capture_name: String) -> void:
	var image := root.get_texture().get_image()
	var output_path := "%s/%s.png" % [_output_directory, capture_name]
	var error := image.save_png(output_path)
	if error != OK:
		push_error("LOCAL_CAPTURE_FAIL: %s error=%d" % [output_path, error])
		quit(1)
