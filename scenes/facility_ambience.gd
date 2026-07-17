extends AudioStreamPlayer

const MIX_RATE := 22050
const LOOP_SECONDS := 14.0
const CLANK_DURATION_SAMPLES := 5200
const STEREO_FRAME_BYTES := 4


func _ready() -> void:
	stream = _create_ambience_stream()
	play()


func _exit_tree() -> void:
	stop()
	stream = null


func _create_ambience_stream() -> AudioStreamWAV:
	var rng := RandomNumberGenerator.new()
	rng.randomize()

	var frame_count := int(MIX_RATE * LOOP_SECONDS)
	var data := PackedByteArray()
	data.resize(frame_count * STEREO_FRAME_BYTES)
	var clank_samples := 0

	for index in frame_count:
		var time := float(index) / MIX_RATE
		var hum := sin(TAU * 48.0 * time) * 0.11 + sin(TAU * 96.0 * time) * 0.035
		var ventilation := sin(TAU * 0.17 * time) * 0.025
		var air_noise := rng.randf_range(-0.012, 0.012)
		if clank_samples <= 0 and rng.randf() < 1.0 / (MIX_RATE * 14.0):
			clank_samples = CLANK_DURATION_SAMPLES

		var clank := 0.0
		if clank_samples > 0:
			var envelope := float(clank_samples) / CLANK_DURATION_SAMPLES
			clank = sin(TAU * 690.0 * time) * envelope * 0.12
			clank_samples -= 1

		var left_sample := int(clampf(hum + ventilation + air_noise + clank, -0.8, 0.8) * 32767.0)
		var right_sample := int(left_sample * 0.96)
		var byte_offset := index * STEREO_FRAME_BYTES
		data.encode_s16(byte_offset, left_sample)
		data.encode_s16(byte_offset + 2, right_sample)

	var ambience := AudioStreamWAV.new()
	ambience.format = AudioStreamWAV.FORMAT_16_BITS
	ambience.mix_rate = MIX_RATE
	ambience.stereo = true
	ambience.loop_mode = AudioStreamWAV.LOOP_FORWARD
	ambience.loop_begin = 0
	ambience.loop_end = frame_count
	ambience.data = data
	return ambience
