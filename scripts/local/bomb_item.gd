class_name LocalBombItem
extends Area3D

signal exploded

@export var fuse_seconds := 22.0
var _remaining := fuse_seconds
var _active := false
var _authoritative := true
var _time_scale := 1.0
var _beep_cooldown := 0.0
var _playback: AudioStreamGeneratorPlayback
@onready var fuse_light: OmniLight3D = $FuseLight
@onready var fuse_tip: MeshInstance3D = $FuseTip


func _ready() -> void:
	add_to_group(&"bomb_collectible")
	var generator := AudioStreamGenerator.new()
	generator.mix_rate = 22050.0
	generator.buffer_length = 0.12
	$Beep.stream = generator
	$Beep.play()
	_playback = $Beep.get_stream_playback() as AudioStreamGeneratorPlayback


func arm(authoritative := true, time_scale := 1.0, initial_remaining := -1.0) -> void:
	_authoritative = authoritative
	_time_scale = maxf(0.01, time_scale)
	_remaining = fuse_seconds if initial_remaining < 0.0 else clampf(initial_remaining, 0.0, fuse_seconds)
	_active = true


func synchronize_remaining(remaining: float) -> void:
	_remaining = clampf(remaining, 0.0, fuse_seconds)
	_active = _remaining > 0.0


func get_remaining() -> float:
	return _remaining


func get_urgency() -> float:
	return 1.0 - _remaining / fuse_seconds


func _process(delta: float) -> void:
	if not _active:
		return
	_remaining = maxf(0.0, _remaining - delta / _time_scale)
	var urgency := 1.0 - _remaining / fuse_seconds
	_beep_cooldown -= delta
	if _beep_cooldown <= 0.0:
		_beep_cooldown = lerpf(0.82, 0.11, urgency)
		_emit_beep(lerpf(420.0, 980.0, urgency))
	var pulse := 0.55 + sin(Time.get_ticks_msec() * 0.022) * 0.45
	fuse_light.light_energy = lerpf(0.5, 3.2, urgency) * pulse
	fuse_tip.scale = Vector3.ONE * lerpf(0.6, 1.25, urgency * pulse)
	if _remaining <= 0.0 and _authoritative:
		_active = false
		exploded.emit()


func _emit_beep(frequency: float) -> void:
	if _playback == null:
		return
	var frames := mini(900, _playback.get_frames_available())
	for frame in frames:
		var value := sin(TAU * frequency * float(frame) / 22050.0) * 0.24
		_playback.push_frame(Vector2(value, value))
