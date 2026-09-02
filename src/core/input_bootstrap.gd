extends Node

const KEY_ACTIONS := {
	"move_left": [KEY_A, KEY_LEFT],
	"move_right": [KEY_D, KEY_RIGHT],
	"move_up": [KEY_W, KEY_UP],
	"move_down": [KEY_S, KEY_DOWN],
	"attack": [KEY_J],
	"sword_art": [KEY_Q],
	"spirit_guard": [KEY_E],
	"dodge": [KEY_SPACE, KEY_K],
	"start_demo": [KEY_ENTER],
	"restart": [KEY_R],
}


func _enter_tree() -> void:
	for action_name in KEY_ACTIONS.keys():
		_ensure_action(action_name)
		for key_code in KEY_ACTIONS[action_name]:
			_ensure_key_binding(action_name, key_code)

	_ensure_mouse_binding("attack", MOUSE_BUTTON_LEFT)


func _ensure_action(action_name: StringName) -> void:
	if not InputMap.has_action(action_name):
		InputMap.add_action(action_name)


func _ensure_key_binding(action_name: StringName, key_code: int) -> void:
	for existing_event in InputMap.action_get_events(action_name):
		if existing_event is InputEventKey and existing_event.physical_keycode == key_code:
			return

	var key_event := InputEventKey.new()
	key_event.physical_keycode = key_code
	InputMap.action_add_event(action_name, key_event)


func _ensure_mouse_binding(action_name: StringName, button_index: int) -> void:
	for existing_event in InputMap.action_get_events(action_name):
		if existing_event is InputEventMouseButton and existing_event.button_index == button_index:
			return

	var mouse_event := InputEventMouseButton.new()
	mouse_event.button_index = button_index
	InputMap.action_add_event(action_name, mouse_event)
