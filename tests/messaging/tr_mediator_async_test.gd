extends GdUnitTestSuite

var mediator: TrMediator
var handler: FxAsyncHandler


func before_test() -> void:
	mediator = TrMediator.new()
	handler = FxAsyncHandler.new()
	mediator.register(handler)
	mediator.register(FxAddHandler.new())


func test_send_async_awaits_the_handler() -> void:
	var start_frame: int = Engine.get_process_frames()
	var r: TrResult = await mediator.send_async(FxAsyncRequest.new(4))
	assert_bool(r.ok).is_true()
	assert_int(r.value).is_equal(40)
	assert_int(handler.finished).is_equal(1)
	assert_int(Engine.get_process_frames()).is_greater(start_frame)


func test_send_async_works_with_sync_handlers() -> void:
	var r: TrResult = await mediator.send_async(FxAdd.new(2, 3))
	assert_int(r.value).is_equal(5)


func test_send_with_async_handler_is_reported() -> void:
	var out: Array[TrResult] = []
	await assert_error(func() -> void: out.append(mediator.send(FxAsyncRequest.new(1)))) \
		.is_push_error("TrMediator: FxAsyncHandler uses await; send this request with send_async()")
	assert_str(String(out[0].error)).is_equal(String(TrMediator.ERR_ASYNC_HANDLER))
	await get_tree().process_frame


func test_async_behaviors_wrap_in_order_and_sync_only_behaviors_pass_through() -> void:
	var log: Array[String] = []
	mediator.add_behavior(FxAsyncRecorder.new("outer", log))
	mediator.add_behavior(FxRecorder.new("sync-only", log))
	mediator.add_behavior(FxAsyncRecorder.new("inner", log))
	var r: TrResult = await mediator.send_async(FxAsyncRequest.new(1))
	assert_int(r.value).is_equal(10)
	assert_array(log).contains_exactly(["outer>", "inner>", "<inner", "<outer"])


func test_sync_send_still_uses_process() -> void:
	var log: Array[String] = []
	mediator.add_behavior(FxAsyncRecorder.new("b", log))
	mediator.send(FxAdd.new(1, 1))
	assert_array(log).contains_exactly(["sync b"])


func test_send_async_missing_handler() -> void:
	var out: Array[TrResult] = []
	await assert_error(func() -> void: out.append(await mediator.send_async(FxUnhandled.new()))) \
		.is_push_error("TrMediator.send_async(): no handler registered for FxUnhandled")
	assert_str(String(out[0].error)).is_equal(String(TrMediator.ERR_NO_HANDLER))
