extends Node3D

@onready var blockout: ComplexV3Blockout = $ComplexV3Blockout
@onready var player: CharacterBody3D = $Player
@onready var player_camera: Camera3D = $Player/Camera3D
@onready var overview_camera: Camera3D = $OverviewCamera
@onready var status_label: Label = $CanvasLayer/StatusLabel

var _overview_enabled := false
var _level_filter_index := 0
var _level_filters: Array[String] = ["ALL", "LV-U", "LV-L", "LV-T"]


func _ready() -> void:
	overview_camera.look_at(Vector3(-38.0, -4.0, 32.0), Vector3.UP)
	player_camera.make_current()
	_update_status()
	var errors := blockout.validate_against_handoff()
	for error: String in errors:
		push_error(error)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey:
		var key_event := event as InputEventKey
		if key_event.pressed and not key_event.echo and key_event.keycode == KEY_F1:
			_overview_enabled = not _overview_enabled
			if _overview_enabled:
				overview_camera.make_current()
				Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
			else:
				player_camera.make_current()
				Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
			_update_status()
			get_viewport().set_input_as_handled()
		elif key_event.pressed and not key_event.echo and key_event.keycode == KEY_F2:
			_level_filter_index = (_level_filter_index + 1) % _level_filters.size()
			_apply_level_filter()
			_update_status()
			get_viewport().set_input_as_handled()


func _apply_level_filter() -> void:
	var selected := _level_filters[_level_filter_index]
	for level_id: String in ["LV-U", "LV-L", "LV-T"]:
		var level := blockout.get_node_or_null("Generated/%s" % level_id) as Node3D
		if level != null:
			level.visible = selected == "ALL" or selected == level_id
	var connections := blockout.get_node_or_null("Generated/Connections") as Node3D
	if connections != null:
		connections.visible = selected == "ALL"
	var verticals := blockout.get_node_or_null("Generated/VerticalTransitions") as Node3D
	if verticals != null:
		verticals.visible = selected == "ALL"


func _update_status() -> void:
	var stats := blockout.get_build_stats()
	status_label.text = "COMPLEX v3 BLOCKOUT · %s · %s\n139 помещений · 7 магистралей · 7 опор · %d коллайдеров\nF1 — %s · F2 — следующий уровень" % [
		"ОБЗОР" if _overview_enabled else "ПЕРВОЕ ЛИЦО",
		_level_filters[_level_filter_index],
		int(stats.get("colliders", 0)),
		"вернуться к игроку" if _overview_enabled else "общий вид",
	]
