extends GdUnitTestSuite

var phase: TrPhases
var log_lines: Array[String]


func before_test() -> void:
	phase = TrPhases.new()
	log_lines = []


func _rec(label: String) -> Callable:
	return func(other: StringName) -> void: log_lines.append("%s:%s" % [label, other])


func test_start_and_go_run_exit_then_enter() -> void:
	phase.add(&"ready", {exit = _rec("exit_ready")})
	phase.add(&"playing", {enter = _rec("enter_playing")})
	var changes: Array = []
	phase.changed.connect(func(a: StringName, b: StringName) -> void: changes.append([a, b]))
	assert_bool(phase.start(&"ready")).is_true()
	assert_bool(phase.go(&"playing")).is_true()
	assert_array(log_lines).contains_exactly(["exit_ready:playing", "enter_playing:ready"])
	assert_array(changes).contains_exactly([[&"", &"ready"], [&"ready", &"playing"]])
	assert_bool(phase.is_in(&"playing")).is_true()


func test_zero_argument_callables() -> void:
	var hits: Array[int] = [0]
	phase.add(&"a", {enter = func() -> void: hits[0] += 1, update = func() -> void: hits[0] += 10})
	phase.start(&"a")
	phase.update(0.5)
	assert_int(hits[0]).is_equal(11)
	assert_float(phase.elapsed()).is_equal_approx(0.5, 0.0001)


func test_to_limits_the_next_phase() -> void:
	phase.add(&"crashed", {to = [&"over"]})
	phase.add(&"playing")
	phase.add(&"over")
	phase.start(&"crashed")
	assert_bool(phase.can_go(&"playing")).is_false()
	assert_bool(phase.go(&"playing")).is_false()
	assert_bool(phase.go(&"over")).is_true()
	assert_bool(phase.go(&"over")).is_false()


func test_go_inside_enter_runs_after_the_current_transition() -> void:
	phase.add(&"a")
	phase.add(&"b", {enter = func() -> void:
		log_lines.append("enter_b")
		phase.go(&"c")
		log_lines.append("after_go")})
	phase.add(&"c", {enter = _rec("enter_c")})
	phase.start(&"a")
	phase.go(&"b")
	assert_array(log_lines).contains_exactly(["enter_b", "after_go", "enter_c:b"])
	assert_str(String(phase.current())).is_equal("c")


func test_elapsed_resets_on_transition() -> void:
	phase.add(&"a")
	phase.add(&"b")
	phase.start(&"a")
	phase.update(1.0)
	phase.go(&"b")
	assert_float(phase.elapsed()).is_equal(0.0)


func test_errors() -> void:
	phase.add(&"a")
	await assert_error(func() -> void: phase.go(&"a")).is_push_error("TrPhases.go(a): call start() first")
	await assert_error(func() -> void: phase.add(&"a")).is_push_error("TrPhases.add(): phase a already exists")
	await assert_error(func() -> void: phase.add(&"b", {enter_ = _rec("x")})) \
		.is_push_error("TrPhases.add(b): unknown option enter_ (valid: enter, exit, update, to)")
	await assert_error(func() -> void: phase.start(&"zzz")).is_push_error("TrPhases.start(): unknown phase zzz (known: a)")
	phase.start(&"a")
	await assert_error(func() -> void: phase.go(&"q")).is_push_error("TrPhases.go(): unknown phase q (known: a)")
