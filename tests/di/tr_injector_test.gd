extends GdUnitTestSuite

var c: TrServiceContainer
var injector: TrInjector


func before_test() -> void:
	c = TrServiceContainer.new()
	c.singleton(FxStore, func() -> FxStore: return FxMemoryStore.new())
	injector = TrInjector.new(c)


func after_test() -> void:
	injector.detach()
	c.dispose()


func _make(node_name: String, shared_log: Array[String]) -> FxInjectedNode:
	var node := FxInjectedNode.new()
	node.name = node_name
	node.log = shared_log
	return node


func test_attached_injector_runs_before_ready_parent_first() -> void:
	var shared: Array[String] = []
	injector.attach(get_tree())
	var parent: FxInjectedNode = _make("Parent", shared)
	parent.add_child(_make("Child", shared))
	add_child(parent)
	assert_array(shared).contains_exactly(["inject Parent", "inject Child", "ready Child store=true", "ready Parent store=true"])
	assert_int(injector.injected_count()).is_equal(2)
	parent.free()


func test_nodes_without_inject_are_ignored() -> void:
	injector.attach(get_tree())
	var plain: Node = auto_free(Node.new())
	add_child(plain)
	assert_int(injector.injected_count()).is_equal(0)


func test_injects_once_when_node_reenters_tree() -> void:
	var shared: Array[String] = []
	injector.attach(get_tree())
	var node: FxInjectedNode = _make("Node", shared)
	add_child(node)
	remove_child(node)
	add_child(node)
	assert_int(node.inject_calls).is_equal(1)
	node.free()


func test_detach_stops_injection() -> void:
	injector.attach(get_tree())
	injector.detach()
	assert_bool(injector.is_attached()).is_false()
	var node: FxInjectedNode = _make("Node", [])
	add_child(node)
	assert_int(node.inject_calls).is_equal(0)
	node.free()


func test_explicit_inject() -> void:
	var node: FxInjectedNode = auto_free(_make("Node", []))
	assert_bool(injector.inject(node)).is_true()
	assert_bool(injector.inject(node)).is_false()
	assert_object(node.store).is_not_null()


func test_inject_tree_handles_existing_nodes() -> void:
	var shared: Array[String] = []
	var parent: FxInjectedNode = _make("Parent", shared)
	parent.add_child(_make("Child", shared))
	add_child(parent)
	assert_int(injector.inject_tree(parent)).is_equal(2)
	assert_int(injector.inject_tree(parent)).is_equal(0)
	parent.free()


func test_set_container_switches_scope() -> void:
	var scope: TrServiceContainer = c.create_scope()
	var local := FxMemoryStore.new()
	local.stored = 99
	scope.instance(FxStore, local)
	injector.set_container(scope)
	var node: FxInjectedNode = auto_free(_make("Node", []))
	injector.inject(node)
	assert_int(node.store.value()).is_equal(99)
	assert_object(injector.get_container()).is_same(scope)


func test_disposed_container_reports_error() -> void:
	c.dispose()
	var node: FxInjectedNode = auto_free(_make("Node", []))
	var out: Array[bool] = []
	await assert_error(func() -> void: out.append(injector.inject(node))) \
		.is_push_error("TrInjector: no usable container to inject ")
	assert_bool(out[0]).is_false()
