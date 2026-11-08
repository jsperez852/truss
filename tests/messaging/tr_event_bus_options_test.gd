extends GdUnitTestSuite

var bus: TrEventBus
var order: Array[String]


func before_test() -> void:
	bus = TrEventBus.new()
	order = []


func _rec(label: String) -> Callable:
	return func(_e: TrEvent) -> void: order.append(label)


func test_priority_runs_higher_first_and_ties_keep_order() -> void:
	bus.subscribe(FxHit, _rec("a0"))
	bus.subscribe(FxHit, _rec("b10"), {priority = 10})
	bus.subscribe(FxHit, _rec("c0"))
	bus.subscribe(FxHit, _rec("d-5"), {priority = -5})
	bus.subscribe(FxHit, _rec("e10"), {priority = 10})
	bus.publish(FxHit.new(1))
	assert_array(order).contains_exactly(["b10", "e10", "a0", "c0", "d-5"])


func test_priority_applies_across_the_class_hierarchy() -> void:
	bus.subscribe(FxHit, _rec("hit0"))
	bus.subscribe(FxEvent, _rec("base5"), {priority = 5})
	bus.subscribe(FxEvent, _rec("base0"))
	bus.publish(FxHit.new(1))
	assert_array(order).contains_exactly(["base5", "hit0", "base0"])


func test_source_filter() -> void:
	var player := Node.new()
	var enemy := Node.new()
	bus.subscribe(FxHit, _rec("player"), {source = player})
	bus.subscribe(FxHit, _rec("enemy"), {source = enemy})
	bus.subscribe(FxHit, _rec("all"))
	bus.publish(FxHit.new(1), player)
	bus.publish(FxHit.new(1))
	assert_array(order).contains_exactly(["player", "all", "all"])
	player.free()
	enemy.free()


func test_publish_sets_event_source() -> void:
	var sender := RefCounted.new()
	var seen: Array[Object] = []
	bus.subscribe(FxHit, func(e: FxHit) -> void: seen.append(e.source))
	bus.publish(FxHit.new(1), sender)
	assert_object(seen[0]).is_same(sender)


func test_freed_source_subscription_is_dropped() -> void:
	var owner_node := Node.new()
	bus.subscribe(FxHit, _rec("x"), {source = owner_node})
	assert_int(bus.subscriber_count(FxHit)).is_equal(1)
	owner_node.free()
	assert_int(bus.subscriber_count(FxHit)).is_equal(0)
	assert_int(bus.publish(FxHit.new(1))).is_equal(0)


func test_invalid_options() -> void:
	var out: Array[bool] = []
	await assert_error(func() -> void: out.append(bus.subscribe(FxHit, _rec("x"), {prio = 1}))) \
		.is_push_error("TrEventBus.subscribe(): unknown option prio (valid: priority, source)")
	await assert_error(func() -> void: out.append(bus.subscribe(FxHit, _rec("y"), {priority = "high"}))) \
		.is_push_error("TrEventBus.subscribe(): priority must be an int, got String")
	assert_array(out).contains_exactly([false, false])


func test_subscribe_during_publish_uses_next_event_and_cache_refreshes() -> void:
	var late := _rec("late")
	bus.subscribe(FxHit, func(_e: FxHit) -> void:
		order.append("first")
		bus.subscribe(FxHit, late, {priority = 100}))
	bus.publish(FxHit.new(1))
	bus.publish(FxHit.new(1))
	assert_array(order).contains_exactly(["first", "late", "first"])


func test_dictionary_string_and_stringname_keys_are_the_same() -> void:
	# Documents the GDScript behavior relied on by transition_args and options.
	var lua_style := {hitstun = 0.3}
	assert_bool(lua_style.has("hitstun")).is_true()
	assert_bool(lua_style.has(&"hitstun")).is_true()
