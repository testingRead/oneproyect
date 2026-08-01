extends SceneTree

const LAB_SCENE := preload("res://scenes/local/local_lab.tscn")

var _lab: LocalDevelopmentLab
var _validation_camera: Camera3D
var _output_directory := "/tmp/oneproyect-shooter-captures"


func _init() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--output-dir="):
			_output_directory = argument.trim_prefix("--output-dir=")
	call_deferred("_run")


func _run() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("SHOOTER_CAPTURE_FAIL: a real display driver is required")
		quit(1)
		return
	ProjectSettings.set_setting(
		"oneproyect/session_minigame_path",
		"res://data/minigames/shooter_local.tres"
	)
	ProjectSettings.set_setting("oneproyect/session_auto_start", false)
	DirAccess.make_dir_recursive_absolute(_output_directory)
	_lab = LAB_SCENE.instantiate() as LocalDevelopmentLab
	root.add_child(_lab)
	await process_frame
	var player_camera := _lab.player.get_node("CameraPivot/SpringArm/Camera") as Camera3D
	player_camera.current = false
	_validation_camera = Camera3D.new()
	_validation_camera.name = "ShooterValidationCamera"
	_validation_camera.fov = 58.0
	_validation_camera.current = true
	_lab.get_node("World").add_child(_validation_camera)
	_lab.round_controller.duration_multiplier = 0.12
	_lab.start_reference_round(9000)
	while _lab.round_controller.phase != LocalRoundController.Phase.RULES:
		await physics_frame
	await _capture_from(
		"01_arena_completa",
		Vector3(24.0, 22.0, 12.0),
		Vector3(0.0, 0.0, -20.0)
	)
	while _lab.round_controller.phase != LocalRoundController.Phase.ACTIVE:
		await physics_frame
	for frame in 12:
		await physics_frame
	await _capture_from(
		"02_coberturas_y_rivales",
		Vector3(12.0, 6.0, -5.0),
		Vector3(0.0, 1.0, -20.0)
	)
	_validation_camera.current = false
	player_camera.current = true
	for frame in 4:
		await process_frame
	await _capture_current("03_primera_persona_arma")
	_lab.shooter_host.request_shot()
	for frame in 2:
		await process_frame
	await _capture_current("04_retroceso_y_mira")
	player_camera.current = false
	_validation_camera.current = true
	_lab.reset_lab()
	for frame in 16:
		await physics_frame
	await _capture_from(
		"05_limpieza_total",
		Vector3(18.0, 16.0, 22.0),
		Vector3.ZERO
	)
	print("SHOOTER_CAPTURE_OK directory=%s captures=5" % _output_directory)
	quit(0)


func _capture_from(name_value: String, position_value: Vector3, target: Vector3) -> void:
	_validation_camera.global_position = position_value
	_validation_camera.look_at(target, Vector3.UP)
	for frame in 4:
		await process_frame
	await _capture_current(name_value)


func _capture_current(name_value: String) -> void:
	var image := root.get_texture().get_image()
	var path := "%s/%s.png" % [_output_directory, name_value]
	var error := image.save_png(path)
	if error != OK:
		push_error("SHOOTER_CAPTURE_FAIL: %s error=%d" % [path, error])
		quit(1)
