extends GdUnitTestSuite
## Zero-argument handlers and handlers bound to nodes (Truss 0.5.1).

var bus: TrEventBus
var calls: int


func before_test() -> void:
	bus = TrEventBus.new()
	calls = 0


func _count() -> void:
	calls += 1


func _listener() -> Node:
	var script := GDScript.new()
	script.source_code = "extends Node\nvar got: int = 0\nfunc on_hit() -> void:\n\tgot += 1\n"
	script.reload()
	var node := Node.new()
	node.set_script(script)
	return node


func test_zero_argument_handlers_are_called_without_the_event() -> void:
	bus.subscribe(FxHit, _count)
	bus.subscribe(FxHit, func() -> void: calls += 10)
	assert_int(bus.publish(FxHit.new(1))).is_equal(2)
	assert_int(calls).is_equal(11)


func test_bound_arguments_count_as_given() -> void:
	var seen: Array = []
	bus.subscribe(FxHit, (func(e: FxHit, tag: String) -> void: seen.append([tag, e.damage])).bind("tagged"))
	bus.publish(FxHit.new(4))
	assert_array(seen).contains_exactly([["tagged", 4]])


func test_handlers_with_two_arguments_are_rejected() -> void:
	var out: Array[bool] = []
	await assert_error(func() -> void: out.append(bus.subscribe(FxHit, func(_a: Variant, _b: Variant) -> void: pass))) \
		.is_push_error("TrEventBus.subscribe(): handler for FxHit takes 2 arguments (expected the event, or none)")
	assert_array(out).contains_exactly([false])


func test_node_handlers_are_skipped_outside_the_tree() -> void:
	var node := _listener()
	add_child(node)
	bus.subscribe(FxHit, Callable(node, &"on_hit"))
	bus.publish(FxHit.new(1))
	remove_child(node)
	assert_int(bus.publish(FxHit.new(1))).is_equal(0)
	add_child(node)
	bus.publish(FxHit.new(1))
	assert_int(node.get(&"got")).is_equal(2)
	assert_int(bus.subscriber_count(FxHit)).is_equal(1)
	node.free()


func test_outside_tree_option_delivers_anyway() -> void:
	var node := _listener()
	bus.subscribe(FxHit, Callable(node, &"on_hit"), {outside_tree = true})
	bus.publish(FxHit.new(1))
	assert_int(node.get(&"got")).is_equal(1)
	node.free()


func test_queue_freed_nodes_need_no_unsubscribe() -> void:
	var node := _listener()
	add_child(node)
	bus.subscribe(FxHit, Callable(node, &"on_hit"))
	node.queue_free()
	await get_tree().process_frame
	assert_int(bus.publish(FxHit.new(1))).is_equal(0)
	assert_int(bus.subscriber_count(FxHit)).is_equal(0)


func test_handlers_on_ref_counted_objects_ignore_the_tree() -> void:
	var listener := FxListener.new()
	bus.subscribe(FxHit, listener.on_hit)
	assert_int(bus.publish(FxHit.new(1))).is_equal(1)
