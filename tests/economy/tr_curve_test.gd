extends GdUnitTestSuite


## The upgrade formula of an idle game, written by hand: cost = ceil(cost * 1.3) per level, ×3 every 25 levels.
func _hand_written(base: float, multiplier: float, levels: int) -> PackedFloat64Array:
	var values := PackedFloat64Array([base])
	var value: float = base
	for level: int in range(1, levels + 1):
		value = ceil(multiplier * value)
		if level % 25 == 0:
			value *= 3
		values.append(value)
	return values


func _idle_curve(base: float, multiplier: float) -> TrCurve:
	var curve := TrCurve.exponential(base, multiplier)
	curve.rounding = TrCurve.Rounding.CEIL
	curve.round_each_level = true
	curve.milestone_every = 25
	curve.milestone_multiplier = 3.0
	return curve


func test_round_each_level_matches_a_hand_written_idle_formula() -> void:
	for pair: Array in [[3.0, 1.3], [4.0, 1.2]]:
		var base: float = pair[0]
		var multiplier: float = pair[1]
		var expected: PackedFloat64Array = _hand_written(base, multiplier, 75)
		var curve := _idle_curve(base, multiplier)
		for level: int in expected.size():
			assert_float(curve.value_at(level)).is_equal(expected[level])


func test_closed_form_exponential_and_linear() -> void:
	var exp_curve := TrCurve.exponential(10.0, 2.0)
	assert_float(exp_curve.value_at(0)).is_equal(10.0)
	assert_float(exp_curve.value_at(3)).is_equal(80.0)
	exp_curve.milestone_every = 2
	exp_curve.milestone_multiplier = 10.0
	assert_float(exp_curve.value_at(3)).is_equal(800.0)
	var lin := TrCurve.linear(5.0, 2.5)
	lin.rounding = TrCurve.Rounding.FLOOR
	assert_float(lin.value_at(3)).is_equal(12.0)
	assert_float(lin.value_at(-4)).is_equal(5.0)


func test_table_and_limits() -> void:
	var curve := TrCurve.from_table(PackedFloat64Array([1.0, 4.0, 9.0]))
	assert_float(curve.value_at(1)).is_equal(4.0)
	assert_float(curve.value_at(10)).is_equal(9.0)
	curve.max_value = 5.0
	assert_float(curve.value_at(2)).is_equal(5.0)


func test_total_and_max_affordable() -> void:
	var curve := TrCurve.linear(10.0, 10.0)   # 10, 20, 30, 40...
	assert_float(curve.total(0, 3)).is_equal(60.0)
	assert_float(curve.total(2, 2)).is_equal(70.0)
	assert_int(curve.max_affordable(0, 65.0)).is_equal(3)
	assert_int(curve.max_affordable(1, 19.0)).is_equal(0)
	assert_int(curve.max_affordable(0, 1e12, 5)).is_equal(5)


func test_changing_a_property_recomputes_cached_levels() -> void:
	var curve := _idle_curve(3.0, 1.3)
	var before: float = curve.value_at(30)
	curve.rate = 1.5
	assert_float(curve.value_at(30)).is_not_equal(before)


func test_saved_curve_resource_round_trips() -> void:
	var curve := _idle_curve(3.0, 1.3)
	var path := "user://truss_curve_test.tres"
	assert_int(ResourceSaver.save(curve, path)).is_equal(OK)
	var loaded: TrCurve = ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE)
	assert_float(loaded.value_at(50)).is_equal(curve.value_at(50))
	DirAccess.remove_absolute(path)
