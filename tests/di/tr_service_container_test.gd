extends GdUnitTestSuite

var c: TrServiceContainer


func before_test() -> void:
	c = TrServiceContainer.new()


func after_test() -> void:
	c.dispose()


func test_singleton_is_created_once_and_lazily() -> void:
	var made: Array[int] = [0]
	c.singleton(FxStore, func() -> FxStore:
		made[0] += 1
		return FxMemoryStore.new())
	assert_int(made[0]).is_equal(0)
	var first: Object = c.get_service(FxStore)
	assert_object(first).is_instanceof(FxMemoryStore)
	assert_object(c.get_service(FxStore)).is_same(first)
	assert_int(made[0]).is_equal(1)


func test_transient_is_new_each_time() -> void:
	c.transient(FxService, func() -> FxService: return FxService.new())
	assert_object(c.get_service(FxService)).is_not_same(c.get_service(FxService))


func test_instance_registration() -> void:
	var store := FxMemoryStore.new()
	c.instance(FxStore, store)
	assert_object(c.get_service(FxStore)).is_same(store)


func test_instance_must_implement_contract() -> void:
	await assert_error(func() -> void: c.instance(FxStore, FxService.new())) \
		.is_push_error("TrServiceContainer.instance(): FxService does not implement FxStore")
	assert_bool(c.has(FxStore)).is_false()


func test_factory_receives_resolving_container() -> void:
	c.singleton(FxStore, func() -> FxStore: return FxMemoryStore.new())
	c.transient(FxService, func(s: TrServiceContainer) -> FxService: return FxService.new(s.get_service(FxStore) as FxStore))
	var service := c.get_service(FxService) as FxService
	assert_int(service.store.value()).is_equal(7)


func test_missing_registration() -> void:
	var r: TrResult = c.resolve(FxStore)
	assert_str(String(r.error)).is_equal(String(TrServiceContainer.ERR_NOT_REGISTERED))
	assert_str(r.message).is_equal("FxStore is not registered")
	await assert_error(func() -> void: c.get_service(FxStore)) \
		.is_push_error("TrServiceContainer: FxStore is not registered")


func test_factory_returning_wrong_type() -> void:
	c.singleton(FxStore, func() -> Object: return FxService.new())
	var r: TrResult = c.resolve(FxStore)
	assert_str(String(r.error)).is_equal(String(TrServiceContainer.ERR_CONTRACT))
	assert_str(r.message).is_equal("FxStore: factory returned FxService")


func test_factory_returning_null() -> void:
	c.transient(FxStore, func() -> Object: return null)
	var r: TrResult = c.resolve(FxStore)
	assert_str(String(r.error)).is_equal(String(TrServiceContainer.ERR_FACTORY))


func test_cycle_is_detected_with_chain() -> void:
	c.singleton(FxCycleA, func(s: TrServiceContainer) -> FxCycleA:
		s.get_service(FxCycleB)
		return FxCycleA.new())
	c.singleton(FxCycleB, func(s: TrServiceContainer) -> FxCycleB:
		s.get_service(FxCycleA)
		return FxCycleB.new())
	await assert_error(func() -> void: c.get_service(FxCycleA)) \
		.is_push_error("TrServiceContainer: dependency cycle: FxCycleA -> FxCycleB -> FxCycleA")


func test_scope_sees_parent_and_overrides() -> void:
	c.singleton(FxStore, func() -> FxStore: return FxMemoryStore.new())
	var scope: TrServiceContainer = c.create_scope()
	assert_object(scope.get_service(FxStore)).is_same(c.get_service(FxStore))
	var local := FxMemoryStore.new()
	local.stored = 99
	scope.instance(FxStore, local)
	assert_int((scope.get_service(FxStore) as FxStore).value()).is_equal(99)
	assert_int((c.get_service(FxStore) as FxStore).value()).is_equal(7)
	scope.dispose()


func test_scoped_lifetime_is_per_scope() -> void:
	c.scoped(FxService, func() -> FxService: return FxService.new())
	var a: TrServiceContainer = c.create_scope()
	var b: TrServiceContainer = c.create_scope()
	var in_a: Object = a.get_service(FxService)
	assert_object(a.get_service(FxService)).is_same(in_a)
	assert_object(b.get_service(FxService)).is_not_same(in_a)
	a.dispose()
	b.dispose()


func test_singleton_from_child_scope_lives_in_owner() -> void:
	c.singleton(FxStore, func() -> FxStore: return FxMemoryStore.new())
	var scope: TrServiceContainer = c.create_scope()
	var from_child: Object = scope.get_service(FxStore)
	scope.dispose()
	assert_object(c.get_service(FxStore)).is_same(from_child)


func test_dispose_calls_dispose_and_frees_nodes() -> void:
	var made: Array[FxDisposable] = []
	c.singleton(FxDisposable, func() -> FxDisposable:
		var d := FxDisposable.new()
		made.append(d)
		return d)
	var node_script := GDScript.new()
	node_script.source_code = "extends Node\n"
	node_script.reload()
	c.singleton(node_script, func() -> Node:
		var n := Node.new()
		n.set_script(node_script)
		return n)
	var node: Object = c.get_service(node_script)
	c.get_service(FxDisposable)
	c.dispose()
	assert_int(made[0].disposed).is_equal(1)
	assert_bool(is_instance_valid(node)).is_false()
	assert_bool(c.is_disposed()).is_true()
	assert_str(String(c.resolve(FxDisposable).error)).is_equal(String(TrServiceContainer.ERR_DISPOSED))


func test_dispose_leaves_external_instances() -> void:
	var external := FxDisposable.new()
	c.instance(FxDisposable, external)
	c.dispose()
	assert_int(external.disposed).is_equal(0)


func test_dispose_parent_disposes_children() -> void:
	var scope: TrServiceContainer = c.create_scope()
	c.dispose()
	assert_bool(scope.is_disposed()).is_true()


func test_validate_success_creates_singletons() -> void:
	var made: Array[int] = [0]
	c.singleton(FxStore, func() -> FxStore:
		made[0] += 1
		return FxMemoryStore.new())
	c.transient(FxService, func(s: TrServiceContainer) -> FxService: return FxService.new(s.get_service(FxStore) as FxStore))
	assert_bool(c.validate().ok).is_true()
	assert_int(made[0]).is_equal(1)


func test_validate_lists_every_problem_without_errors() -> void:
	c.transient(FxService, func(s: TrServiceContainer) -> FxService: return FxService.new(s.get_service(FxStore) as FxStore))
	c.singleton(FxCycleA, func(s: TrServiceContainer) -> FxCycleA:
		s.get_service(FxCycleB)
		return FxCycleA.new())
	c.singleton(FxCycleB, func(s: TrServiceContainer) -> FxCycleB:
		s.get_service(FxCycleA)
		return FxCycleB.new())
	c.singleton(FxDisposable, func() -> Object: return FxService.new())
	var r: TrResult = c.validate()
	assert_bool(r.ok).is_false()
	assert_str(r.message).contains("FxStore is not registered")
	assert_str(r.message).contains("dependency cycle: FxCycleA -> FxCycleB -> FxCycleA")
	assert_str(r.message).contains("FxDisposable: factory returned FxService")


func test_validate_does_not_keep_scoped_instances() -> void:
	var made: Array[int] = [0]
	c.scoped(FxService, func() -> FxService:
		made[0] += 1
		return FxService.new())
	c.validate()
	c.get_service(FxService)
	assert_int(made[0]).is_equal(2)


func test_registered_contracts_and_lifetime() -> void:
	c.singleton(FxStore, func() -> FxStore: return FxMemoryStore.new())
	var scope: TrServiceContainer = c.create_scope()
	scope.transient(FxService, func() -> FxService: return FxService.new())
	assert_array(scope.registered_contracts()).contains_exactly_in_any_order([FxStore, FxService])
	assert_int(scope.lifetime_of(FxService)).is_equal(TrServiceContainer.Lifetime.TRANSIENT)
	assert_int(scope.lifetime_of(FxStore)).is_equal(TrServiceContainer.Lifetime.SINGLETON)
	assert_int(scope.lifetime_of(FxCycleA)).is_equal(-1)
	scope.dispose()


func test_container_and_scopes_are_freed_when_unreferenced() -> void:
	var local := TrServiceContainer.new()
	local.singleton(FxStore, func() -> FxStore: return FxMemoryStore.new())
	local.transient(FxService, func(s: TrServiceContainer) -> FxService: return FxService.new(s.get_service(FxStore) as FxStore))
	local.get_service(FxService)
	var scope: TrServiceContainer = local.create_scope()
	scope.scoped(FxDisposable, func() -> FxDisposable: return FxDisposable.new())
	scope.get_service(FxDisposable)
	var store_ref: WeakRef = weakref(local.get_service(FxStore))
	var local_ref: WeakRef = weakref(local)
	var scope_ref: WeakRef = weakref(scope)
	local = null
	scope = null
	assert_object(local_ref.get_ref()).is_null()
	assert_object(scope_ref.get_ref()).is_null()
	assert_object(store_ref.get_ref()).is_null()


func test_fast_path_returns_created_singleton() -> void:
	c.singleton(FxStore, func() -> FxStore: return FxMemoryStore.new())
	var first: Object = c.get_service(FxStore)
	for i: int in 3:
		assert_object(c.get_service(FxStore)).is_same(first)


func test_replacing_registration_warns() -> void:
	c.singleton(FxStore, func() -> FxStore: return FxMemoryStore.new())
	c.instance(FxStore, FxMemoryStore.new())
	assert_int(c.lifetime_of(FxStore)).is_equal(TrServiceContainer.Lifetime.INSTANCE)
