extends GdUnitTestSuite

const PATH: String = "user://truss_save_test.dat"


func before_test() -> void:
	TrSave.new(PATH).erase()


func after_test() -> void:
	TrSave.new(PATH).erase()


func test_write_then_read() -> void:
	var save := TrSave.new(PATH)
	assert_bool(save.exists()).is_false()
	assert_str(String(save.read().error)).is_equal("not_found")
	var written: TrResult = save.write({"coins": 12.5, "spawn": Vector2(3, 4), "names": ["a", "b"]})
	assert_bool(written.is_ok()).is_true()
	var loaded: TrResult = save.read()
	assert_bool(loaded.is_ok()).is_true()
	assert_dict(loaded.value).is_equal({"coins": 12.5, "spawn": Vector2(3, 4), "names": ["a", "b"]})
	assert_bool(FileAccess.file_exists(PATH + ".tmp")).is_false()


func test_second_write_keeps_a_backup_and_corrupt_main_falls_back() -> void:
	var save := TrSave.new(PATH)
	save.write({"best": 1})
	save.write({"best": 2})
	assert_bool(FileAccess.file_exists(PATH + ".bak")).is_true()
	var damaged := FileAccess.open(PATH, FileAccess.WRITE)
	damaged.store_string("garbage")
	damaged.close()
	var loaded: TrResult = save.read()
	assert_bool(loaded.is_ok()).is_true()
	assert_dict(loaded.value).is_equal({"best": 1})


func test_read_or_fills_defaults() -> void:
	var save := TrSave.new(PATH)
	assert_dict(save.read_or({"best": 0, "volume": 0.8})).is_equal({"best": 0, "volume": 0.8})
	save.write({"best": 7})
	assert_dict(save.read_or({"best": 0, "volume": 0.8})).is_equal({"best": 7, "volume": 0.8})


func test_migrations_run_in_order() -> void:
	TrSave.new(PATH, 1).write({"gold": 5})
	var save := TrSave.new(PATH, 3)
	save.add_migration(1, func(data: Dictionary) -> Dictionary:
		data["coins"] = data["gold"]
		data.erase("gold")
		return data)
	save.add_migration(2, func(data: Dictionary) -> Dictionary:
		data["gems"] = 0
		return data)
	var loaded: TrResult = save.read()
	assert_bool(loaded.is_ok()).is_true()
	assert_dict(loaded.value).is_equal({"coins": 5, "gems": 0})


func test_missing_migration_and_newer_version() -> void:
	TrSave.new(PATH, 1).write({"a": 1})
	var missing: TrResult = TrSave.new(PATH, 2).read()
	assert_str(String(missing.error)).is_equal("migration_failed")
	TrSave.new(PATH, 5).write({"a": 1})
	var newer: TrResult = TrSave.new(PATH, 2).read()
	assert_str(String(newer.error)).is_equal("newer_version")


func test_not_a_truss_save() -> void:
	var file := FileAccess.open(PATH, FileAccess.WRITE)
	file.store_var({"something": "else"})
	file.close()
	assert_str(String(TrSave.new(PATH).read().error)).is_equal("corrupt")


func test_encrypted_save() -> void:
	var save := TrSave.new(PATH, 1, "secret")
	save.write({"coins": 3})
	assert_dict(save.read().value).is_equal({"coins": 3})
	assert_bool(TrSave.new(PATH, 1, "wrong").read().is_err()).is_true()
	assert_bool(TrSave.new(PATH).read().is_err()).is_true()
