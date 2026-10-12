extends SceneTree

## Builds one AudioStreamRandomizer per footstep sound from the sliced single steps
## (loads/audio/cc0/steps/<id>_NN.wav, made by tools/audio/cc0_sounds.py).
## Run after the WAVs are imported:
##   godot --headless --path . --script res://tools/audio/build_randomizers.gd

const STEPS_DIR := "res://loads/audio/cc0/steps"
const IDS: Array[String] = ["step_concrete", "step_grate", "step_metal", "step_ladder"]


func _initialize() -> void:
	var failed := false
	for id in IDS:
		var files: Array[String] = []
		for file in DirAccess.get_files_at(STEPS_DIR):
			if file.begins_with(id + "_") and file.ends_with(".wav"):
				files.append(file)
		files.sort()
		var randomizer := AudioStreamRandomizer.new()
		randomizer.playback_mode = AudioStreamRandomizer.PLAYBACK_RANDOM_NO_REPEATS
		randomizer.random_pitch = 1.0  # pitch variation comes from the catalogue's pitch_jitter
		randomizer.random_volume_offset_db = 1.5
		for file in files:
			var stream := load("%s/%s" % [STEPS_DIR, file]) as AudioStream
			if stream == null:
				push_error("cannot load %s" % file)
				failed = true
				continue
			randomizer.add_stream(-1, stream)
		var path := "%s/%s.tres" % [STEPS_DIR, id]
		if ResourceSaver.save(randomizer, path) != OK:
			push_error("cannot save %s" % path)
			failed = true
		print("%s: %d steps" % [path, randomizer.streams_count])
	quit(1 if failed else 0)
