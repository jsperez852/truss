extends GdUnitTestSuite


func test_formula_flat_percent_multiply() -> void:
	var s := TrStat.new(10.0)
	s.add(TrModifier.flat(5.0, &"sword"))
	s.add(TrModifier.percent(0.2, &"buff"))
	s.add(TrModifier.percent(0.1, &"aura"))
	s.add(TrModifier.multiply(1.5, &"rage"))
	s.add(TrModifier.multiply(2.0, &"crit"))
	# (10 + 5) x (1 + 0.3) x 3
	assert_float(s.value).is_equal_approx(58.5, 0.0001)


func test_base_and_clamps() -> void:
	var s := TrStat.new(50.0, 0.0, 100.0)
	s.add(TrModifier.flat(80.0))
	assert_float(s.value).is_equal(100.0)
	s.base = -200.0
	assert_float(s.value).is_equal(0.0)
	s.max_value = INF
	s.base = 50.0
	assert_float(s.value).is_equal(130.0)


func test_remove_and_remove_from() -> void:
	var s := TrStat.new(10.0)
	var m: TrModifier = s.add(TrModifier.flat(5.0, &"a"))
	s.add(TrModifier.flat(1.0, &"b"))
	s.add(TrModifier.percent(1.0, &"b"))
	assert_float(s.value).is_equal(32.0)
	assert_int(s.remove_from(&"b")).is_equal(2)
	assert_float(s.value).is_equal(15.0)
	assert_bool(s.remove(m)).is_true()
	assert_bool(s.remove(m)).is_false()
	assert_float(s.value).is_equal(10.0)


func test_object_sources_and_freed_sources() -> void:
	var s := TrStat.new(10.0)
	var item := Node.new()
	var other := RefCounted.new()
	s.add(TrModifier.flat(5.0, item))
	s.add(TrModifier.flat(1.0, other))
	assert_float(s.value).is_equal(16.0)
	item.free()
	assert_float(s.value).is_equal(11.0)
	assert_int(s.modifiers().size()).is_equal(1)
	assert_int(s.remove_from(other)).is_equal(1)
	assert_float(s.value).is_equal(10.0)


func test_changed_only_when_value_changes() -> void:
	var s := TrStat.new(10.0)
	var events: Array[String] = []
	s.changed.connect(func(old: float, new: float) -> void: events.append("%s>%s" % [TrModifier.format_number(old), TrModifier.format_number(new)]))
	s.add(TrModifier.flat(5.0))
	s.add(TrModifier.flat(0.0))
	s.add(TrModifier.multiply(1.0))
	s.base = 10.0
	s.add(TrModifier.percent(1.0))
	assert_array(events).contains_exactly(["10>15", "15>30"])


func test_value_is_read_only() -> void:
	var s := TrStat.new(3.0)
	await assert_error(func() -> void: s.value = 9.0).is_push_error("TrStat.value is read-only; change base or add a modifier")
	assert_float(s.value).is_equal(3.0)


func test_modifier_is_from_and_text() -> void:
	var node := RefCounted.new()
	var by_object := TrModifier.flat(2.0, node)
	var by_name := TrModifier.percent(0.25, &"buff")
	assert_bool(by_object.is_from(node)).is_true()
	assert_bool(by_object.is_from(&"buff")).is_false()
	assert_bool(by_name.is_from("buff")).is_true()
	assert_bool(TrModifier.flat(1.0).is_from(null)).is_false()
	assert_str(str(by_object)).is_equal("+2")
	assert_str(str(by_name)).is_equal("+25%")
	assert_str(str(TrModifier.multiply(1.5))).is_equal("x1.5")


func test_format_number() -> void:
	assert_str(TrModifier.format_number(15.0)).is_equal("15")
	assert_str(TrModifier.format_number(1.5)).is_equal("1.5")
	assert_str(TrModifier.format_number(-3.0)).is_equal("-3")
	assert_str(str(TrStat.new(2.5))).is_equal("TrStat(2.5, base 2.5, 0 modifiers)")


func test_clear_modifiers() -> void:
	var s := TrStat.new(1.0)
	s.add(TrModifier.flat(1.0, RefCounted.new()))
	s.clear_modifiers()
	assert_float(s.value).is_equal(1.0)
