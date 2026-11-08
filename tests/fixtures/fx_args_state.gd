class_name FxArgsState
extends FxLogState
## Records the transition args it sees on enter.

var seen_args: Array[Dictionary] = []


func enter(previous: TrState) -> void:
	super.enter(previous)
	seen_args.append(machine.transition_args.duplicate())
