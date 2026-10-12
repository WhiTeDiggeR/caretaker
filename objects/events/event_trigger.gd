class_name EventTrigger
extends Area3D

## Starts an EventSequence (#133): when the player enters the area (AREA), when a
## StateRules condition starts to hold (CONDITION, checked on GameState changes, no
## per-frame polling) or from code and other nodes' signals (CALL → `fire()`).

enum Mode { AREA, CONDITION, CALL }

const PLAYER_GROUP := &"player"

@export var sequence: EventSequence
@export var mode: Mode = Mode.AREA
## StateRules condition as JSON for CONDITION, e.g. {"flag": "generator/started"}.
@export_multiline var condition_json := ""

var _condition: Dictionary = {}


func _ready() -> void:
	if sequence == null:
		push_error("EventTrigger %s: no sequence" % get_path())
		return
	monitoring = mode == Mode.AREA
	monitorable = false
	match mode:
		Mode.AREA:
			body_entered.connect(_on_body_entered)
		Mode.CONDITION:
			var parsed: Variant = JSON.parse_string(condition_json)
			if not parsed is Dictionary:
				push_error("EventTrigger %s: condition_json is not a JSON object" % get_path())
				return
			_condition = parsed
			GameState.flag_changed.connect(func(_flag: StringName, _value: Variant) -> void: _check.call_deferred())
			GameState.section_power_changed.connect(func(_section: StringName, _power: int) -> void: _check.call_deferred())
			GameState.access_changed.connect(func(_access: StringName, _granted: bool) -> void: _check.call_deferred())
			GameState.state_loaded.connect(_check.call_deferred)
			_check.call_deferred()


## Starts the sequence. Returns false when it is running or already done.
func fire() -> bool:
	return sequence != null and sequence.play()


func _on_body_entered(body: Node3D) -> void:
	if body.is_in_group(PLAYER_GROUP):
		fire()


func _check() -> void:
	if is_inside_tree() and sequence.can_play() and StateRules.check(_condition):
		fire()
