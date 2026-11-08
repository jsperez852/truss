extends GdUnitTestSuite


func test_implements_follows_script_inheritance() -> void:
	var store := FxMemoryStore.new()
	assert_bool(TrContracts.implements(store, FxStore)).is_true()
	assert_bool(TrContracts.implements(store, FxMemoryStore)).is_true()
	assert_bool(TrContracts.implements(FxService.new(), FxStore)).is_false()


func test_implements_rejects_non_objects_and_null() -> void:
	assert_bool(TrContracts.implements(null, FxStore)).is_false()
	assert_bool(TrContracts.implements(5, FxStore)).is_false()
	assert_bool(TrContracts.implements(FxMemoryStore.new(), null)).is_false()


func test_implements_rejects_freed_objects() -> void:
	var script := GDScript.new()
	script.source_code = "extends Node\n"
	script.reload()
	var node := Node.new()
	node.set_script(script)
	assert_bool(TrContracts.implements(node, script)).is_true()
	node.free()
	assert_bool(TrContracts.implements(node, script)).is_false()
	assert_str(TrContracts.describe_value(node)).is_equal("<freed object>")


func test_require_reports_with_context() -> void:
	await assert_error(func() -> void: TrContracts.require(FxService.new(), FxStore, "setup")) \
		.is_push_error("setup: FxService does not implement FxStore")


func test_require_passes() -> void:
	assert_bool(TrContracts.require(FxMemoryStore.new(), FxStore)).is_true()


func test_describe() -> void:
	assert_str(TrContracts.describe(FxStore)).is_equal("FxStore")
	assert_str(TrContracts.describe(null)).is_equal("<null script>")
	var anonymous := GDScript.new()
	anonymous.source_code = "extends RefCounted\n"
	anonymous.reload()
	assert_str(TrContracts.describe(anonymous)).is_equal("<anonymous script>")
	var inner := GDScript.new()
	inner.source_code = "extends FxMemoryStore\n"
	inner.reload()
	assert_str(TrContracts.describe(inner)).is_equal("<unnamed FxMemoryStore subclass>")


func test_describe_value() -> void:
	assert_str(TrContracts.describe_value(null)).is_equal("null")
	assert_str(TrContracts.describe_value(3)).is_equal("int")
	assert_str(TrContracts.describe_value(FxMemoryStore.new())).is_equal("FxMemoryStore")
	var plain := RefCounted.new()
	assert_str(TrContracts.describe_value(plain)).is_equal("RefCounted")
