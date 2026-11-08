extends GdUnitTestSuite


func test_success_holds_value() -> void:
	var r: TrResult = TrResult.success(5)
	assert_bool(r.ok).is_true()
	assert_bool(r.is_ok()).is_true()
	assert_bool(r.is_err()).is_false()
	assert_int(r.value).is_equal(5)
	assert_str(String(r.error)).is_empty()


func test_success_without_value() -> void:
	var r: TrResult = TrResult.success()
	assert_bool(r.ok).is_true()
	assert_that(r.value).is_null()


func test_failure_holds_code_and_message() -> void:
	var r: TrResult = TrResult.failure(&"inventory_full", "no slot")
	assert_bool(r.is_err()).is_true()
	assert_str(String(r.error)).is_equal("inventory_full")
	assert_str(r.message).is_equal("no slot")
	assert_that(r.value).is_null()


func test_unwrap_or() -> void:
	assert_int(TrResult.success(3).unwrap_or(0)).is_equal(3)
	assert_int(TrResult.failure(&"x").unwrap_or(9)).is_equal(9)


func test_unwrap_success() -> void:
	assert_int(TrResult.success(4).unwrap()).is_equal(4)


func test_unwrap_failure_reports_error() -> void:
	await assert_error(func() -> void: TrResult.failure(&"boom").unwrap()) \
		.is_push_error("TrResult.unwrap() called on a failure: TrResult.failure(boom)")


func test_map_transforms_success_only() -> void:
	var doubled: TrResult = TrResult.success(4).map(func(v: int) -> int: return v * 2)
	assert_int(doubled.value).is_equal(8)
	var failed: TrResult = TrResult.failure(&"x")
	assert_object(failed.map(func(v: int) -> int: return v * 2)).is_same(failed)


func test_and_then_chains_results() -> void:
	var half := func(v: int) -> TrResult:
		return TrResult.success(v / 2) if v % 2 == 0 else TrResult.failure(&"odd")
	assert_int(TrResult.success(8).and_then(half).and_then(half).value).is_equal(2)
	var r: TrResult = TrResult.success(6).and_then(half).and_then(half)
	assert_str(String(r.error)).is_equal("odd")


func test_and_then_requires_result() -> void:
	# Lambdas capture locals by value, so the result is passed out through an array.
	var out: Array[TrResult] = []
	await assert_error(func() -> void: out.append(TrResult.success(1).and_then(func(v: int) -> int: return v))) \
		.is_push_error("TrResult.and_then(): the callable must return a TrResult, got int")
	assert_str(String(out[0].error)).is_equal("invalid_result")


func test_to_string() -> void:
	assert_str(str(TrResult.success(1))).is_equal("TrResult.success(1)")
	assert_str(str(TrResult.failure(&"full", "no slot"))).is_equal("TrResult.failure(full, \"no slot\")")
	assert_str(str(TrResult.failure(&"full"))).is_equal("TrResult.failure(full)")
