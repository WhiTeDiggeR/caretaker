class_name PlaceholderTones
extends RefCounted

## Short generated loops used until real sound assets exist.

const MIX_RATE := 22050

static var _hum: AudioStreamWAV
static var _alarm: AudioStreamWAV


## Low machine hum (1 s loop).
static func hum() -> AudioStreamWAV:
	if _hum == null:
		_hum = _render(1.0, func(t: float) -> float:
			return sin(TAU * 50.0 * t) * 0.18 + sin(TAU * 100.0 * t) * 0.07 + sin(TAU * 150.0 * t) * 0.03)
	return _hum


## Two-tone alarm with a pause (1.6 s loop).
static func alarm() -> AudioStreamWAV:
	if _alarm == null:
		_alarm = _render(1.6, func(t: float) -> float:
			if t > 1.2:
				return 0.0
			var frequency := 620.0 if fmod(t, 0.6) < 0.3 else 820.0
			var envelope := minf(1.0, minf(t, 1.2 - t) * 40.0)
			return signf(sin(TAU * frequency * t)) * 0.08 * envelope)
	return _alarm


static func _render(seconds: float, wave: Callable) -> AudioStreamWAV:
	var frames := int(MIX_RATE * seconds)
	var data := PackedByteArray()
	data.resize(frames * 2)
	for index in frames:
		data.encode_s16(index * 2, int(clampf(wave.call(float(index) / MIX_RATE), -1.0, 1.0) * 32767.0))
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = MIX_RATE
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_end = frames
	stream.data = data
	return stream
