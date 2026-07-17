extends Node3D

@onready var objective_label: Label = $CanvasLayer/ObjectiveLabel
@onready var start_hint: Label = $CanvasLayer/StartHint
@onready var message_panel: PanelContainer = $CanvasLayer/MessagePanel
@onready var message_label: Label = $CanvasLayer/MessagePanel/MessageText
@onready var message_timer: Timer = $CanvasLayer/MessageTimer

var stage := 0
var objectives: Array[String] = [
	"ЦЕЛЬ: Добраться до центрального поста",
	"ЦЕЛЬ: Осмотреть технический сектор и генераторы",
	"ЦЕЛЬ: Найти камеру содержания 01",
	"ЦЕЛЬ: Исследовать оставшуюся часть комплекса"
]

func _ready() -> void:
	objective_label.text = objectives[stage]
	start_hint.text = "%s/%s/%s/%s — ДВИЖЕНИЕ    %s — БЕГ    МЫШЬ — ОБЗОР    %s — ВЗАИМОДЕЙСТВИЕ" % [
		InputPromptFormatter.action_label(&"move_forward"),
		InputPromptFormatter.action_label(&"move_left"),
		InputPromptFormatter.action_label(&"move_back"),
		InputPromptFormatter.action_label(&"move_right"),
		InputPromptFormatter.action_label(&"sprint"),
		InputPromptFormatter.action_label(&"interact"),
	]
	$ProgressionTriggers/ControlReached.body_entered.connect(_on_stage_area.bind(0))
	$ProgressionTriggers/TechnicalReached.body_entered.connect(_on_stage_area.bind(1))
	$ProgressionTriggers/ContainmentReached.body_entered.connect(_on_stage_area.bind(2))
	message_timer.timeout.connect(_on_message_timeout)
	var tween := create_tween()
	tween.tween_interval(6.0)
	tween.tween_property(start_hint, "modulate:a", 0.0, 1.0)

func _on_stage_area(body: Node3D, required_stage: int) -> void:
	if not body is CharacterBody3D or stage != required_stage:
		return
	stage = min(stage + 1, objectives.size() - 1)
	objective_label.text = objectives[stage]

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
