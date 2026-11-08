# tooling: strict profile, generators and arch_check

Three headless tool scripts in `addons/truss/tooling/`. They run from the command line (and in CI) with the
project's Godot binary; none of them needs the editor or the plugin enabled.

## Strict typing profile

```bash
godot --headless --path . -s res://addons/truss/tooling/strict_profile.gd                # dry run: lists changes
godot --headless --path . -s res://addons/truss/tooling/strict_profile.gd -- --apply     # writes project.godot
godot --headless --path . -s res://addons/truss/tooling/strict_profile.gd -- --apply --level=warn
```

| Warning (`debug/gdscript/warnings/`) | `--level=error` (default) | `--level=warn` |
|---|---|---|
| `untyped_declaration` | 2 (error) | 1 |
| `unsafe_property_access` | 2 | 1 |
| `unsafe_method_access` | 2 | 1 |
| `unsafe_call_argument` | 2 | 1 |
| `unsafe_cast` | 1 (warn) | 1 |
| `return_value_discarded`, `inferred_declaration` | 0 | 0 |

The dry run exits with 1 when changes are pending, so it can guard CI ("the profile must be applied").
On an existing project, start with `--level=warn`: errors can stop hundreds of scripts from loading.

`--include-addons` also checks scripts under `res://addons`. Godot 4.7 uses `directory_rules` (path → 0 exclude,
1 include), and Godot 4.5 uses `exclude_addons`, which ignores `directory_rules`. Both behaviors were verified
on 4.7.2 and 4.5.1. The tool uses `directory_rules` from 4.7 on and `exclude_addons` before that; 4.6 is untested.

Strict typing finds real problems in GDScript that runs fine in a loose project. Truss's own code runs under this
profile, and it caught conversions such as `String(dictionary["key"])` (an unsafe call argument; assign to a typed
variable instead) and typed-array arguments built from untyped values.

## Generators

```bash
godot --headless --path . -s res://addons/truss/tooling/generate.gd -- module inventory
godot --headless --path . -s res://addons/truss/tooling/generate.gd -- usecase inventory AddItem
godot --headless --path . -s res://addons/truss/tooling/generate.gd -- port inventory InventoryStore
godot --headless --path . -s res://addons/truss/tooling/generate.gd -- event inventory ItemAdded item_id:StringName amount:int
```

| Command | Creates (under `res://features/<feature>/`) |
|---|---|
| `module <feature>` | `<feature>_module.gd` (`<Feature>Module extends TrModule`) and empty `domain/`, `application/`, `infrastructure/`, `presentation/` folders |
| `usecase <feature> <Name>` | `application/<name>_request.gd` (`<Name>Request extends TrRequest`) and `application/<name>_handler.gd` (`<Name>Handler extends TrRequestHandler`, returns `not_implemented`) |
| `port <feature> <Name>` | `application/ports/<name>.gd` (`@abstract class_name <Name>`) and `infrastructure/memory_<name>.gd` (`Memory<Name>`) |
| `event <feature> <Name> [field:Type ...]` | `application/events/<name>.gd` (`<Name> extends TrEvent`, with typed fields and an `_init` that sets them) |

Each command prints the line to add to the module. Generators never overwrite: if any target file exists,
nothing is written and the exit code is 1. `--root=res://game/features` changes the base folder, `--dry-run`
only prints paths. The generated code compiles under the strict profile.

## arch_check

```bash
godot --headless --path . -s res://addons/truss/tooling/arch_check.gd -- --write-default-config   # once
godot --headless --path . --import                                                                 # on a fresh checkout
godot --headless --path . -s res://addons/truss/tooling/arch_check.gd
godot --headless --path . -s res://addons/truss/tooling/arch_check.gd -- --junit=res://reports/arch.xml
```

Exit codes: 0 no violations, 1 violations, 2 configuration error. The default `res://architecture.cfg` matches the
generators' layout:

| Section | Default |
|---|---|
| `[layers]` | `domain`, `application`, `infrastructure`, `presentation` under `res://features/*/`; `composition` = `res://app/*` and `*_module.gd` files |
| `[allow]` | domain → nothing; application → domain; infrastructure and presentation → application, domain; composition → anything |
| `[rules]` | domain and application may not extend `Node` or touch the scene tree, autoloads or scenes |
| `[features]` | `root="res://features/"`; other features may only use a feature's `domain` and `application` |
| `[rules] stateful_resources` | Off by default. Layers listed here may not contain `Resource` scripts with fields that are neither `@export` nor `@export_storage` (runtime state on a shared definition). Only fields declared in the script itself are reported; `static` and `const` are ignored |
| `[forbid]` | domain may not reference `TrServiceContainer`, `TrInjector`, `TrBootstrap`, `TrMediator`; application may not reference `TrInjector`, `TrBootstrap` |

Example output:

```
VIOLATION res://features/inventory/domain/stock.gd [domain] depends on MemoryInventoryStore, res://features/inventory/infrastructure/memory_inventory_store.gd (layer infrastructure)
VIOLATION res://features/inventory/domain/stock.gd [domain] uses TrServiceContainer, which is forbidden in this layer
VIOLATION res://features/shop/infrastructure/shop_store.gd [infrastructure] reaches into feature inventory's infrastructure (MemoryInventoryStore, ...); only domain, application are public to other features
arch_check: 9 files, 3 violations
```

It detects references by `class_name` (outside comments and strings), `res://...gd` paths in strings, autoload
names, `get_tree()`, `get_node()`, `$Node` and `"/root/"`, and Node base classes. It doesn't see dynamic access
(`load(variable)`, `call("method")`, `Engine.get_main_loop()`); review those by hand.

## In CI

```yaml
      - name: Architecture
        run: godot --headless --path . -s res://addons/truss/tooling/arch_check.gd -- --junit=res://reports/arch.xml
      - name: Strict profile applied
        run: godot --headless --path . -s res://addons/truss/tooling/strict_profile.gd
```

`tools/test_tooling.sh` in this repository runs all three tools end to end in a throwaway project.
