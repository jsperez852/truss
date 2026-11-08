extends GdUnitTestSuite

var bus: TrEventBus
var listener: FxListener


func before_test() -> void:
	bus = TrEventBus.new()
	listener = FxListener.new()


func test_publish_reaches_subscribers_of_the_class() -> void:
	bus.subscribe(FxHit, listener.on_hit)
	assert_int(bus.publish(FxHit.new(3))).is_equal(1)
	assert_array(listener.received).contains_exactly(["hit:3"])


func test_base_class_subscribers_receive_subclasses() -> void:
	bus.subscribe(FxHit, listener.on_hit)
	bus.subscribe(FxEvent, listener.on_any)
	bus.publish(FxHit.new(2))
	assert_array(listener.received).contains_exactly(["hit:2", "any:FxHit"])


func test_subscribing_twice_is_ignored() -> void:
	bus.subscribe(FxHit, listener.on_hit)
	bus.subscribe(FxHit, listener.on_hit)
	assert_int(bus.subscriber_count(FxHit)).is_equal(1)
	bus.publish(FxHit.new(1))
	assert_int(listener.received.size()).is_equal(1)


func test_unsubscribe() -> void:
	bus.subscribe(FxHit, listener.on_hit)
	bus.unsubscribe(FxHit, listener.on_hit)
	assert_int(bus.publish(FxHit.new(1))).is_equal(0)


func test_unsubscribe_all_for_target() -> void:
	var other := FxListener.new()
	bus.subscribe(FxHit, listener.on_hit)
	bus.subscribe(FxEvent, listener.on_any)
	bus.subscribe(FxHit, other.on_hit)
	bus.unsubscribe_all(listener)
	bus.publish(FxHit.new(5))
	assert_array(listener.received).is_empty()
	assert_array(other.received).contains_exactly(["hit:5"])


func test_handlers_of_freed_objects_are_dropped() -> void:
	var script := GDScript.new()
	script.source_code = "extends Node\nvar got: int = 0\nfunc on_hit(_e: Object) -> void:\n\tgot += 1\n"
	script.reload()
	var node := Node.new()
	node.set_script(script)
	bus.subscribe(FxHit, Callable(node, &"on_hit"))
	assert_int(bus.publish(FxHit.new(1))).is_equal(1)
	node.free()
	assert_int(bus.publish(FxHit.new(1))).is_equal(0)
	assert_int(bus.subscriber_count(FxHit)).is_equal(0)


func test_unsubscribe_during_publish_skips_later_handler() -> void:
	var other := FxListener.new()
	bus.subscribe(FxHit, func(_e: FxHit) -> void: bus.unsubscribe(FxHit, other.on_hit))
	bus.subscribe(FxHit, other.on_hit)
	bus.publish(FxHit.new(1))
	assert_array(other.received).is_empty()


func test_subscribe_during_publish_applies_next_time() -> void:
	bus.subscribe(FxHit, func(_e: FxHit) -> void: bus.subscribe(FxHit, listener.on_hit))
	bus.publish(FxHit.new(1))
	assert_array(listener.received).is_empty()
	bus.publish(FxHit.new(2))
	assert_array(listener.received).contains_exactly(["hit:2"])


func test_rejects_non_event_types() -> void:
	var out: Array[bool] = []
	await assert_error(func() -> void: out.append(bus.subscribe(FxStore, listener.on_hit))) \
		.is_push_error("TrEventBus.subscribe(): FxStore is not a TrEvent subclass")
	assert_bool(out[0]).is_false()


func test_publish_null_reports_error() -> void:
	await assert_error(func() -> void: bus.publish(null)).is_push_error("TrEventBus.publish(): event is null")


func test_clear() -> void:
	bus.subscribe(FxHit, listener.on_hit)
	bus.clear()
	assert_int(bus.publish(FxHit.new(1))).is_equal(0)
