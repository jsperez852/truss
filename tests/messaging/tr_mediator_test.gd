extends GdUnitTestSuite

var mediator: TrMediator
var handler: FxAddHandler


func before_test() -> void:
	mediator = TrMediator.new()
	handler = FxAddHandler.new()
	mediator.register(handler)


func test_send_reaches_handler() -> void:
	var r: TrResult = mediator.send(FxAdd.new(2, 3))
	assert_bool(r.ok).is_true()
	assert_int(r.value).is_equal(5)
	assert_int(handler.calls).is_equal(1)


func test_handler_failures_are_returned() -> void:
	var r: TrResult = mediator.send(FxAdd.new(-1, 3))
	assert_str(String(r.error)).is_equal("negative")


func test_missing_handler() -> void:
	var out: Array[TrResult] = []
	await assert_error(func() -> void: out.append(mediator.send(FxUnhandled.new()))) \
		.is_push_error("TrMediator.send(): no handler registered for FxUnhandled")
	assert_str(String(out[0].error)).is_equal(String(TrMediator.ERR_NO_HANDLER))


func test_duplicate_handler_is_rejected() -> void:
	var out: Array[bool] = []
	await assert_error(func() -> void: out.append(mediator.register(FxAddHandler.new()))) \
		.is_push_error("TrMediator.register(): FxAdd already has a handler (FxAddHandler)")
	assert_bool(out[0]).is_false()


func test_handler_for_non_request_is_rejected() -> void:
	await assert_error(func() -> void: mediator.register(FxBadHandler.new())) \
		.is_push_error("TrMediator.register(): FxBadHandler handles FxStore, which is not a TrRequest subclass")
	assert_bool(mediator.has_handler(FxStore)).is_false()


func test_unregister() -> void:
	mediator.unregister(FxAdd)
	assert_bool(mediator.has_handler(FxAdd)).is_false()


func test_behaviors_wrap_in_order() -> void:
	var log: Array[String] = []
	mediator.add_behavior(FxRecorder.new("outer", log))
	mediator.add_behavior(FxRecorder.new("inner", log))
	var r: TrResult = mediator.send(FxAdd.new(1, 1))
	assert_int(r.value).is_equal(2)
	assert_array(log).contains_exactly(["outer>", "inner>", "<inner", "<outer"])


func test_behavior_can_short_circuit() -> void:
	mediator.add_behavior(FxBlocker.new())
	var r: TrResult = mediator.send(FxAdd.new(1, 1))
	assert_str(String(r.error)).is_equal("blocked")
	assert_int(handler.calls).is_equal(0)


func test_remove_behavior() -> void:
	var blocker := FxBlocker.new()
	mediator.add_behavior(blocker)
	mediator.remove_behavior(blocker)
	assert_bool(mediator.send(FxAdd.new(1, 1)).ok).is_true()


func test_null_result_from_handler_is_reported() -> void:
	mediator.register(FxNullHandler.new())
	var out: Array[TrResult] = []
	await assert_error(func() -> void: out.append(mediator.send(FxUnhandled.new()))) \
		.is_push_error("TrMediator: FxNullHandler returned null instead of a TrResult")
	assert_str(String(out[0].error)).is_equal(String(TrMediator.ERR_INVALID_RESULT))


func test_send_null() -> void:
	await assert_error(func() -> void: mediator.send(null)).is_push_error("TrMediator.send(): request is null")
