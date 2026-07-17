extends Node3D

@onready var _label: Label3D = $Label3D

var _pods: Array[SleepPod] = []


func _ready() -> void:
	for node: Node in get_tree().get_nodes_in_group("sleep_pods"):
		var pod := node as SleepPod
		if not pod:
			continue
		_pods.append(pod)
		pod.sleep_time_changed.connect(_on_pod_sleep_time_changed)
		pod.pod_awakened.connect(_on_pod_awakened)
	call_deferred("_update_display")


func _on_pod_sleep_time_changed(_current_seconds: float, _maximum_seconds: float) -> void:
	_update_display()


func _on_pod_awakened() -> void:
	_update_display()


func _update_display() -> void:
	var text := "СОСТОЯНИЕ КОМПЛЕКСА\n\n"
	if _pods.is_empty():
		_label.text = text + "Капсулы не обнаружены"
		return

	for pod: SleepPod in _pods:
		var percent := 0
		if pod.max_sleep_time > 0.0:
			percent = clampi(int((pod.sleep_time / pod.max_sleep_time) * 100.0), 0, 100)

		var state := "🟢"
		if percent < 50:
			state = "🟡"
		if percent < 25:
			state = "🔴"

		text += "%s   %d%%   %s\n" % [pod.villain_name, percent, state]

	_label.text = text
