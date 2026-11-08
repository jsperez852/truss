@tool
extends EditorDebuggerPlugin
## Adds the "Truss" tab to every debugger session and routes "truss:*" messages to it.

var _panels: Dictionary[int, TrDebugPanel] = {}


func _has_capture(capture: String) -> bool:
	return capture == TrDebugReporter.PREFIX


func _setup_session(session_id: int) -> void:
	var panel := TrDebugPanel.new()
	_panels[session_id] = panel
	get_session(session_id).add_session_tab(panel)


func _capture(message: String, data: Array, session_id: int) -> bool:
	if not _panels.has(session_id):
		return false
	return _panels[session_id].apply(message.trim_prefix(TrDebugReporter.PREFIX + ":"), data)
