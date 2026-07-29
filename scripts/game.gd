extends Node3D

@onready var player: GrayboxPlayer = $World/Player
@onready var fps_label: Label = $HUD/TopBar/FPS
@onready var status_label: Label = $HUD/Status
@onready var pause_panel: Control = $HUD/PausePanel
@onready var pause_button: Button = $HUD/TopBar/Pause
@onready var touch_debug: Label = $HUD/TouchDebug

var _completed := false
var _stats_elapsed := 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	$HUD/Joystick.value_changed.connect(_on_touch_move)
	$HUD/LookPad.look_delta.connect(player.add_touch_look)
	$HUD/Jump.action_pressed.connect(player.request_jump)
	$HUD/TopBar/Pause.pressed.connect(toggle_pause)
	$HUD/TopBar/Restart.pressed.connect(restart_level)
	$HUD/PausePanel/Center/Resume.pressed.connect(toggle_pause)
	$HUD/PausePanel/Center/Restart.pressed.connect(restart_level)
	$World/Goal.body_entered.connect(_on_goal_body_entered)
	status_label.text = "OBJETIVO: LLEGA AL CILINDRO VERDE"


func _process(delta: float) -> void:
	_stats_elapsed += delta
	if _stats_elapsed >= 0.25:
		var fps := Engine.get_frames_per_second()
		var frame_ms := 1000.0 / maxf(float(fps), 1.0)
		fps_label.text = "%d FPS  %.1f ms" % [fps, frame_ms]
		_stats_elapsed = 0.0


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		toggle_pause()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("restart"):
		restart_level()
		get_viewport().set_input_as_handled()


func toggle_pause() -> void:
	if _completed:
		return
	get_tree().paused = not get_tree().paused
	pause_panel.visible = get_tree().paused
	pause_button.text = "SEGUIR" if get_tree().paused else "PAUSA"
	if not OS.has_feature("mobile"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if get_tree().paused else Input.MOUSE_MODE_CAPTURED


func restart_level() -> void:
	get_tree().paused = false
	_completed = false
	pause_panel.visible = false
	pause_button.text = "PAUSA"
	$HUD/PausePanel/Center/Title.text = "EN PAUSA"
	$HUD/PausePanel/Center/Resume.visible = true
	status_label.text = "OBJETIVO: LLEGA AL CILINDRO VERDE"
	player.reset_to_spawn()
	if not OS.has_feature("mobile"):
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _on_goal_body_entered(body: Node3D) -> void:
	if body != player or _completed:
		return
	_completed = true
	status_label.text = "¡OBJETIVO COMPLETADO!  PULSA REINICIAR"
	get_tree().paused = true
	pause_panel.visible = true
	$HUD/PausePanel/Center/Title.text = "¡OBJETIVO COMPLETADO!"
	$HUD/PausePanel/Center/Resume.visible = false
	if not OS.has_feature("mobile"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _on_touch_move(value: Vector2) -> void:
	player.set_touch_move(value)
	touch_debug.text = "JOY  %.2f  %.2f" % [value.x, value.y]
