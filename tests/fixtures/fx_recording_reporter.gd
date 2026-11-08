class_name FxRecordingReporter
extends TrDebugReporter
## Records messages instead of sending them to the editor.

var sent: Array = []


func send(message: StringName, data: Array) -> void:
	sent.append([String(message), data])
