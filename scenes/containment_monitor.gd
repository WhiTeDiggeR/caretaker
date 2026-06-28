extends Node3D

@onready var label = $Label3D

func _process(_delta):
	update_display()

func update_display():

	var text = "СОСТОЯНИЕ КОМПЛЕКСА\n\n"

	var pods = get_tree().get_nodes_in_group("sleep_pods")

	if pods.is_empty():
		text += "Капсулы не обнаружены"
		label.text = text
		return

	for pod in pods:

		var percent = int(
			(pod.sleep_time / pod.max_sleep_time) * 100
		)

		percent = clamp(percent, 0, 100)

		var state = "🟢"

		if percent < 50:
			state = "🟡"

		if percent < 25:
			state = "🔴"

		text += "%s   %d%%   %s\n" % [
			pod.villain_name,
			percent,
			state
		]

	label.text = text
