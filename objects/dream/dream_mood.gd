class_name DreamMood
extends WorldEnvironment

## Tints the dream by the instability stage of its sleeper (canon: instability distorts the
## world of the dream). Calm — even warm light; pre-awakening — dark red sky and thick haze.

const SKY_BY_STAGE: Array[Color] = [
	Color(0.85, 0.55, 0.3), Color(0.7, 0.35, 0.2), Color(0.5, 0.2, 0.15), Color(0.35, 0.08, 0.08), Color(0.2, 0.02, 0.02),
]
const FOG_BY_STAGE: Array[float] = [0.002, 0.008, 0.02, 0.04, 0.06]


func _ready() -> void:
	environment = environment.duplicate()
	Containment.stage_changed.connect(func(id: StringName, _stage: int) -> void:
		if id == Dreams.module_id:
			apply())
	apply()


func apply() -> void:
	var stage := Containment.get_stage(Dreams.module_id) if Dreams.module_id != &"" else 0
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = SKY_BY_STAGE[stage]
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = SKY_BY_STAGE[stage].lightened(0.3)
	environment.fog_enabled = true
	environment.fog_light_color = SKY_BY_STAGE[stage]
	environment.fog_density = FOG_BY_STAGE[stage]
