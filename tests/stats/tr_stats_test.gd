extends GdUnitTestSuite


func test_declared_stats_and_values() -> void:
	var stats := TrStats.new({&"damage": 10.0, "speed": 220.0})
	assert_array(stats.names()).contains_exactly_in_any_order([&"damage", &"speed"])
	assert_float(stats.value(&"speed")).is_equal(220.0)
	stats.add(&"damage", TrModifier.percent(0.25, &"item"))
	assert_float(stats.value(&"damage")).is_equal(12.5)
	stats.set_base(&"damage", 20.0)
	assert_float(stats.value(&"damage")).is_equal(25.0)
	assert_dict(stats.snapshot()).is_equal({&"damage": 25.0, &"speed": 220.0})


func test_undeclared_stat_is_an_error() -> void:
	var stats := TrStats.new({&"damage": 10.0, &"speed": 1.0})
	var out: Array[float] = []
	await assert_error(func() -> void: out.append(stats.value(&"start_with_shield"))) \
		.is_push_error("TrStats: unknown stat start_with_shield (declared: damage, speed)")
	assert_float(out[0]).is_equal(0.0)
	assert_bool(stats.has(&"start_with_shield")).is_false()


func test_declare_with_limits_and_redeclare() -> void:
	var stats := TrStats.new()
	stats.declare(&"health", 100.0, 0.0, 100.0)
	stats.add(&"health", TrModifier.flat(50.0))
	assert_float(stats.value(&"health")).is_equal(100.0)
	stats.declare(&"health", 100.0, 0.0, 500.0)
	assert_float(stats.value(&"health")).is_equal(150.0)


func test_remove_from_across_stats_and_changed_signal() -> void:
	var stats := TrStats.new({&"damage": 10.0, &"armor": 2.0})
	var seen: Array[String] = []
	stats.changed.connect(func(stat: StringName, _old: float, new: float) -> void: seen.append("%s=%s" % [stat, TrModifier.format_number(new)]))
	var ring := RefCounted.new()
	stats.add(&"damage", TrModifier.flat(1.0, ring))
	stats.add(&"armor", TrModifier.flat(3.0, ring))
	assert_int(stats.remove_from(ring)).is_equal(2)
	assert_array(seen).contains_exactly(["damage=11", "armor=5", "damage=10", "armor=2"])


func test_modifier_defs_from_an_inspector_authored_resource() -> void:
	var item := load("res://tests/fixtures/content_items/iron_sword.tres") as FxEquipmentDef
	var stats := TrStats.new({&"damage": 10.0, &"attack_speed": 1.0})
	assert_int(TrModifierDef.apply_all(item.modifiers, stats, item)).is_equal(2)
	assert_float(stats.value(&"damage")).is_equal(15.0)
	assert_float(stats.value(&"attack_speed")).is_equal_approx(1.1, 0.0001)
	assert_int(stats.remove_from(item)).is_equal(2)
	assert_float(stats.value(&"damage")).is_equal(10.0)


func test_modifier_def_for_undeclared_stat() -> void:
	var def := TrModifierDef.new()
	def.stat = &"luck"
	def.amount = 1.0
	var stats := TrStats.new({&"damage": 1.0})
	var out: Array[Variant] = []
	await assert_error(func() -> void: out.append(def.apply_to(stats))).is_push_error("TrStats: unknown stat luck (declared: damage)")
	assert_that(out[0]).is_null()
