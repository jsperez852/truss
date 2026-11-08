extends GdUnitTestSuite

const TrussScript: GDScript = preload("res://addons/truss/truss.gd")

var truss: Node
var target: FxPauseTarget


func before_test() -> void:
	truss = TrussScript.new()
	add_child(truss)
	target = FxPauseTarget.new()
	truss.set(&"pause", TrPause.new(get_tree(), target))


func after_test() -> void:
	ProjectSettings.set_setting("truss/lifecycle/pause_on_focus_loss", false)
	truss.call(&"shutdown")
	truss.free()


func test_notifications_map_to_events() -> void:
	assert_str(TrContracts.describe_value(TrAppEvents.from_notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT))).is_equal("TrAppEvents.FocusLost")
	assert_str(TrContracts.describe_value(TrAppEvents.from_notification(Node.NOTIFICATION_WM_CLOSE_REQUEST))).is_equal("TrAppEvents.QuitRequested")
	assert_object(TrAppEvents.from_notification(Node.NOTIFICATION_READY)).is_null()


func test_events_are_emitted_and_published_on_the_bus() -> void:
	truss.call(&"boot", [FxMessagingModule.new()])
	var bus := (truss.get(&"container") as TrServiceContainer).get_service(TrEventBus) as TrEventBus
	var on_bus: Array[String] = []
	var on_signal: Array[String] = []
	bus.subscribe(TrAppEvents.AppEvent, func(e: TrAppEvents.AppEvent) -> void: on_bus.append(TrContracts.describe_value(e)))
	truss.connect(&"app_event", func(e: TrAppEvents.AppEvent) -> void: on_signal.append(TrContracts.describe_value(e)))
	for what: int in [Node.NOTIFICATION_APPLICATION_FOCUS_OUT, Node.NOTIFICATION_APPLICATION_FOCUS_IN, Node.NOTIFICATION_APPLICATION_PAUSED, Node.NOTIFICATION_APPLICATION_RESUMED, Node.NOTIFICATION_WM_CLOSE_REQUEST]:
		truss.call(&"handle_lifecycle", what)
	var expected: Array[String] = ["TrAppEvents.FocusLost", "TrAppEvents.FocusGained", "TrAppEvents.Paused", "TrAppEvents.Resumed", "TrAppEvents.QuitRequested"]
	assert_array(on_bus).contains_exactly(expected)
	assert_array(on_signal).contains_exactly(expected)


func test_signal_works_without_boot() -> void:
	var seen: Array[String] = []
	truss.connect(&"app_event", func(e: TrAppEvents.AppEvent) -> void: seen.append(TrContracts.describe_value(e)))
	truss.call(&"handle_lifecycle", Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	assert_array(seen).contains_exactly(["TrAppEvents.FocusLost"])


func test_focus_loss_does_not_pause_by_default() -> void:
	truss.call(&"handle_lifecycle", Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	assert_bool(target.paused).is_false()


func test_pause_on_focus_loss_holds_until_focus_and_app_are_back() -> void:
	ProjectSettings.set_setting("truss/lifecycle/pause_on_focus_loss", true)
	truss.call(&"handle_lifecycle", Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	assert_bool(target.paused).is_true()
	assert_array((truss.get(&"pause") as TrPause).holders()).contains_exactly([&"focus_lost"])
	truss.call(&"handle_lifecycle", Node.NOTIFICATION_APPLICATION_PAUSED)
	truss.call(&"handle_lifecycle", Node.NOTIFICATION_APPLICATION_FOCUS_IN)
	assert_bool(target.paused).is_true()
	truss.call(&"handle_lifecycle", Node.NOTIFICATION_APPLICATION_RESUMED)
	assert_bool(target.paused).is_false()


func test_reporter_sends_pause_changes_and_panel_shows_them() -> void:
	var boot := TrBootstrap.new()
	boot.add(FxMessagingModule.new())
	boot.boot()
	var p: TrPause = truss.get(&"pause")
	var reporter := FxRecordingReporter.new()
	reporter.attach(boot, p)
	var token: TrPauseToken = p.acquire(&"menu")
	token.release()
	var kinds: Array[String] = []
	for entry: Variant in reporter.sent:
		kinds.append(str((entry as Array)[0]))
	assert_array(kinds).contains_exactly(["boot", "pause", "pause"])
	var panel: TrDebugPanel = auto_free(TrDebugPanel.new())
	add_child(panel)
	# Godot 4.5 ignores directory_rules, so the strict profile applies to tests too: keep arguments typed.
	var first: Array = (reporter.sent[1] as Array)[1]
	var second: Array = (reporter.sent[2] as Array)[1]
	panel.apply("pause", first)
	panel.apply("pause", second)
	assert_array(panel.log_lines()).contains_exactly(["1  pause   ON  (menu)", "2  pause   OFF"])
	reporter.detach()
