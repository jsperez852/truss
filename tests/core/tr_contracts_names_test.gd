extends GdUnitTestSuite


func test_inner_classes_of_named_scripts_get_outer_dot_inner() -> void:
	assert_str(TrContracts.describe(FxNamedEvents.StaminaChanged)).is_equal("FxNamedEvents.StaminaChanged")
	assert_str(TrContracts.describe(FxNamedEvents.Nested.Deeper)).is_equal("FxNamedEvents.Nested.Deeper")
	assert_str(TrContracts.describe_value(FxNamedEvents.StaminaChanged.new())).is_equal("FxNamedEvents.StaminaChanged")


func test_preloaded_scripts_keep_their_own_name() -> void:
	assert_str(TrContracts.describe(FxNamedEvents.PRELOADED)).is_equal("FxHit")


func test_module_name_uses_inner_names() -> void:
	var boot := TrBootstrap.new()
	boot.add(FxInnerModules.Alpha.new())
	assert_array(boot.module_names()).contains_exactly(["FxInnerModules.Alpha"])


func test_unknown_scripts_still_fall_back() -> void:
	var anonymous := GDScript.new()
	anonymous.source_code = "extends TrEvent\n"
	anonymous.reload()
	assert_str(TrContracts.describe(anonymous)).is_equal("<unnamed TrEvent subclass>")
