extends GdUnitTestSuite


func _booted() -> TrBootstrap:
	var boot := TrBootstrap.new()
	boot.add(FxMessagingModule.new()).add(FxSaveModule.new([]))
	assert_bool(boot.boot().ok).is_true()
	return boot


func test_boot_payload_lists_modules_and_services() -> void:
	var boot: TrBootstrap = _booted()
	var payload: Array = TrDebugReporter.boot_payload(boot.module_names(), boot.get_container())
	assert_array(payload[0]).contains_exactly(["FxMessagingModule", "FxSaveModule"])
	assert_array(payload[1]).contains_exactly_in_any_order([["TrEventBus", "singleton"], ["TrMediator", "singleton"], ["FxStore", "singleton"]])


func test_request_and_event_payloads() -> void:
	assert_array(TrDebugReporter.request_payload(FxAdd.new(), TrResult.success(1), 12, false)).contains_exactly(["FxAdd", true, "", 12, false])
	assert_array(TrDebugReporter.request_payload(FxAdd.new(), TrResult.failure(&"nope"), 3, true)).contains_exactly(["FxAdd", false, "nope", 3, true])
	assert_array(TrDebugReporter.request_payload(FxAdd.new(), null, 0, false)).contains_exactly(["FxAdd", false, "null_result", 0, false])
	var event_data: Array = TrDebugReporter.event_payload(FxHit.new(2))
	assert_str(str(event_data[0])).is_equal("FxHit")


func test_reporter_reports_boot_events_and_requests() -> void:
	var boot: TrBootstrap = _booted()
	var reporter := FxRecordingReporter.new()
	reporter.attach(boot)
	var c: TrServiceContainer = boot.get_container()
	(c.get_service(TrEventBus) as TrEventBus).publish(FxHit.new(1))
	var mediator := c.get_service(TrMediator) as TrMediator
	mediator.send(FxAdd.new(1, 2))
	await mediator.send_async(FxAsyncRequest.new(1))
	var names: Array[String] = []
	for entry: Variant in reporter.sent:
		names.append(str((entry as Array)[0]))
	assert_array(names).contains_exactly(["boot", "event", "request", "request"])
	var sync_request: Array = (reporter.sent[2] as Array)[1]
	assert_str(str(sync_request[0])).is_equal("FxAdd")
	assert_bool(sync_request[1]).is_true()
	var async_request: Array = (reporter.sent[3] as Array)[1]
	assert_bool(async_request[4]).is_true()
	reporter.detach()
	mediator.send(FxAdd.new(1, 2))
	assert_int(reporter.sent.size()).is_equal(4)


func test_panel_shows_boot_and_log() -> void:
	var panel: TrDebugPanel = auto_free(TrDebugPanel.new())
	add_child(panel)
	assert_bool(panel.apply("boot", [PackedStringArray(["CoreModule", "ScoreModule"]), [["TrMediator", "singleton"], ["ScoreStore", "instance"]]])).is_true()
	assert_array(panel.tree_lines()).contains_exactly([
		"Modules/CoreModule | #1", "Modules/ScoreModule | #2",
		"Services/TrMediator | singleton", "Services/ScoreStore | instance",
	])
	assert_str(panel.summary_text()).is_equal("2 modules, 2 services")
	panel.apply("event", ["PointsChanged", 10])
	panel.apply("request", ["AddPoints", true, "", 15, false])
	panel.apply("request", ["AddPoints", false, "invalid_points", 4, true])
	assert_array(panel.log_lines()).contains_exactly([
		"1  event   PointsChanged",
		"2  request AddPoints ok (15 µs)",
		"3  request AddPoints FAILED invalid_points (4 µs) async",
	])
	assert_bool(panel.apply("unknown", [])).is_false()


func test_panel_log_is_capped_and_clearable() -> void:
	var panel: TrDebugPanel = auto_free(TrDebugPanel.new())
	add_child(panel)
	for i: int in TrDebugPanel.MAX_LOG + 5:
		panel.apply("event", ["E%d" % i, i])
	assert_int(panel.log_lines().size()).is_equal(TrDebugPanel.MAX_LOG)
	assert_str(panel.log_lines()[0]).is_equal("6  event   E5")
	panel.clear_log()
	assert_array(panel.log_lines()).is_empty()


func test_bus_emits_published() -> void:
	var bus := TrEventBus.new()
	var seen: Array[String] = []
	bus.published.connect(func(e: TrEvent) -> void: seen.append(TrContracts.describe_value(e)))
	bus.publish(FxHit.new(1))
	assert_array(seen).contains_exactly(["FxHit"])


func test_published_follows_publish_order_for_nested_events() -> void:
	var bus := TrEventBus.new()
	var seen: Array[String] = []
	bus.published.connect(func(e: TrEvent) -> void: seen.append(TrContracts.describe_value(e)))
	bus.subscribe(FxHit, func(_e: FxHit) -> void: bus.publish(FxEvent.new()))
	bus.publish(FxHit.new(1))
	assert_array(seen).contains_exactly(["FxHit", "FxEvent"])
