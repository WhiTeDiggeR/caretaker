extends StaticBody3D

@export var interaction_prompt := "[E] ОСМОТРЕТЬ"
@export var message_title := "СЛУЖЕБНАЯ СИСТЕМА"
@export_multiline var message_text := "Устройство не отвечает."

func get_interaction_text() -> String:
	return interaction_prompt

func interact() -> void:
	var scene := get_tree().current_scene
	if scene and scene.has_method("show_facility_message"):
		scene.show_facility_message(message_title, message_text)
