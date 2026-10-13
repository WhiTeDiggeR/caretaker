class_name ReviewReturn
extends CanvasLayer

## Way back to the review hall (#192): lives under the tree root once the hall has been
## opened, so it outlasts scene changes. F9 loads the hall from any station; a corner line
## reminds of the key outside the hall.

const NODE_NAME := &"ReviewReturn"
const RETURN_KEY := KEY_F9
const LAYER := 105
const HINT := "F9 — в смотровую"

var _hint: Label


## Adds the node to the root unless it is already there.
static func ensure(tree: SceneTree) -> ReviewReturn:
	var existing := tree.root.get_node_or_null(NodePath(String(NODE_NAME))) as ReviewReturn
	if existing:
		return existing
	var node := ReviewReturn.new()
	node.name = NODE_NAME
	tree.root.add_child.call_deferred(node)
	return node


func _ready() -> void:
	layer = LAYER
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group(Saves.HUD_GROUP)
	_hint = Label.new()
	_hint.text = HINT
	_hint.add_theme_color_override(&"font_color", Color(1.0, 0.8, 0.4))
	_hint.add_theme_color_override(&"font_outline_color", Color.BLACK)
	_hint.add_theme_constant_override(&"outline_size", 4)
	add_child(_hint)
	_hint.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT, Control.PRESET_MODE_MINSIZE, 16)
	_hint.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	get_tree().scene_changed.connect(_refresh)
	_refresh()


## Loads the hall; false while a load or a moment is under way.
func go_back() -> bool:
	if Shell.loading or Debug.busy:
		return false
	Shell.change_scene(ReviewHub.SCENE)
	return true


func _refresh() -> void:
	var scene := get_tree().current_scene
	_hint.visible = scene != null and scene.scene_file_path != ReviewHub.SCENE


func _input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key and key.pressed and not key.echo and key.keycode == RETURN_KEY:
		if go_back():
			get_viewport().set_input_as_handled()
