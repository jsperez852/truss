@tool
extends EditorPlugin
## Enabling the plugin registers the "Truss" autoload and the truss/injection/automatic project setting.

const AUTOLOAD_NAME: String = "Truss"
const AUTOLOAD_PATH: String = "res://addons/truss/truss.gd"
const SETTING_AUTOMATIC_INJECTION: String = "truss/injection/automatic"


func _enable_plugin() -> void:
	add_autoload_singleton(AUTOLOAD_NAME, AUTOLOAD_PATH)
	if not ProjectSettings.has_setting(SETTING_AUTOMATIC_INJECTION):
		ProjectSettings.set_setting(SETTING_AUTOMATIC_INJECTION, true)
	ProjectSettings.set_initial_value(SETTING_AUTOMATIC_INJECTION, true)
	ProjectSettings.add_property_info({
		"name": SETTING_AUTOMATIC_INJECTION,
		"type": TYPE_BOOL,
	})
	ProjectSettings.set_as_basic(SETTING_AUTOMATIC_INJECTION, true)
	ProjectSettings.save()


func _disable_plugin() -> void:
	remove_autoload_singleton(AUTOLOAD_NAME)
