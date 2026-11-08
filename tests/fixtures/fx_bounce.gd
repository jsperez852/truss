class_name FxBounce
extends FxLogState
## Requests another transition from enter(); the machine must queue it.


func enter(previous: TrState) -> void:
	super.enter(previous)
	machine.transition_to(FxIdle)
