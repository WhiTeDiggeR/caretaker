class_name InputPromptFormatter
extends RefCounted


static func action_label(action: StringName) -> String:
	for event: InputEvent in InputMap.action_get_events(action):
		if event is InputEventKey:
			var key_event := event as InputEventKey
			if key_event.physical_keycode != KEY_NONE:
				return key_event.as_text_physical_keycode()
			return key_event.as_text_keycode()
		return event.as_text()
	return String(action)


static func format_action(action: StringName, prompt: String) -> String:
	return "[%s] %s" % [action_label(action), prompt]
