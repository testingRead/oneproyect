class_name SoundBank
extends Node

@onready var warning_player: AudioStreamPlayer = $Warning
@onready var impact_player: AudioStreamPlayer = $Impact
@onready var shockwave_player: AudioStreamPlayer = $Shockwave
@onready var success_player: AudioStreamPlayer = $Success
@onready var shot_player: AudioStreamPlayer = $Shot

const MIX_RATE := 11025

var _enabled := true
var _weapon_streams: Array[AudioStreamWAV] = []


func _ready() -> void:
	warning_player.stream = _make_tone(620.0, 0.16, 0.55, 0.82)
	impact_player.stream = _make_impact(0.34, 0.72)
	shockwave_player.stream = _make_shockwave()
	success_player.stream = _make_success()
	shot_player.stream = _make_shot()
	_weapon_streams = [_make_pistol(), _make_carbine(), _make_shotgun()]


func play_warning() -> void:
	if _enabled:
		warning_player.play()


func play_impact() -> void:
	if _enabled:
		impact_player.play()


func play_shockwave() -> void:
	if _enabled:
		shockwave_player.play()


func play_success() -> void:
	if _enabled:
		success_player.play()


func play_shot() -> void:
	if _enabled:
		shot_player.play()


func play_weapon_shot(weapon_id: int) -> void:
	if not _enabled:
		return
	shot_player.stream = _weapon_streams[clampi(weapon_id, 0, _weapon_streams.size() - 1)]
	shot_player.play()


func set_enabled(enabled: bool) -> void:
	_enabled = enabled
	if not enabled:
		warning_player.stop()
		impact_player.stop()
		shockwave_player.stop()
		success_player.stop()
		shot_player.stop()


func is_enabled() -> bool:
	return _enabled


func _make_tone(frequency: float, duration: float, volume: float, decay: float) -> AudioStreamWAV:
	var frame_count := int(MIX_RATE * duration)
	var data := PackedByteArray()
	data.resize(frame_count)
	for frame in frame_count:
		var time := float(frame) / MIX_RATE
		var envelope := pow(1.0 - float(frame) / frame_count, decay)
		var sample: float = sin(TAU * frequency * time) * envelope * volume
		data[frame] = int(clampf(sample * 127.0 + 128.0, 0.0, 255.0))
	return _build_stream(data)


func _make_impact(duration: float, volume: float) -> AudioStreamWAV:
	var frame_count := int(MIX_RATE * duration)
	var data := PackedByteArray()
	data.resize(frame_count)
	var noise_state := 73129
	for frame in frame_count:
		noise_state = (noise_state * 1103515245 + 12345) & 0x7fffffff
		var noise := float(noise_state % 2001 - 1000) / 1000.0
		var time := float(frame) / MIX_RATE
		var low_hit := sin(TAU * (82.0 - time * 90.0) * time)
		var envelope := pow(1.0 - float(frame) / frame_count, 2.6)
		var sample: float = (low_hit * 0.72 + noise * 0.28) * envelope * volume
		data[frame] = int(clampf(sample * 127.0 + 128.0, 0.0, 255.0))
	return _build_stream(data)


func _make_success() -> AudioStreamWAV:
	var duration := 0.55
	var frame_count := int(MIX_RATE * duration)
	var data := PackedByteArray()
	data.resize(frame_count)
	for frame in frame_count:
		var time := float(frame) / MIX_RATE
		var note: float = 523.25 if time < 0.18 else (659.25 if time < 0.36 else 783.99)
		var note_time: float = fmod(time, 0.18)
		var envelope: float = clampf(1.0 - note_time / 0.2, 0.0, 1.0)
		var sample: float = sin(TAU * note * time) * envelope * 0.48
		data[frame] = int(clampf(sample * 127.0 + 128.0, 0.0, 255.0))
	return _build_stream(data)


func _make_shockwave() -> AudioStreamWAV:
	var duration := 0.58
	var frame_count := int(MIX_RATE * duration)
	var data := PackedByteArray()
	data.resize(frame_count)
	for frame in frame_count:
		var progress := float(frame) / frame_count
		var time := float(frame) / MIX_RATE
		var frequency := lerpf(145.0, 46.0, progress)
		var envelope := pow(1.0 - progress, 1.45)
		var sample := sin(TAU * frequency * time) * envelope * 0.62
		data[frame] = int(clampf(sample * 127.0 + 128.0, 0.0, 255.0))
	return _build_stream(data)


func _make_shot() -> AudioStreamWAV:
	var duration := 0.14
	var frame_count := int(MIX_RATE * duration)
	var data := PackedByteArray()
	data.resize(frame_count)
	var noise_state := 918273
	for frame in frame_count:
		noise_state = (noise_state * 1103515245 + 12345) & 0x7fffffff
		var progress := float(frame) / frame_count
		var time := float(frame) / MIX_RATE
		var crack := sin(TAU * lerpf(820.0, 170.0, progress) * time)
		var noise := float(noise_state % 2001 - 1000) / 1000.0
		var envelope := pow(1.0 - progress, 3.2)
		var sample := (crack * 0.62 + noise * 0.38) * envelope * 0.72
		data[frame] = int(clampf(sample * 127.0 + 128.0, 0.0, 255.0))
	return _build_stream(data)


func _make_pistol() -> AudioStreamWAV:
	return _make_weapon_crack(0.13, 940.0, 190.0, 0.76, 0.34)


func _make_carbine() -> AudioStreamWAV:
	return _make_weapon_crack(0.11, 1250.0, 240.0, 0.68, 0.44)


func _make_shotgun() -> AudioStreamWAV:
	return _make_weapon_crack(0.27, 510.0, 72.0, 0.82, 0.58)


func _make_weapon_crack(
	duration: float,
	start_frequency: float,
	end_frequency: float,
	volume: float,
	noise_mix: float
) -> AudioStreamWAV:
	var frame_count := int(MIX_RATE * duration)
	var data := PackedByteArray()
	data.resize(frame_count)
	var noise_state := int(start_frequency * 913.0)
	for frame in frame_count:
		noise_state = (noise_state * 1103515245 + 12345) & 0x7fffffff
		var progress := float(frame) / frame_count
		var time := float(frame) / MIX_RATE
		var frequency := lerpf(start_frequency, end_frequency, progress)
		var tone := sin(TAU * frequency * time)
		var noise := float(noise_state % 2001 - 1000) / 1000.0
		var envelope := pow(1.0 - progress, 3.0 if duration < 0.2 else 2.1)
		var sample := lerpf(tone, noise, noise_mix) * envelope * volume
		data[frame] = int(clampf(sample * 127.0 + 128.0, 0.0, 255.0))
	return _build_stream(data)


func _build_stream(data: PackedByteArray) -> AudioStreamWAV:
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_8_BITS
	stream.mix_rate = MIX_RATE
	stream.stereo = false
	stream.data = data
	return stream
