extends GdUnitTestSuite
## Tests the "Truss" autoload script (instantiated by hand: the dev project doesn't enable the plugin).

const TrussScript: GDScript = preload("res://addons/truss/truss.gd")

var truss: Node


func before_test() -> void:
	truss = TrussScript.new()
	add_child(truss)


func after_test() -> void:
	truss.call(&"shutdown")
	truss.free()


func test_boot_injects_existing_and_new_nodes() -> void:
	var existing := FxInjectedNode.new()
	existing.name = "Existing"
	add_child(existing)
	var r: TrResult = truss.call(&"boot", [FxSaveModule.new([])])
	assert_bool(r.ok).is_true()
	assert_object(existing.store).is_not_null()
	var later := FxInjectedNode.new()
	add_child(later)
	assert_object(later.store).is_not_null()
	existing.free()
	later.free()


func test_boot_failure_leaves_no_container() -> void:
	var r: TrResult = truss.call(&"boot", [FxInventoryModule.new([])])
	assert_str(String(r.error)).is_equal(String(TrBootstrap.ERR_MISSING_DEPENDENCY))
	assert_bool(truss.call(&"is_booted")).is_false()
	assert_that(truss.get(&"container")).is_null()


func test_boot_twice_fails() -> void:
	truss.call(&"boot", [FxSaveModule.new([])])
	var r: TrResult = truss.call(&"boot", [FxSaveModule.new([])])
	assert_str(String(r.error)).is_equal(String(TrBootstrap.ERR_ALREADY_BOOTED))


func test_automatic_injection_can_be_disabled() -> void:
	ProjectSettings.set_setting("truss/injection/automatic", false)
	truss.call(&"boot", [FxSaveModule.new([])])
	var node := FxInjectedNode.new()
	add_child(node)
	assert_object(node.store).is_null()
	(truss.get(&"injector") as TrInjector).inject(node)
	assert_object(node.store).is_not_null()
	ProjectSettings.set_setting("truss/injection/automatic", true)
	node.free()


func test_shutdown_disposes_container() -> void:
	truss.call(&"boot", [FxSaveModule.new([])])
	var container := truss.get(&"container") as TrServiceContainer
	truss.call(&"shutdown")
	assert_bool(container.is_disposed()).is_true()
	assert_bool(truss.call(&"is_booted")).is_false()


func test_boot_registers_the_pause_service() -> void:
	truss.call(&"boot", [FxSaveModule.new([])])
	var container := truss.get(&"container") as TrServiceContainer
	assert_object(container.get_service(TrPause)).is_same(truss.get(&"pause"))
