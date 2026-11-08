extends GdUnitTestSuite


func test_some() -> void:
	var o: TrOption = TrOption.some(3)
	assert_bool(o.is_some()).is_true()
	assert_bool(o.is_none()).is_false()
	assert_int(o.unwrap()).is_equal(3)
	assert_int(o.unwrap_or(0)).is_equal(3)


func test_some_null_is_still_some() -> void:
	var o: TrOption = TrOption.some(null)
	assert_bool(o.is_some()).is_true()
	assert_that(o.unwrap_or(5)).is_null()


func test_none() -> void:
	var o: TrOption = TrOption.none()
	assert_bool(o.is_none()).is_true()
	assert_int(o.unwrap_or(7)).is_equal(7)


func test_unwrap_none_reports_error() -> void:
	await assert_error(func() -> void: TrOption.none().unwrap()).is_push_error("TrOption.unwrap() called on none()")


func test_ok_or() -> void:
	assert_int(TrOption.some(2).ok_or(&"missing").value).is_equal(2)
	var r: TrResult = TrOption.none().ok_or(&"missing", "not found")
	assert_str(String(r.error)).is_equal("missing")
	assert_str(r.message).is_equal("not found")


func test_to_string() -> void:
	assert_str(str(TrOption.some(1))).is_equal("TrOption.some(1)")
	assert_str(str(TrOption.none())).is_equal("TrOption.none()")
