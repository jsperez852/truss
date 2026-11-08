extends GdUnitTestSuite

var log: Array[String]
var machine: TrStateMachine


func _make(state: FxLogState, state_name: String, parent: Node) -> FxLogState:
	state.name = state_name
	state.log = log
	parent.add_child(state)
	return state


func before_test() -> void:
	log = []
	machine = TrStateMachine.new()
	machine.running = false


func after_test() -> void:
	machine.free()


func test_args_reach_enter_and_stay_until_next_transition() -> void:
	_make(FxIdle.new(), "Idle", machine)
	var hurt := _make(FxArgsState.new(), "Hurt", machine) as FxArgsState
	add_child(machine)
	machine.transition_to(FxArgsState, {hitstun = 0.3, knockback = Vector2(120, 0)})
	assert_float(hurt.seen_args[0].get(&"hitstun")).is_equal(0.3)
	assert_that(machine.transition_args.get("knockback")).is_equal(Vector2(120, 0))
	machine.transition_to(FxIdle)
	assert_dict(machine.transition_args).is_empty()


func test_queued_transitions_keep_their_own_args() -> void:
	var a := _make(FxArgsState.new(), "A", machine) as FxArgsState
	_make(FxIdle.new(), "Idle", machine)
	add_child(machine)
	machine.transitioned.connect(func(_from: TrState, to: TrState) -> void:
		if to.name == "Idle" and a.seen_args.size() < 2:
			machine.transition_to(FxArgsState, {step = 2}))
	machine.transition_to(FxIdle, {step = 1})
	assert_int(a.seen_args.size()).is_equal(2)
	assert_int(a.seen_args[1].get("step")).is_equal(2)


func test_intents_bubble_from_leaf_until_handled() -> void:
	var parent := _make(FxIntentState.new(), "Alive", machine) as FxIntentState
	var leaf := _make(FxIntentState.new(), "Idle", parent) as FxIntentState
	parent.handles = [&"attack", &"jump"]
	leaf.handles = [&"jump"]
	add_child(machine)
	assert_bool(machine.send_intent(&"jump")).is_true()
	assert_bool(machine.send_intent(&"attack", {power = 2})).is_true()
	assert_bool(machine.send_intent(&"dance")).is_false()
	assert_array(leaf.intents).contains_exactly(["jump", "attack power=2", "dance"])
	assert_array(parent.intents).contains_exactly(["attack power=2", "dance"])


func test_old_signatures_still_work() -> void:
	_make(FxIdle.new(), "Idle", machine)
	_make(FxChase.new(), "Chase", machine)
	add_child(machine)
	assert_bool(machine.transition_to(FxChase)).is_true()
	assert_bool(machine.transition_to_state(machine.find_state(FxIdle))).is_true()
