extends Node3D

@onready var player: GrayboxPlayer = $World/Player
@onready var disaster: DisasterController = $World/DisasterController
@onready var sounds: SoundBank = $SoundBank
@onready var fps_label: Label = $HUD/TopBar/FPS
@onready var health_label: Label = $HUD/TopBar/Health
@onready var round_title: Label = $HUD/RoundPanel/Title
@onready var round_detail: Label = $HUD/RoundPanel/Detail
@onready var round_clock: Label = $HUD/RoundPanel/Clock
@onready var pause_panel: Control = $HUD/PausePanel
@onready var pause_button: Button = $HUD/TopBar/Pause
@onready var touch_debug: Label = $HUD/TouchDebug

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
	player.health_changed.connect(_on_health_changed)
	player.defeated.connect(_on_player_defeated)
	disaster.state_changed.connect(_on_disaster_state_changed)
	disaster.clock_changed.connect(_on_disaster_clock_changed)
	disaster.round_survived.connect(_on_round_survived)
	disaster.meteor_warning.connect(sounds.play_warning)
	disaster.meteor_impact.connect(sounds.play_impact)
	_on_health_changed(100, 100)


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
	get_tree().paused = not get_tree().paused
	pause_panel.visible = get_tree().paused
	pause_button.text = "SEGUIR" if get_tree().paused else "PAUSA"
	if not OS.has_feature("mobile"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if get_tree().paused else Input.MOUSE_MODE_CAPTURED


func restart_level() -> void:
	get_tree().paused = false
	pause_panel.visible = false
	pause_button.text = "PAUSA"
	$HUD/PausePanel/Center/Title.text = "EN PAUSA"
	$HUD/PausePanel/Center/Resume.visible = true
	player.reset_to_spawn()
	disaster.restart_cycle()
	if not OS.has_feature("mobile"):
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _on_touch_move(value: Vector2) -> void:
	player.set_touch_move(value)
	touch_debug.text = "JOY  %.2f  %.2f" % [value.x, value.y]


func _on_health_changed(current: int, maximum: int) -> void:
	health_label.text = "VIDA  %d/%d" % [current, maximum]
	if current <= 35:
		health_label.modulate = Color(1.0, 0.4, 0.32)
	else:
		health_label.modulate = Color.WHITE


func _on_player_defeated() -> void:
	round_detail.text = "¡Te derribaron! Regresas a la plaza"
	player.reset_to_spawn()


func _on_disaster_state_changed(title: String, detail: String) -> void:
	round_title.text = title
	round_detail.text = detail


func _on_disaster_clock_changed(seconds_left: int) -> void:
	round_clock.text = "%02d" % seconds_left


func _on_round_survived(_round_number: int) -> void:
	sounds.play_success()
	player.heal_full()
