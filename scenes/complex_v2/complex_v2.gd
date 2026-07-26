extends Node3D

@onready var objective_label: Label = $CanvasLayer/ObjectiveLabel
@onready var start_hint: Label = $CanvasLayer/StartHint
@onready var message_panel: PanelContainer = $CanvasLayer/MessagePanel
@onready var message_label: Label = $CanvasLayer/MessagePanel/MessageText
@onready var message_timer: Timer = $CanvasLayer/MessageTimer

var _stage := 0
var _objectives: Array[String] = [
	"ЦЕЛЬ: Найти ручной эвакуационный путь",
	"ЦЕЛЬ: Добраться до старого резервного поста",
	"ЦЕЛЬ: Запустить главный генератор",
	"ЦЕЛЬ: Добраться до нового центра управления",
	"ЦЕЛЬ: Осмотреть камеры полноценного сна",
	"ЦЕЛЬ: Исследовать оставшуюся часть комплекса",
]


func _ready() -> void:
	objective_label.text = _objectives[_stage]
	start_hint.text = "%s/%s/%s/%s — ДВИЖЕНИЕ    %s — БЕГ    МЫШЬ — ОБЗОР    %s — ВЗАИМОДЕЙСТВИЕ" % [
		InputPromptFormatter.action_label(&"move_forward"),
		InputPromptFormatter.action_label(&"move_left"),
		InputPromptFormatter.action_label(&"move_back"),
		InputPromptFormatter.action_label(&"move_right"),
		InputPromptFormatter.action_label(&"sprint"),
		InputPromptFormatter.action_label(&"interact"),
	]
	$ProgressionTriggers/EvacuationRoute.body_entered.connect(_on_stage_area.bind(0))
	$ProgressionTriggers/OldControl.body_entered.connect(_on_stage_area.bind(1))
	$ProgressionTriggers/MainGenerator.body_entered.connect(_on_stage_area.bind(2))
	$ProgressionTriggers/CentralControl.body_entered.connect(_on_stage_area.bind(3))
	$ProgressionTriggers/Containment03.body_entered.connect(_on_stage_area.bind(4))
	message_timer.timeout.connect(_on_message_timeout)
	var tween := create_tween()
	tween.tween_interval(7.0)
	tween.tween_property(start_hint, "modulate:a", 0.0, 1.0)


func _on_stage_area(body: Node3D, required_stage: int) -> void:
	if not body is CharacterBody3D or _stage != required_stage:
		return
	_stage = mini(_stage + 1, _objectives.size() - 1)
	objective_label.text = _objectives[_stage]


func show_facility_message(title: String, body: String) -> void:
	message_label.text = "%s\n\n%s\n\n%s" % [
		title,
		body,
		InputPromptFormatter.format_action(&"ui_cancel", "ЗАКРЫТЬ"),
	]
	message_panel.visible = true
	message_timer.start()


func _on_message_timeout() -> void:
	message_panel.visible = false


func _unhandled_input(event: InputEvent) -> void:
	if message_panel.visible and event.is_action_pressed("ui_cancel"):
		message_timer.stop()
		message_panel.visible = false
		get_viewport().set_input_as_handled()
