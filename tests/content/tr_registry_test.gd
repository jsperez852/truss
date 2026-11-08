extends GdUnitTestSuite

const ROOT: String = "res://tests/fixtures/content"


func _ids(items: Array[Resource]) -> Array[String]:
	var out: Array[String] = []
	for item: Resource in items:
		out.append(String((item as FxItemDef).id))
	out.sort()
	return out


func test_scan_collects_type_and_subclasses_recursively() -> void:
	var reg := TrRegistry.new(FxItemDef)
	var r: TrResult = reg.scan(ROOT)
	assert_bool(r.ok).is_true()
	assert_int(r.value).is_equal(4)
	assert_array(_ids(reg.all())).contains_exactly(["", "elixir", "potion", "sword"])
	assert_array(reg.skipped()).contains_exactly([ROOT + "/misc/note.tres"])


func test_id_falls_back_to_file_name() -> void:
	var reg := TrRegistry.new(FxItemDef)
	reg.scan(ROOT)
	assert_object(reg.by_id(&"no_id_axe")).is_instanceof(FxWeaponDef)
	assert_bool(reg.has(&"potion")).is_true()
	assert_object(reg.by_id(&"missing")).is_null()


func test_non_recursive_scan() -> void:
	var reg := TrRegistry.new(FxItemDef)
	reg.scan(ROOT, false)
	assert_array(_ids(reg.all())).contains_exactly(["elixir", "potion"])


func test_scan_subclass_only() -> void:
	var reg := TrRegistry.new(FxWeaponDef)
	reg.scan(ROOT)
	assert_int(reg.size()).is_equal(2)


func test_where() -> void:
	var reg := TrRegistry.new(FxItemDef)
	reg.scan(ROOT)
	var rare: Array[Resource] = reg.where(func(i: FxItemDef) -> bool: return i.rare)
	assert_array(_ids(rare)).contains_exactly(["elixir"])


func test_duplicate_ids_fail_but_keep_the_first() -> void:
	var reg := TrRegistry.new(FxItemDef)
	var r: TrResult = reg.scan("res://tests/fixtures/content_dupes")
	assert_str(String(r.error)).is_equal(String(TrRegistry.ERR_SCAN))
	assert_str(r.message).contains("duplicate id same")
	assert_int(reg.size()).is_equal(1)


func test_missing_folder() -> void:
	var r: TrResult = TrRegistry.new(FxItemDef).scan("res://tests/fixtures/nope")
	assert_str(String(r.error)).is_equal(String(TrRegistry.ERR_NOT_A_FOLDER))


func test_pick_weighted_respects_weights_and_skips_zero() -> void:
	var reg := TrRegistry.new(FxItemDef)
	reg.scan(ROOT)
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	var counts: Dictionary[String, int] = {}
	for i: int in 4000:
		var picked := reg.pick_weighted(rng, func(it: FxItemDef) -> float: return it.weight) as FxItemDef
		var key: String = String(picked.id) if picked.id != &"" else "axe"
		counts[key] = counts.get(key, 0) + 1
	assert_bool(counts.has("sword")).is_false()
	# weights: potion 3, elixir 1, axe 1 (default) -> potion about 60 %
	assert_float(float(counts["potion"]) / 4000.0).is_between(0.55, 0.65)
	assert_float(float(counts["elixir"]) / 4000.0).is_between(0.16, 0.24)


func test_pick_weighted_among_candidates_and_empty() -> void:
	var reg := TrRegistry.new(FxItemDef)
	reg.scan(ROOT)
	var rng := RandomNumberGenerator.new()
	var rare: Array[Resource] = reg.where(func(i: FxItemDef) -> bool: return i.rare)
	var picked := reg.pick_weighted(rng, func(it: FxItemDef) -> float: return it.weight, rare) as FxItemDef
	assert_str(String(picked.id)).is_equal("elixir")
	assert_object(reg.pick_weighted(rng, func(_it: FxItemDef) -> float: return 0.0)).is_null()


func test_instantiate_returns_independent_copy() -> void:
	var reg := TrRegistry.new(FxItemDef)
	reg.scan(ROOT)
	var copy := reg.instantiate(&"potion") as FxItemDef
	copy.uses = 5
	copy.weight = 99.0
	var shared := reg.by_id(&"potion") as FxItemDef
	assert_int(shared.uses).is_equal(0)
	assert_float(shared.weight).is_equal(3.0)
	assert_object(copy).is_not_same(shared)


func test_instantiate_unknown_id() -> void:
	var reg := TrRegistry.new(FxItemDef)
	await assert_error(func() -> void: reg.instantiate(&"nope")).is_push_error("TrRegistry(FxItemDef): no resource with id nope")


func test_add_in_code_and_type_check() -> void:
	var reg := TrRegistry.new(FxWeaponDef)
	var w := FxWeaponDef.new()
	w.id = &"bow"
	assert_bool(reg.add(w).ok).is_true()
	assert_bool(reg.add(FxItemDef.new(), &"x").ok).is_false()
	assert_array(reg.ids()).contains_exactly([&"bow"])
	reg.clear()
	assert_int(reg.size()).is_equal(0)


func test_native_class_types() -> void:
	var all_resources := TrRegistry.new(Resource)
	all_resources.scan(ROOT)
	assert_int(all_resources.size()).is_equal(5)
	assert_array(all_resources.skipped()).is_empty()
	var curves := TrRegistry.new(Curve)
	var curve := Curve.new()
	assert_bool(curves.add(curve, &"ease").ok).is_true()
	assert_bool(curves.add(Gradient.new(), &"grad").ok).is_false()
	var by_name := TrRegistry.new(&"Curve")
	assert_bool(by_name.add(Curve.new(), &"ease").ok).is_true()
	assert_object(curves.instantiate(&"ease")).is_instanceof(Curve)


func test_non_resource_types_are_reported() -> void:
	await assert_error(func() -> void: TrRegistry.new(&"Node")).is_push_error("TrRegistry.new(): Node is not a Resource script or class")
