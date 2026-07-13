extends Node3D

@onready var objective_label: Label = $CanvasLayer/ObjectiveLabel
@onready var start_hint: Label = $CanvasLayer/StartHint

var stage := 0
var objectives := [
	"ЦЕЛЬ: Добраться до центрального поста",
	"ЦЕЛЬ: Осмотреть технический сектор и генераторы",
	"ЦЕЛЬ: Найти камеру содержания 01",
	"ЦЕЛЬ: Исследовать оставшуюся часть комплекса"
]

func _ready() -> void:
	objective_label.text = objectives[stage]
	$ProgressionTriggers/ControlReached.body_entered.connect(_on_stage_area.bind(0))
	$ProgressionTriggers/TechnicalReached.body_entered.connect(_on_stage_area.bind(1))
	$ProgressionTriggers/ContainmentReached.body_entered.connect(_on_stage_area.bind(2))
	var tween := create_tween()
	tween.tween_interval(6.0)
	tween.tween_property(start_hint, "modulate:a", 0.0, 1.0)

func _on_stage_area(body: Node3D, required_stage: int) -> void:
	if not body is CharacterBody3D or stage != required_stage:
		return
	stage = min(stage + 1, objectives.size() - 1)
	objective_label.text = objectives[stage]
