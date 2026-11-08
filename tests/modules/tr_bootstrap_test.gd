extends GdUnitTestSuite

var log: Array[String]


func before_test() -> void:
	log = []


func test_boots_in_dependency_order() -> void:
	var boot := TrBootstrap.new()
	boot.add(FxUiModule.new(log)).add(FxInventoryModule.new(log)).add(FxSaveModule.new(log))
	var r: TrResult = boot.boot()
	assert_bool(r.ok).is_true()
	assert_object(r.value).is_same(boot.get_container())
	assert_bool(boot.is_booted()).is_true()
	assert_array(log).contains_exactly([
		"register FxSaveModule", "register FxInventoryModule", "register FxUiModule",
		"start FxSaveModule", "start FxInventoryModule", "inventory sees store=7", "start FxUiModule",
	])


func test_independent_modules_keep_added_order() -> void:
	var boot := TrBootstrap.new()
	boot.add_all([FxSaveModule.new(log), FxBrokenModule.new([])])
	var r: TrResult = boot.order()
	var names: Array[String] = []
	for module: TrModule in r.value:
		names.append(TrContracts.describe_value(module))
	assert_array(names).contains_exactly(["FxSaveModule", "FxBrokenModule"])


func test_missing_dependency_fails_before_registering() -> void:
	var boot := TrBootstrap.new()
	boot.add(FxInventoryModule.new(log))
	var r: TrResult = boot.boot()
	assert_str(String(r.error)).is_equal(String(TrBootstrap.ERR_MISSING_DEPENDENCY))
	assert_str(r.message).is_equal("FxInventoryModule depends on FxSaveModule, which was not added")
	assert_array(log).is_empty()
	assert_bool(boot.is_booted()).is_false()


func test_cycle_fails_with_path() -> void:
	var boot := TrBootstrap.new()
	boot.add(FxCycleModuleA.new(log)).add(FxCycleModuleB.new(log))
	var r: TrResult = boot.boot()
	assert_str(String(r.error)).is_equal(String(TrBootstrap.ERR_MODULE_CYCLE))
	assert_str(r.message).is_equal("module dependency cycle: FxCycleModuleA -> FxCycleModuleB -> FxCycleModuleA")
	assert_array(log).is_empty()


func test_duplicate_module() -> void:
	var boot := TrBootstrap.new()
	boot.add(FxSaveModule.new(log)).add(FxSaveModule.new(log))
	var r: TrResult = boot.boot()
	assert_str(String(r.error)).is_equal(String(TrBootstrap.ERR_DUPLICATE_MODULE))
	assert_str(r.message).is_equal("module added twice: FxSaveModule")


func test_invalid_container_fails_without_starting() -> void:
	var boot := TrBootstrap.new()
	boot.add(FxBrokenModule.new(log))
	var r: TrResult = boot.boot()
	assert_str(String(r.error)).is_equal(String(TrBootstrap.ERR_INVALID_CONTAINER))
	assert_str(r.message).contains("FxStore is not registered")
	assert_array(log).contains_exactly(["register FxBrokenModule"])
	assert_bool(boot.is_booted()).is_false()


func test_boot_twice() -> void:
	var boot := TrBootstrap.new()
	boot.add(FxSaveModule.new(log))
	boot.boot()
	assert_str(String(boot.boot().error)).is_equal(String(TrBootstrap.ERR_ALREADY_BOOTED))


func test_shutdown_stops_in_reverse_and_disposes() -> void:
	var boot := TrBootstrap.new()
	boot.add(FxInventoryModule.new(log)).add(FxSaveModule.new(log))
	boot.boot()
	log.clear()
	boot.shutdown()
	assert_array(log).contains_exactly(["stop FxInventoryModule", "stop FxSaveModule"])
	assert_bool(boot.get_container().is_disposed()).is_true()


func test_uses_given_container_with_overrides() -> void:
	var c := TrServiceContainer.new()
	var boot := TrBootstrap.new(c)
	boot.add(FxSaveModule.new(log)).add(FxInventoryModule.new(log))
	var fake := FxMemoryStore.new()
	fake.stored = 42
	# Overrides go in a child scope... or after register: here the test replaces the store after boot ordering.
	boot.boot()
	assert_object(boot.get_container()).is_same(c)
	c.instance(FxStore, fake)
	assert_int((c.get_service(FxService) as FxService).store.value()).is_equal(42)


func test_module_names() -> void:
	var boot := TrBootstrap.new()
	boot.add(FxSaveModule.new(log)).add(FxInventoryModule.new(log))
	assert_array(boot.module_names()).contains_exactly(["FxSaveModule", "FxInventoryModule"])
