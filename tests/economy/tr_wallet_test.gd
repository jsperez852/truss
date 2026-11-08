extends GdUnitTestSuite

var wallet: TrWallet
var changes: Array


func before_test() -> void:
	wallet = TrWallet.new({&"coins": 10.0})
	changes = []
	wallet.changed.connect(func(c: StringName, a: float, b: float) -> void: changes.append([c, a, b]))


func test_earn_and_spend() -> void:
	assert_float(wallet.earn(5.0)).is_equal(15.0)
	var paid: TrResult = wallet.try_spend(12.0)
	assert_bool(paid.is_ok()).is_true()
	assert_float(paid.value).is_equal(3.0)
	assert_array(changes).contains_exactly([[&"coins", 10.0, 15.0], [&"coins", 15.0, 3.0]])


func test_insufficient_funds_changes_nothing() -> void:
	var paid: TrResult = wallet.try_spend(11.0)
	assert_str(String(paid.error)).is_equal("insufficient_funds")
	assert_str(paid.message).is_equal("not enough coins: needs 11, has 10")
	assert_float(wallet.balance()).is_equal(10.0)
	assert_array(changes).is_empty()


func test_invalid_amounts() -> void:
	assert_str(String(wallet.try_spend(-1.0).error)).is_equal("invalid_amount")
	assert_str(String(wallet.try_spend(NAN).error)).is_equal("invalid_amount")
	assert_bool(wallet.can_afford(-1.0)).is_false()
	await assert_error(func() -> void: wallet.earn(-3.0)).is_push_error("TrWallet.earn(): amount must be a finite number >= 0, got -3")
	assert_float(wallet.balance()).is_equal(10.0)


func test_multi_currency_is_all_or_nothing() -> void:
	wallet.earn(2.0, &"gems")
	var too_much: TrResult = wallet.try_spend_all({&"coins": 5.0, &"gems": 3.0})
	assert_str(String(too_much.error)).is_equal("insufficient_funds")
	assert_str(too_much.message).is_equal("not enough gems: needs 3, has 2")
	assert_float(wallet.balance()).is_equal(10.0)
	assert_bool(wallet.can_afford_all({&"coins": 5.0, &"gems": 2.0})).is_true()
	var paid: TrResult = wallet.try_spend_all({&"coins": 5.0, &"gems": 2.0})
	assert_bool(paid.is_ok()).is_true()
	assert_dict(paid.value).is_equal({&"coins": 5.0, &"gems": 0.0})


func test_unknown_currency_is_zero() -> void:
	assert_float(wallet.balance(&"stars")).is_equal(0.0)
	assert_bool(wallet.can_afford(1.0, &"stars")).is_false()


func test_snapshot_and_restore() -> void:
	wallet.earn(1.5, &"gems")
	var saved: Dictionary = wallet.snapshot()
	assert_dict(saved).is_equal({"coins": 10.0, "gems": 1.5})
	var other := TrWallet.new()
	other.restore(saved)
	assert_float(other.balance(&"gems")).is_equal(1.5)
	wallet.restore({"coins": 4})
	assert_float(wallet.balance()).is_equal(4.0)
	assert_float(wallet.balance(&"gems")).is_equal(0.0)
