@abstract class_name FxLogState
extends TrState
## Test state that records its callbacks into a shared log.

var log: Array[String] = []
var consume_input: bool = false


func enter(previous: TrState) -> void:
	log.append("enter %s (from %s)" % [name, previous.name if previous != null else "-"])


func exit(next: TrState) -> void:
	log.append("exit %s (to %s)" % [name, next.name])


func update(_delta: float) -> void:
	log.append("update " + name)


func physics_update(_delta: float) -> void:
	log.append("physics " + name)


func handle_input(_event: InputEvent) -> bool:
	log.append("input " + name)
	return consume_input
