class_name DreamCombatHud
extends CanvasLayer

## Dream-only HUD: resolve and focus bars and the weapon keys. A hit plays the `dream_hit`
## screen effect (data/feel/screen_effects.json).

const RESOLVE_COLOR := Color(0.85, 0.3, 0.25)
const FOCUS_COLOR := Color(0.4, 0.75, 1.0)
const HURT_EFFECT := &"dream_hit"
const MOUSE_NAMES := {MOUSE_BUTTON_LEFT: "ЛКМ", MOUSE_BUTTON_RIGHT: "ПКМ", MOUSE_BUTTON_MIDDLE: "СКМ"}

var resolve_bar: ProgressBar
var focus_bar: ProgressBar
var weapons_label: Label
var _combat: DreamCombat


func _ready() -> void:
	layer = 5
	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	box.offset_left = -340.0
	box.offset_right = -24.0
	box.offset_top = -120.0
	box.offset_bottom = -24.0
	box.add_theme_constant_override(&"separation", 6)
	add_child(box)
	resolve_bar = _bar(box, "УСТОЙЧИВОСТЬ", RESOLVE_COLOR)
	focus_bar = _bar(box, "СОСРЕДОТОЧЕННОСТЬ", FOCUS_COLOR)
	weapons_label = Label.new()
	weapons_label.add_theme_color_override(&"font_outline_color", Color.BLACK)
	weapons_label.add_theme_constant_override(&"outline_size", 4)
	box.add_child(weapons_label)


func bind(combat: DreamCombat) -> void:
	_combat = combat
	combat.resolve_changed.connect(func(value: float, maximum: float) -> void: _show(resolve_bar, value, maximum))
	combat.focus_changed.connect(func(value: float, maximum: float) -> void: _show(focus_bar, value, maximum))
	combat.weapon_added.connect(func(_id: StringName) -> void: _refresh_weapons())
	combat.hurt.connect(func(_amount: float) -> void: ScreenEffects.play(HURT_EFFECT))
	_show(resolve_bar, combat.resolve, combat.max_resolve)
	_show(focus_bar, combat.focus, combat.max_focus)
	_refresh_weapons()


## «ЛКМ — Клинок сна · ПКМ — Импульс», or a hint to look for images.
func weapons_text() -> String:
	if _combat == null or _combat.weapons.is_empty():
		return "Оружия нет — ищите образы сна"
	var parts := PackedStringArray()
	for id in _combat.weapons:
		var weapon := DreamCombatData.weapon(id)
		parts.append("%s — %s" % [key_name(StringName(str(weapon.get("action", "")))), weapon.get("title", id)])
	return " · ".join(parts)


static func key_name(action: StringName) -> String:
	if not InputMap.has_action(action):
		return String(action)
	var events := InputMap.action_get_events(action)
	if not events.is_empty() and events[0] is InputEventMouseButton:
		return MOUSE_NAMES.get((events[0] as InputEventMouseButton).button_index, "мышь")
	return InputPromptFormatter.action_label(action)


func _refresh_weapons() -> void:
	weapons_label.text = weapons_text()


func _bar(parent: Control, title: String, color: Color) -> ProgressBar:
	var label := Label.new()
	label.text = title
	label.add_theme_font_size_override(&"font_size", 14)
	label.add_theme_color_override(&"font_outline_color", Color.BLACK)
	label.add_theme_constant_override(&"outline_size", 4)
	parent.add_child(label)
	var bar := ProgressBar.new()
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(0, 10)
	var fill := StyleBoxFlat.new()
	fill.bg_color = color
	bar.add_theme_stylebox_override(&"fill", fill)
	var back := StyleBoxFlat.new()
	back.bg_color = Color(0, 0, 0, 0.5)
	bar.add_theme_stylebox_override(&"background", back)
	parent.add_child(bar)
	return bar


func _show(bar: ProgressBar, value: float, maximum: float) -> void:
	bar.max_value = maximum
	bar.value = value
