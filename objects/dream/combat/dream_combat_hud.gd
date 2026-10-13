class_name DreamCombatHud
extends CanvasLayer

## Dream-only HUD of the fight (#127), in the dream style (issue #164): resolve and focus as
## thin meters in the sleeper's colours (DreamProfile) and the weapon keys under them,
## bottom left, clear of the save indicator, prompts and seal marks. A hit plays the
## `dream_hit` screen effect (data/feel/screen_effects.json) and leaves a trail on the meter.

const HURT_EFFECT := &"dream_hit"
const MOUSE_NAMES := {MOUSE_BUTTON_LEFT: "ЛКМ", MOUSE_BUTTON_RIGHT: "ПКМ", MOUSE_BUTTON_MIDDLE: "СКМ"}
const RESOLVE_CAPTION := "УСТОЙЧИВОСТЬ"
const FOCUS_CAPTION := "СОСРЕДОТОЧЕННОСТЬ"
const NO_WEAPONS := "Оружия нет — ищите образы сна"
const MARGIN := Vector2(40.0, 40.0)
const WIDTH := 300.0
const WEAPONS_SIZE := 17
const KEY_SIZE := 14
const GLOW_SIZE := 6

var resolve_meter: DreamMeter
var focus_meter: DreamMeter
var weapons_line: RichTextLabel
## Set before adding to the tree to show another sleeper's colours (the showroom does).
var profile: DreamProfile
var _combat: DreamCombat


func _ready() -> void:
	layer = 5
	if profile == null:
		profile = DreamProfile.current()
	var box := VBoxContainer.new()
	box.name = "Meters"
	box.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	box.grow_vertical = Control.GROW_DIRECTION_BEGIN
	box.offset_left = MARGIN.x
	box.offset_right = MARGIN.x + WIDTH
	box.offset_bottom = -MARGIN.y
	box.offset_top = -MARGIN.y
	box.add_theme_constant_override(&"separation", 10)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(box)
	resolve_meter = _meter(box, RESOLVE_CAPTION, profile.glow)
	focus_meter = _meter(box, FOCUS_CAPTION, profile.text)
	weapons_line = RichTextLabel.new()
	weapons_line.bbcode_enabled = true
	weapons_line.fit_content = true
	weapons_line.scroll_active = false
	weapons_line.autowrap_mode = TextServer.AUTOWRAP_OFF
	weapons_line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	weapons_line.add_theme_font_override(&"normal_font", UiStyle.FONT_BODY_ITALIC)
	weapons_line.add_theme_font_override(&"mono_font", UiStyle.FONT_MONO)
	weapons_line.add_theme_font_size_override(&"normal_font_size", WEAPONS_SIZE)
	weapons_line.add_theme_font_size_override(&"mono_font_size", KEY_SIZE)
	weapons_line.add_theme_color_override(&"default_color", profile.text)
	weapons_line.add_theme_color_override(&"font_outline_color", Color(profile.glow, 0.25))
	weapons_line.add_theme_constant_override(&"outline_size", GLOW_SIZE)
	box.add_child(weapons_line)


func bind(combat: DreamCombat) -> void:
	_combat = combat
	combat.resolve_changed.connect(resolve_meter.set_value)
	combat.focus_changed.connect(focus_meter.set_value)
	combat.weapon_added.connect(func(_id: StringName) -> void: show_weapons(combat.weapons))
	combat.hurt.connect(func(_amount: float) -> void: ScreenEffects.play(HURT_EFFECT))
	resolve_meter.reset(combat.resolve, combat.max_resolve)
	focus_meter.reset(combat.focus, combat.max_focus)
	show_weapons(combat.weapons)


## «ЛКМ — Клинок сна · ПКМ — Импульс», or a hint to look for images.
func weapons_text() -> String:
	if _combat == null or _combat.weapons.is_empty():
		return NO_WEAPONS
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


## The line of the weapons with the keys in mono, the titles in italics.
func show_weapons(ids: Array) -> void:
	if ids.is_empty():
		weapons_line.text = "[color=#%s]%s[/color]" % [Color(profile.text, 0.7).to_html(), NO_WEAPONS]
		return
	var parts := PackedStringArray()
	for id: StringName in ids:
		var weapon := DreamCombatData.weapon(id)
		parts.append("[code]%s[/code]  %s" % [key_name(StringName(str(weapon.get("action", "")))), str(weapon.get("title", id)).replace("[", "[lb]")])
	weapons_line.text = "   ·   ".join(parts)


func _meter(parent: Control, caption: String, fill: Color) -> DreamMeter:
	var meter := DreamMeter.new()
	meter.caption = caption
	meter.fill = fill
	meter.glow = profile.glow
	meter.text = profile.text
	parent.add_child(meter)
	return meter
