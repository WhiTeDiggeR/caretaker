class_name SandboxStand
extends OpeningSandbox

## One test stand of the sandbox (#239): a single feature in its own small scene built on
## stand_base.tscn. Its entry in data/debug/stands.json (found by the scene path) gives the
## title, what to check — shown on a plate in the top-right corner, H hides it — and the
## progress state set on load on top of the sandbox defaults. Debug keys and the module 4
## overlay are the sandbox's (OpeningSandbox); F3 brings the stand back to its starting state.

const SIGN_KEY := KEY_H
const SIGN_MARGIN := 16.0
const SIGN_WIDTH := 460.0
const SIGN_TITLE_SIZE := 22
const SIGN_TEXT_SIZE := 17
const SIGN_PLATE := Color(0.05, 0.06, 0.07, 0.78)

var stand: Dictionary = {}
## The «что проверить» list of the plate.
var sign_label: Label

var _sign_layer: CanvasLayer


func _ready() -> void:
	stand = DebugStands.find(scene_file_path)
	if stand.is_empty():
		push_warning("SandboxStand: %s is not in %s" % [scene_file_path, DebugStands.DATA_PATH])
	super()
	_build_sign()


func reset_state() -> void:
	GameState.reset()
	GameState.set_flag(INITIALIZED_FLAG)
	for section in SECTIONS:
		GameState.set_section_power(section, GameState.Power.EMERGENCY)
	GameState.set_section_power(&"sandbox_event", GameState.Power.MAIN)
	GameState.set_flag(&"containment_online")
	DebugMoments.apply_state(stand.get("state", {}))


func _unhandled_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key and key.pressed and not key.echo and key.keycode == SIGN_KEY:
		_sign_layer.visible = not _sign_layer.visible
		get_viewport().set_input_as_handled()
		return
	super(event)


## The «что проверить» plate in the top-right corner (the objective takes the top-left).
func _build_sign() -> void:
	_sign_layer = CanvasLayer.new()
	_sign_layer.name = &"CheckSign"
	# Kept out of save thumbnails like the HUD.
	_sign_layer.add_to_group(Saves.HUD_GROUP)
	add_child(_sign_layer)
	var plate := PanelContainer.new()
	var box := StyleBoxFlat.new()
	box.bg_color = SIGN_PLATE
	box.border_color = UiStyle.ACCENT
	box.border_width_left = 3
	box.set_content_margin_all(12.0)
	plate.add_theme_stylebox_override(&"panel", box)
	plate.custom_minimum_size = Vector2(SIGN_WIDTH, 0)
	plate.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT, Control.PRESET_MODE_MINSIZE, SIGN_MARGIN)
	plate.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_sign_layer.add_child(plate)
	var column := VBoxContainer.new()
	plate.add_child(column)
	var title := Label.new()
	title.text = str(stand.get("title", "")).to_upper()
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title.add_theme_font_override(&"font", UiStyle.FONT_DISPLAY)
	title.add_theme_font_size_override(&"font_size", SIGN_TITLE_SIZE)
	title.add_theme_color_override(&"font_color", UiStyle.ACCENT)
	column.add_child(title)
	sign_label = Label.new()
	sign_label.text = DebugStands.sign_text(stand)
	sign_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	sign_label.add_theme_font_override(&"font", UiStyle.FONT_BODY)
	sign_label.add_theme_font_size_override(&"font_size", SIGN_TEXT_SIZE)
	sign_label.add_theme_color_override(&"font_color", UiStyle.TEXT)
	column.add_child(sign_label)
