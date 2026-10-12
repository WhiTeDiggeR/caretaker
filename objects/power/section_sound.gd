class_name SectionSound
extends PowerConsumer

## Plays a loop that depends on section power, e.g. alarm on emergency power and machine
## hum on main power. Without streams set, a placeholder alarm is generated for emergency
## power; main power stays silent unless a stream is given (the generated 50 Hz hum of the
## lamps was tiring, author feedback #126).

@export var player: Node
@export var main_stream: AudioStream
@export var emergency_stream: AudioStream
@export var use_placeholder_tones := true
## The generated mains hum for main power; off by default.
@export var use_placeholder_hum := false


func _ready() -> void:
	if player == null:
		player = get_parent()
	if use_placeholder_tones:
		if main_stream == null and use_placeholder_hum:
			main_stream = PlaceholderTones.hum()
		if emergency_stream == null:
			emergency_stream = PlaceholderTones.alarm()
	super()


func current_stream() -> AudioStream:
	return player.get("stream")


func _apply_power(power: int, _instant: bool) -> void:
	var stream: AudioStream = null
	match power:
		GameState.Power.MAIN:
			stream = main_stream
		GameState.Power.EMERGENCY:
			stream = emergency_stream
	if stream == null:
		player.call("stop")
		player.set("stream", null)
		return
	if player.get("stream") != stream or not player.call("is_playing"):
		player.set("stream", stream)
		player.call("play")
