class_name OldPlate
extends StaticBody3D

## Cast plate of the old (second) queue of the lower floor (#229). Its narrow numerals match the
## plate «2» from the interdream: once the hero has seen that trace (`part2/dream_trace_2`), an
## inspection recognises the font and points along the trunk line to post 2
## (`part2/plate_compared`). Before the trace it is just an old plate; nothing is locked by it.

const TRACE_FLAG := &"part2/dream_trace_2"
const COMPARED_FLAG := &"part2/plate_compared"
const PLAIN_TEXT_ID := "part2_old_plate"
const COMPARED_TEXT_ID := "part2_old_plate_compared"

@export var plate_text := "2":
	set(value):
		plate_text = value
		if is_node_ready():
			_label.text = value

@onready var _label: Label3D = $Label
@onready var _interactable: Interactable = $Interactable


func _ready() -> void:
	_label.text = plate_text
	_interactable.interacted.connect(_on_interacted)
	GameState.flag_changed.connect(func(flag: StringName, _value: Variant) -> void:
		if flag == TRACE_FLAG:
			_refresh())
	GameState.state_loaded.connect(_refresh)
	_refresh()


func _refresh() -> void:
	_interactable.inspect_text_id = COMPARED_TEXT_ID if GameState.has_flag(TRACE_FLAG) else PLAIN_TEXT_ID


func _on_interacted() -> void:
	if GameState.has_flag(TRACE_FLAG):
		GameState.set_flag(COMPARED_FLAG)
