class_name DefeatScreen
extends CanvasLayer

## Defeat screen: the reason (data/shell/defeat.json) and the ways back — the last
## checkpoint (autosave), a chosen save or the main menu. Opened by Shell.defeat().

const DATA_PATH := "res://data/shell/defeat.json"
const FALLBACK := {"title": "ПОРАЖЕНИЕ", "text": ""}

var reason: StringName = &""
var checkpoint_button: Button
var load_button: Button


static func open(parent: Node, defeat_reason: StringName) -> DefeatScreen:
	var screen := DefeatScreen.new()
	screen.reason = defeat_reason
	screen.layer = 82
	screen.process_mode = Node.PROCESS_MODE_ALWAYS
	parent.add_child(screen)
	return screen


## Title and text of a defeat reason.
static func texts(defeat_reason: StringName) -> Dictionary:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(DATA_PATH))
	var all: Dictionary = parsed if parsed is Dictionary else {}
	return all.get(String(defeat_reason), FALLBACK)


func _ready() -> void:
	var data := texts(reason)
	var column := ShellUI.screen(self, str(data.get("title", FALLBACK["title"])), 640.0)
	var text := Label.new()
	text.text = str(data.get("text", ""))
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	text.add_theme_color_override(&"font_color", ShellUI.TEXT)
	column.add_child(text)
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 12)
	column.add_child(spacer)
	checkpoint_button = ShellUI.button(column, "Загрузить контрольную точку", load_checkpoint)
	checkpoint_button.disabled = not Saves.exists(Saves.AUTO)
	load_button = ShellUI.button(column, "Загрузить игру", func() -> void: SaveSlotsScreen.open(self, SaveSlotsScreen.Mode.LOAD))
	load_button.disabled = Saves.latest().is_empty()
	var menu_button := ShellUI.button(column, "В главное меню", Shell.main_menu)
	var first := checkpoint_button if not checkpoint_button.disabled else (load_button if not load_button.disabled else menu_button)
	first.grab_focus.call_deferred()


func load_checkpoint() -> void:
	Shell.load_game(Saves.AUTO)
