# economy: TrWallet and TrCurve

Two pieces that idle, tycoon and roguelite games end up writing by hand: a balance you can spend safely, and
a number that grows with a level.

## TrWallet

```gdscript
var wallet := TrWallet.new({&"coins": 100.0})
wallet.changed.connect(func(currency: StringName, _old: float, new: float) -> void: hud.show(currency, new))

wallet.earn(4.0)                                    # default currency: &"coins"
var paid: TrResult = wallet.try_spend(cost)
if paid.is_err():
	toast(paid.message)                             # "not enough coins: needs 30, has 12"

wallet.try_spend_all({&"coins": 50.0, &"gems": 2.0})   # both or neither
```

| Member | Notes |
|---|---|
| `TrWallet.new(starting = {})` | Currency → balance |
| `balance(currency = &"coins") -> float` | 0 for a currency never used |
| `can_afford(amount, currency)`, `can_afford_all(price)` | `price` is currency → amount |
| `earn(amount, currency) -> float` | Negative or non-finite amounts are errors and change nothing |
| `try_spend(amount, currency) -> TrResult` | Success holds the new balance. Errors: `insufficient_funds`, `invalid_amount` |
| `try_spend_all(price) -> TrResult` | All or nothing; success holds the remaining balances |
| `set_balance(amount, currency)` | Cheats, tests; clamps to 0 |
| `snapshot() -> Dictionary`, `restore(balances)` | Plain data for [save](save.md) |
| signal `changed(currency, old_balance, new_balance)` | Only on real changes |

Spending is one call, so "check, then subtract" can't be split across two places that drift apart. Connect
`changed` to the HUD instead of polling the balance every frame.

## TrCurve

A Resource, so a designer can tune it in the inspector and every upgrade can have its own.

```gdscript
# The price of an idle-game upgrade: ×1.3 per level, rounded up at every level, ×3 every 25 levels.
var cost := TrCurve.exponential(3.0, 1.3)
cost.rounding = TrCurve.Rounding.CEIL
cost.round_each_level = true
cost.milestone_every = 25
cost.milestone_multiplier = 3.0

cost.value_at(level)                 # price of the next level
cost.total(level, 10)                # price of 10 levels at once
cost.max_affordable(level, wallet.balance())   # "buy max"
```

| Property | Notes |
|---|---|
| `growth` | `EXPONENTIAL` (`base · rate^level`), `LINEAR` (`base + rate · level`) or `TABLE` (one value per level; past the end, the last one) |
| `base`, `rate` | Value at level 0, and the multiplier (exponential) or step (linear) |
| `rounding` | `NONE`, `FLOOR`, `CEIL`, `ROUND` |
| `round_each_level` | Off: round the final value once. On: each level grows from the previous **rounded** value, like a hand-written `cost = ceil(cost * 1.3)` loop |
| `milestone_every`, `milestone_multiplier` | Every N levels, multiply (×3 every 25) |
| `min_value`, `max_value` | Clamp |

`round_each_level` exists because the two forms give different numbers: `ceil(3 · 1.3^10)` is 42, while rounding up
at every level gives 59 at level 10. When you replace a hand-written formula, pick the form that matches it;
Truss's tests compare a `TrCurve` with such a loop for 75 levels.

`TrStat` vs `TrCurve`: a `TrStat` is "base plus modifiers right now" (damage with a sword and a buff); a `TrCurve`
is "the value at level N" (the price of the next upgrade). They combine: `stat.set_base(curve.value_at(level))`.
