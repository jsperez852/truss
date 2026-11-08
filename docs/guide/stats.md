# stats: TrStat, TrModifier, TrStats, TrModifierDef

Numbers made of a base and stacked modifiers: damage, speed, armor, cooldowns, prices. Items, buffs and
upgrades add modifiers tagged with their source, and removing the source removes them all.

```gdscript
var damage := TrStat.new(10.0)
damage.add(TrModifier.flat(5.0, sword))          # +5
damage.add(TrModifier.percent(0.2, &"buff"))     # +20 %
damage.add(TrModifier.multiply(1.5, rage))       # x1.5
damage.value                                     # (10 + 5) x 1.2 x 1.5 = 27.0
damage.remove_from(&"buff")                      # 22.5
damage.changed.connect(func(old: float, new: float) -> void: hud.show_damage(new))
```

## Formula

```
value = clamp((base + Σ flat) × (1 + Σ percent) × Π multiply, min_value, max_value)
```

- Percentages add together before being applied: two +10 % buffs give +20 %, not +21 %.
- Multipliers multiply: ×1.5 and ×2 give ×3.
- Within a kind the order doesn't matter, so modifiers have no priority.
- `min_value` / `max_value` default to `-INF` / `INF`.

## TrStat

| Member | Notes |
|---|---|
| `TrStat.new(base = 0.0, min = -INF, max = INF)` | |
| `base`, `min_value`, `max_value` | Setting them recomputes the value |
| `value` | Read-only and cached: recomputed only when something changes (reading costs about 0.2 µs) |
| `add(modifier) -> TrModifier`, `remove(modifier) -> bool`, `remove_from(source) -> int`, `clear_modifiers()`, `modifiers()` | |
| `changed(old_value, new_value)` | Emitted only when the value actually changes |
| `refresh()` | Drops modifiers whose source object was freed (reading `value` does it too) |

## TrModifier

`TrModifier.flat(amount, source)`, `percent(fraction, source)` (0.2 = +20 %), `multiply(factor, source)`.
The source is an `Object` (kept as a weak reference: freeing the item removes its modifiers) or a `StringName`
(`&"poison"`). `is_from(source)`, `is_alive()`, `source()`. `TrModifier.format_number(15.0)` gives `"15"`:
GDScript's `%` operator has no `%g`, and `String.num(15.0)` gives `"15.0"`.

## TrStats: declared keys

```gdscript
var stats := TrStats.new({&"speed": 220.0, &"damage": 10.0})
stats.declare(&"health", 100.0, 0.0, 100.0)       # with limits
stats.add(&"damage", TrModifier.percent(0.25, item))
stats.value(&"damage")                            # 12.5
stats.value(&"start_with_shield")                 # error: unknown stat start_with_shield (declared: damage, health, speed)
stats.remove_from(item)                           # from every stat
stats.changed.connect(_on_stat_changed)           # (stat, old, new)
stats.snapshot()                                  # {&"damage": 10.0, ...}
```

Declaring keys turns a typo or a forgotten key into an error with the list of valid names, instead of a silent 0.

## TrModifierDef: modifiers in the inspector

```gdscript
class_name ItemDef
extends Resource

@export var id: StringName
@export var modifiers: Array[TrModifierDef] = []   # each: stat, kind (FLAT/PERCENT/MULTIPLY), amount
```

```gdscript
TrModifierDef.apply_all(item.modifiers, player_stats, item)   # equip
player_stats.remove_from(item)                                # unequip
```

Combine with [TrRegistry](content.md): `items.by_id(&"iron_sword")` gives the shared definition. Its modifiers can
be applied directly, because the modifiers are created per application and the definition isn't changed.
