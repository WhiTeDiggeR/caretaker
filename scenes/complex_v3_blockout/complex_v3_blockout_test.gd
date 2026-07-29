extends Node3D

@onready var blockout: ComplexV3Blockout = $ComplexV3Blockout
@onready var player: CharacterBody3D = $Player
@onready var player_camera: Camera3D = $Player/Camera3D
@onready var overview_camera: Camera3D = $OverviewCamera
@onready var status_label: Label = $CanvasLayer/StatusLabel

var _overview_enabled := false
var _level_filter_index := 0
var _level_filters: Array[String] = ["ALL", "LV-U", "LV-L", "LV-T"]
var _scope_index := 0
var _scopes: Array[String] = ["FULL", "SECTOR", "NEIGHBORS"]
var _sector_ids := PackedStringArray()
var _sector_index := 0


func _ready() -> void:
	_sector_ids = blockout.get_sector_ids()
	_sector_index = maxi(_sector_ids.find("U-MEDBAY"), 0)
	overview_camera.look_at(Vector3(-38.0, -4.0, 32.0), Vector3.UP)
	player_camera.make_current()
	_apply_view_filter()
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
			_apply_view_filter()
			_update_status()
			get_viewport().set_input_as_handled()
		elif key_event.pressed and not key_event.echo and key_event.keycode == KEY_F3:
			_scope_index = (_scope_index + 1) % _scopes.size()
			_apply_view_filter()
			_update_status()
			get_viewport().set_input_as_handled()
		elif key_event.pressed and not key_event.echo and key_event.keycode == KEY_F4:
			var direction := -1 if key_event.shift_pressed else 1
			_sector_index = posmod(_sector_index + direction, _sector_ids.size())
			if _scope_index == 0:
				_scope_index = 1
			_apply_view_filter()
			_update_status()
			get_viewport().set_input_as_handled()


func _apply_view_filter() -> void:
	var sector_id := _sector_ids[_sector_index] if not _sector_ids.is_empty() else ""
	match _scopes[_scope_index]:
		"SECTOR":
			blockout.show_sector(sector_id)
			_focus_selected_sector(sector_id)
		"NEIGHBORS":
			blockout.show_sector_with_neighbors(sector_id)
			_focus_selected_sector(sector_id)
		_:
			blockout.show_full_complex()
			overview_camera.global_position = Vector3(-38.0, 142.0, 38.0)
			overview_camera.look_at(Vector3(-38.0, -4.0, 32.0), Vector3.UP)
	blockout.set_level_filter(_level_filters[_level_filter_index])


func _focus_selected_sector(sector_id: String) -> void:
	var focus := blockout.get_sector_focus(sector_id)
	player.global_position = focus
	overview_camera.global_position = focus + Vector3(0.0, 55.0, 32.0)
	overview_camera.look_at(focus, Vector3.UP)


func _update_status() -> void:
	var stats := blockout.get_build_stats()
	var sector_id := _sector_ids[_sector_index] if not _sector_ids.is_empty() else "—"
	status_label.text = "COMPLEX v3 · %s · %s · %s\n139 помещений · 30 зон · %d коллайдеров\nF1 камера · F2 уровень · F3 режим · F4/Shift+F4 зона" % [
		"ОБЗОР" if _overview_enabled else "ПЕРВОЕ ЛИЦО",
		_level_filters[_level_filter_index],
		"ВСЕ" if _scope_index == 0 else "%s: %s" % [_scopes[_scope_index], sector_id],
		int(stats.get("colliders", 0)),
	]
