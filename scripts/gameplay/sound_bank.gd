class_name SoundBank
extends Node

@onready var warning_player: AudioStreamPlayer = $Warning
@onready var impact_player: AudioStreamPlayer = $Impact
@onready var shockwave_player: AudioStreamPlayer = $Shockwave
@onready var success_player: AudioStreamPlayer = $Success

const MIX_RATE := 11025


func _ready() -> void:
	warning_player.stream = _make_tone(620.0, 0.16, 0.55, 0.82)
	impact_player.stream = _make_impact(0.34, 0.72)
	shockwave_player.stream = _make_shockwave()
	success_player.stream = _make_success()


func play_warning() -> void:
	warning_player.play()


func play_impact() -> void:
	impact_player.play()


func play_shockwave() -> void:
	shockwave_player.play()


func play_success() -> void:
	success_player.play()


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


func _build_stream(data: PackedByteArray) -> AudioStreamWAV:
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_8_BITS
	stream.mix_rate = MIX_RATE
	stream.stereo = false
	stream.data = data
	return stream
