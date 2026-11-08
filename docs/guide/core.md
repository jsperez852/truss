# core: TrResult, TrOption, TrContracts

## TrResult

The outcome of an operation that can fail in an **expected** way. Programming errors still use `push_error` and `assert`.

```gdscript
func buy(item: ItemDef) -> TrResult:
	if gold < item.price:
		return TrResult.failure(&"not_enough_gold", "needs %d" % item.price)
	gold -= item.price
	return TrResult.success(item)

var r: TrResult = shop.buy(sword)
if r.is_err():
	ui.show_error(r.error)   # &"not_enough_gold"
	return
var bought := r.value as ItemDef
```

| Member | Meaning |
|---|---|
| `TrResult.success(value = null)`, `TrResult.failure(code, message = "")` | Constructors. `code` is a non-empty `StringName` |
| `ok`, `value`, `error`, `message` | Plain fields, visible in the debugger |
| `is_ok()`, `is_err()` | Predicates |
| `unwrap()` | The value; on a failure it reports an error and returns `null` |
| `unwrap_or(default)` | The value or `default` |
| `map(fn)` | Transforms a success's value; failures pass through |
| `and_then(fn)` | Chains another step that returns a `TrResult` |

There are no generics in GDScript, so `value` is a `Variant`: cast it at the edge (`r.value as ItemDef`).

## TrOption

An explicit "maybe missing" value, for APIs where `null` is a valid value or where absence is normal.

```gdscript
func find_quest(id: StringName) -> TrOption:
	return TrOption.some(_quests[id]) if _quests.has(id) else TrOption.none()

var quest := find_quest(&"dragon").unwrap_or(null) as Quest
var r: TrResult = find_quest(&"dragon").ok_or(&"quest_missing")
```

## TrContracts

Ports are `@abstract` classes: Godot refuses to load an implementation that misses an abstract method, and
`Port.new()` is a parse error. `TrContracts` checks the other side, that an object you received is an
implementation of the port.

```gdscript
@abstract class_name SaveGateway
extends RefCounted

@abstract func write(slot: int, data: Dictionary) -> Error

# elsewhere
TrContracts.implements(gateway, SaveGateway)            # bool, never errors
TrContracts.require(gateway, SaveGateway, "SaveMenu")   # reports "SaveMenu: X does not implement SaveGateway"
TrContracts.describe(SaveGateway)                       # "SaveGateway" (class_name or path)
TrContracts.describe_value(obj)                         # "JsonSaveGateway", "int", "null", "<freed object>"
```

`implements()` is safe with freed objects. In GDScript, using `is` on a freed instance is a runtime error, so
check validity first in your own code too.
