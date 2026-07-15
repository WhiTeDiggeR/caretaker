extends AudioStreamPlayer

const MIX_RATE := 22050.0

var _playback: AudioStreamGeneratorPlayback
var _sample_index := 0
var _clank_samples := 0
var _rng := RandomNumberGenerator.new()

func _ready() -> void:
	_rng.randomize()
	var generator := AudioStreamGenerator.new()
	generator.mix_rate = MIX_RATE
	generator.buffer_length = 0.5
	stream = generator
	play()
	_playback = get_stream_playback() as AudioStreamGeneratorPlayback

func _process(_delta: float) -> void:
	if not _playback:
		return
	var frame_count := _playback.get_frames_available()
	var frames := PackedVector2Array()
	frames.resize(frame_count)
	for index in frame_count:
		var time := float(_sample_index) / MIX_RATE
		var hum := sin(TAU * 48.0 * time) * 0.11 + sin(TAU * 96.0 * time) * 0.035
		var ventilation := sin(TAU * 0.17 * time) * 0.025
		var air_noise := _rng.randf_range(-0.012, 0.012)
		if _clank_samples <= 0 and _rng.randf() < 1.0 / (MIX_RATE * 14.0):
			_clank_samples = 5200
		var clank := 0.0
		if _clank_samples > 0:
			var envelope := float(_clank_samples) / 5200.0
			clank = sin(TAU * 690.0 * time) * envelope * 0.12
			_clank_samples -= 1
		var sample: float = clampf(hum + ventilation + air_noise + clank, -0.8, 0.8)
		frames[index] = Vector2(sample, sample * 0.96)
		_sample_index += 1
	_playback.push_buffer(frames)

func _exit_tree() -> void:
	stop()
	_playback = null
	stream = null
