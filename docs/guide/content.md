# content: TrRegistry

A content database: loads every Resource of one type from a folder (attacks, items, enemies, cards, upgrades)
and gives typed lookups, filters, weighted random picks and private copies.

```gdscript
var attacks := TrRegistry.new(BaseAttack)            # subclasses of BaseAttack are included
var scan: TrResult = attacks.scan("res://data/attacks")   # recursive by default
if scan.is_err():
	push_error(scan.message)                          # load failures, duplicate ids (valid items are kept)

var slash := attacks.by_id(&"slash") as BaseAttack
var basics: Array[Resource] = attacks.where(func(a: BaseAttack) -> bool: return a.is_basic_attack)
var drop := attacks.pick_weighted(rng, func(a: BaseAttack) -> float: return a.drop_weight) as BaseAttack
var mine := attacks.instantiate(&"slash") as BaseAttack   # duplicate_deep(): safe to modify
```

Register one registry per content type as a singleton, so the rest of the game receives it through `_inject`:

```gdscript
c.singleton(AttackRegistry, func() -> TrRegistry:
	var reg := TrRegistry.new(BaseAttack)
	reg.scan("res://data/attacks")
	return reg)
```

(`AttackRegistry` is any script you use as the key, for example `class_name AttackRegistry extends TrRegistry`
with `_init()` calling `super(BaseAttack)`.)

## Why not DirAccess

In an exported game, Godot converts and remaps resources, and `DirAccess.get_files_at("res://data")` returns
`potion.tres.remap` instead of `potion.tres`. Code that filters with `ends_with(".tres")` finds nothing after export,
even though it works in the editor. `TrRegistry` uses `ResourceLoader.list_directory()` (Godot 4.4+), which lists the
original names in both cases. `tools/test_export.sh` exports a project with `--export-pack` and checks both, on
Godot 4.5.1 and 4.7.2:

```
editor:   naive_dir_access=2 registry_ok=true registry=3 ids=elixir,potion,sword
exported: naive_dir_access=0 registry_ok=true registry=3 ids=elixir,potion,sword
```

## Reference

| Method | Notes |
|---|---|
| `TrRegistry.new(type, id_property = &"id")` (`type`: a Resource script, a native class such as `Curve`, or its name `&"Curve"`) | The id is the `id_property` value when the resource has it, otherwise the file name without extension |
| `scan(folder, recursive = true) -> TrResult` | Success holds how many were added. Resources of other types are skipped (`skipped()` lists them). Load failures, missing ids and duplicate ids make it a failure; the valid ones are still added. A missing folder is `not_a_folder` |
| `add(resource, id = &"") -> TrResult` | For content built in code or in tests |
| `all()`, `by_id(id)`, `has(id)`, `ids()`, `size()`, `where(predicate)` | Return the **shared** definitions: treat them as read-only |
| `pick_weighted(rng, weight, candidates = [])` | Weights ≤ 0 are never picked; `null` when nothing can be picked. Pass the RNG for deterministic tests |
| `instantiate(id)` | `Resource.duplicate_deep()` of the definition, for runtime state (uses, cooldowns, upgrades) |
| `clear()` | Empties the registry |

## Shared definitions vs instances

A Resource loaded from disk is shared by everything that loads it. Storing runtime state on it (current uses, a
cooldown, an upgrade level) changes it for every user, which is why projects end up writing their own
`duplicate_instance()` methods. Keep definitions read-only and call `instantiate()` for anything that changes.
