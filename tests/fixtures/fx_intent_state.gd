class_name FxIntentState
extends FxLogState
## Handles intents listed in `handles`, records every intent it sees.

var handles: Array[StringName] = []
var intents: Array[String] = []


func handle_intent(intent: StringName, data: Dictionary) -> bool:
	intents.append("%s%s" % [intent, (" power=%s" % str(data.get("power"))) if data.has("power") else ""])
	return handles.has(intent)
