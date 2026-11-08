class_name TrWallet
extends RefCounted
## Balances of one or more currencies. Spending checks and subtracts in one step and returns a [TrResult], so
## "can I afford it?" and "pay" can't drift apart, and a multi-currency price is paid all or nothing.
## [codeblock]
## var wallet := TrWallet.new({&"coins": 100.0})
## wallet.changed.connect(_on_balance_changed)
##
## wallet.earn(4.0)                                          # default currency: &"coins"
## var paid: TrResult = wallet.try_spend(3.0)
## if paid.is_err():
##     show_message(paid.message)                            # "not enough coins: needs 3, has 1"
## wallet.try_spend_all({&"coins": 50.0, &"gems": 2.0})      # both or neither
## var saved: Dictionary = wallet.snapshot()                 # for TrSave
## [/codeblock]

## Emitted after a balance changes (not when an operation fails or adds 0).
signal changed(currency: StringName, old_balance: float, new_balance: float)

const DEFAULT_CURRENCY: StringName = &"coins"
const ERR_INSUFFICIENT: StringName = &"insufficient_funds"
const ERR_INVALID_AMOUNT: StringName = &"invalid_amount"

var _balances: Dictionary[StringName, float] = {}


## [param starting]: currency → balance, for example [code]{&"coins": 100.0}[/code].
func _init(starting: Dictionary = {}) -> void:
	restore(starting)


func balance(currency: StringName = DEFAULT_CURRENCY) -> float:
	return _balances.get(currency, 0.0)


## Currencies that have (or had) a balance.
func currencies() -> Array[StringName]:
	var out: Array[StringName] = []
	out.assign(_balances.keys())
	return out


func can_afford(amount: float, currency: StringName = DEFAULT_CURRENCY) -> bool:
	return amount >= 0.0 and balance(currency) >= amount


## [code]true[/code] when every currency in [param price] (currency → amount) is covered.
func can_afford_all(price: Dictionary) -> bool:
	for currency: Variant in price:
		var amount: float = _amount_of(price[currency])
		if not can_afford(amount, StringName(str(currency))):
			return false
	return true


## Adds [param amount] (>= 0). Returns the new balance. Negative or non-finite amounts are errors and change
## nothing.
func earn(amount: float, currency: StringName = DEFAULT_CURRENCY) -> float:
	if amount < 0.0 or not is_finite(amount):
		push_error("TrWallet.earn(): amount must be a finite number >= 0, got %s" % _fmt(amount))
		return balance(currency)
	_put(currency, balance(currency) + amount)
	return balance(currency)


## Subtracts [param amount] when the balance covers it. Success holds the new balance; failures are
## [constant ERR_INSUFFICIENT] and [constant ERR_INVALID_AMOUNT], and leave the balance unchanged.
func try_spend(amount: float, currency: StringName = DEFAULT_CURRENCY) -> TrResult:
	if amount < 0.0 or not is_finite(amount):
		return TrResult.failure(ERR_INVALID_AMOUNT, "amount must be a finite number >= 0, got %s" % _fmt(amount))
	var current: float = balance(currency)
	if current < amount:
		return TrResult.failure(ERR_INSUFFICIENT, "not enough %s: needs %s, has %s" % [currency, _fmt(amount), _fmt(current)])
	_put(currency, current - amount)
	return TrResult.success(current - amount)


## Pays every currency in [param price] or none of them. Success holds the remaining balances (currency → balance).
func try_spend_all(price: Dictionary) -> TrResult:
	var missing := PackedStringArray()
	for currency: Variant in price:
		var amount: float = _amount_of(price[currency])
		if amount < 0.0 or not is_finite(amount):
			return TrResult.failure(ERR_INVALID_AMOUNT, "amount of %s must be a finite number >= 0" % str(currency))
		var have: float = balance(StringName(str(currency)))
		if have < amount:
			missing.append("%s: needs %s, has %s" % [str(currency), _fmt(amount), _fmt(have)])
	if not missing.is_empty():
		return TrResult.failure(ERR_INSUFFICIENT, "not enough " + "; ".join(missing))
	var remaining: Dictionary = {}
	for currency: Variant in price:
		var key := StringName(str(currency))
		_put(key, balance(key) - _amount_of(price[currency]))
		remaining[key] = balance(key)
	return TrResult.success(remaining)


## Sets a balance directly (cheats, loading, tests). Negative values are clamped to 0.
func set_balance(amount: float, currency: StringName = DEFAULT_CURRENCY) -> void:
	_put(currency, maxf(amount, 0.0))


## Balances as a plain Dictionary (String keys), ready for [TrSave].
func snapshot() -> Dictionary:
	var out: Dictionary = {}
	for currency: StringName in _balances:
		out[String(currency)] = _balances[currency]
	return out


## Replaces every balance with [param balances] (as returned by [method snapshot]). Emits [signal changed] for
## the currencies whose balance changed.
func restore(balances: Dictionary) -> void:
	var incoming: Dictionary[StringName, float] = {}
	for currency: Variant in balances:
		incoming[StringName(str(currency))] = maxf(_amount_of(balances[currency]), 0.0)
	for currency: StringName in _balances.keys():
		if not incoming.has(currency):
			_put(currency, 0.0)
	for currency: StringName in incoming:
		_put(currency, incoming[currency])


func _put(currency: StringName, value: float) -> void:
	var old: float = _balances.get(currency, 0.0)
	_balances[currency] = value
	if value != old:
		changed.emit(currency, old, value)


static func _amount_of(value: Variant) -> float:
	if typeof(value) == TYPE_FLOAT or typeof(value) == TYPE_INT:
		var number: float = value
		return number
	return NAN


static func _fmt(value: float) -> String:
	return TrModifier.format_number(value)
