@tool
extends EditorPlugin
## Enabling the plugin registers the "Truss" autoload and the truss/injection/automatic project setting.
## While the editor runs, it also adds the "Truss" tab to the Debugger panel.

const AUTOLOAD_NAME: String = "Truss"
const AUTOLOAD_PATH: String = "res://addons/truss/truss.gd"
const SETTING_AUTOMATIC_INJECTION: String = "truss/injection/automatic"
const DEBUGGER_PLUGIN: GDScript = preload("res://addons/truss/debug/tr_debugger_plugin.gd")

var _debugger: EditorDebuggerPlugin


func _enter_tree() -> void:
	_debugger = DEBUGGER_PLUGIN.new()
	add_debugger_plugin(_debugger)


func _exit_tree() -> void:
	if _debugger != null:
		remove_debugger_plugin(_debugger)
		_debugger = null


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
