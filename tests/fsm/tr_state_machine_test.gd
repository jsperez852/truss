extends GdUnitTestSuite

var log: Array[String]
var machine: TrStateMachine
var alive: FxAlive
var idle: FxIdle
var chase: FxChase
var dead: FxDead


func _state(state: FxLogState, state_name: String) -> FxLogState:
	state.name = state_name
	state.log = log
	return state


func _build(extra: Array[FxLogState] = []) -> void:
	log = []
	machine = TrStateMachine.new()
	machine.running = false
	alive = _state(FxAlive.new(), "Alive") as FxAlive
	idle = _state(FxIdle.new(), "Idle") as FxIdle
	chase = _state(FxChase.new(), "Chase") as FxChase
	dead = _state(FxDead.new(), "Dead") as FxDead
	alive.add_child(idle)
	alive.add_child(chase)
	machine.add_child(alive)
	machine.add_child(dead)
	for state: FxLogState in extra:
		state.log = log
		machine.add_child(state)


func _start() -> void:
	add_child(machine)


func after_test() -> void:
	if is_instance_valid(machine):
		machine.free()


func test_starts_in_first_leaf_through_parents() -> void:
	_build()
	_start()
	assert_array(log).contains_exactly(["enter Alive (from -)", "enter Idle (from -)"])
	assert_object(machine.current()).is_same(idle)
	assert_array(machine.active_path()).contains_exactly([alive, idle])


func test_initial_state_and_substate_exports() -> void:
	_build()
	machine.initial_state = alive
	alive.initial_substate = chase
	_start()
	assert_object(machine.current()).is_same(chase)


func test_sibling_transition_keeps_parent_active() -> void:
	_build()
	_start()
	log.clear()
	assert_bool(machine.transition_to(FxChase)).is_true()
	assert_array(log).contains_exactly(["exit Idle (to Chase)", "enter Chase (from Idle)"])
	assert_bool(alive.is_active()).is_true()


func test_leaving_a_parent_exits_leaf_then_parent() -> void:
	_build()
	_start()
	machine.transition_to(FxChase)
	log.clear()
	machine.transition_to(FxDead)
	assert_array(log).contains_exactly(["exit Chase (to Dead)", "exit Alive (to Dead)", "enter Dead (from Chase)"])
	assert_bool(alive.is_active()).is_false()


func test_entering_a_parent_enters_its_initial_substate() -> void:
	_build()
	machine.initial_state = dead
	_start()
	log.clear()
	machine.transition_to(FxAlive)
	assert_array(log).contains_exactly(["exit Dead (to Idle)", "enter Alive (from Dead)", "enter Idle (from Dead)"])


func test_transition_to_current_leaf_reenters_it() -> void:
	_build()
	_start()
	log.clear()
	machine.transition_to(FxIdle)
	assert_array(log).contains_exactly(["exit Idle (to Idle)", "enter Idle (from Idle)"])


func test_unknown_state_class_is_reported() -> void:
	_build()
	_start()
	var out: Array[bool] = []
	await assert_error(func() -> void: out.append(machine.transition_to(FxStore))) \
		.is_push_error("TrStateMachine %s: no state of class FxStore" % machine.get_path())
	assert_bool(out[0]).is_false()


func test_transition_requested_during_enter_is_queued() -> void:
	var bounce := FxBounce.new()
	bounce.name = "Bounce"
	_build([bounce])
	_start()
	var seen: Array[String] = []
	machine.transitioned.connect(func(from: TrState, to: TrState) -> void: seen.append("%s>%s" % [from.name, to.name]))
	log.clear()
	machine.transition_to(FxBounce)
	assert_array(log).contains_exactly([
		"exit Idle (to Bounce)", "exit Alive (to Bounce)", "enter Bounce (from Idle)",
		"exit Bounce (to Idle)", "enter Alive (from Bounce)", "enter Idle (from Bounce)",
	])
	assert_array(seen).contains_exactly(["Idle>Bounce", "Bounce>Idle"])
	assert_object(machine.current()).is_same(idle)


func test_updates_run_parent_first() -> void:
	_build()
	_start()
	log.clear()
	machine.running = true
	machine._process(0.1)
	machine._physics_process(0.1)
	assert_array(log).contains_exactly(["update Alive", "update Idle", "physics Alive", "physics Idle"])


func test_not_running_skips_updates() -> void:
	_build()
	_start()
	log.clear()
	machine._process(0.1)
	assert_array(log).is_empty()


func test_input_bubbles_from_leaf_until_consumed() -> void:
	_build()
	_start()
	machine.running = true
	log.clear()
	machine._unhandled_input(InputEventKey.new())
	assert_array(log).contains_exactly(["input Idle", "input Alive"])
	log.clear()
	idle.consume_input = true
	machine._unhandled_input(InputEventKey.new())
	assert_array(log).contains_exactly(["input Idle"])


func test_history_and_queries() -> void:
	_build()
	machine.history_size = 2
	_start()
	machine.transition_to(FxChase)
	machine.transition_to(FxDead)
	assert_array(machine.history).contains_exactly(["Idle -> Chase", "Chase -> Dead"])
	assert_bool(machine.is_in_class(FxDead)).is_true()
	assert_bool(machine.is_in_class(FxAlive)).is_false()
	assert_object(machine.find_state(FxChase)).is_same(chase)
	assert_array(alive.substates()).contains_exactly([idle, chase])
	assert_object(idle.parent_state()).is_same(alive)
	assert_object(alive.parent_state()).is_null()
