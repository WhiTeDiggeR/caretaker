extends Node

@onready var pods = get_tree().get_nodes_in_group("sleep_pods")

func _process(delta):

	var bowser_awake = false
	var shiro_awake = false

	for pod in pods:

		if pod.villain_name == "Боузер" and pod.awakened:
			bowser_awake = true

		if pod.villain_name == "Широ Брин" and pod.awakened:
			shiro_awake = true

	if bowser_awake and shiro_awake:
		print("ПРОИГРАЛ")
