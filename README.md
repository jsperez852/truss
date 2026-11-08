# Truss

[![CI](https://github.com/jsperez852/truss/actions/workflows/ci.yml/badge.svg)](https://github.com/jsperez852/truss/actions/workflows/ci.yml)

**Structured architecture for GDScript.** Ports checked by the engine, dependency injection from a composition root,
typed events, commands and queries through a mediator, feature modules, a strict typing profile and a layer linter,
all in pure GDScript for Godot 4.5+.

> Status: **0.2.0-dev (milestone M2)**. `core`, `di`, `messaging`, `modules` and automatic injection are
> implemented and tested on Godot 4.5.1 and 4.7.2. `fsm` and the tooling come in later milestones, and the API may
> still change before 1.0. Design: [RFC 0001](docs/rfcs/0001-truss-architecture.md).

## Why

GDScript is great for prototyping. As projects grow, logic ends up trapped in nodes, autoloads become global state,
and string-based calls fail only at runtime. Truss brings the tools of Clean / hexagonal architecture to GDScript
without changing the language or fighting the editor.

| Piece | Status | What it gives you |
|---|---|---|
| `core` | ✅ M1 | `TrResult` for expected errors, `TrOption`, `TrContracts` on top of native `@abstract` ports |
| `di` | ✅ M1 | `TrServiceContainer`: singleton, scoped, transient and instance lifetimes, scopes, cycle detection, startup validation |
| `messaging` | ✅ M1 | Typed `TrEvent` bus; `TrMediator` for commands and queries with `TrBehavior` pipelines |
| `modules` | ✅ M2 | `TrModule` per feature, `TrBootstrap` composition root with dependency-ordered startup, `Truss` autoload with automatic `_inject()` before `_ready()` |
| `fsm` | M4 | Hierarchical node-based state machine |
| `tooling` | M3 | Strict typing profile, `arch_check.gd` layer linter for CI, generators, editor panel |

Every piece is optional. Nothing runs per frame unless you call it.

## Install

1. Copy `addons/truss/` into your project's `addons/` folder (from a release zip or this repository).
2. Enable **Truss** in Project → Project Settings → Plugins. That adds the `Truss` autoload and the
   `truss/injection/automatic` setting. The classes (`TrResult`, `TrServiceContainer`...) work without the plugin.
3. Add your composition root as an autoload **below** `Truss` and call `Truss.boot([...])` from its `_ready()`
   ([modules guide](docs/guide/modules.md)).
4. Requires Godot **4.5 or newer** (for `@abstract`).

## Quick look

```gdscript
@abstract class_name InventoryStore
extends RefCounted

@abstract func save_items(items: Dictionary[StringName, int]) -> Error
```

```gdscript
# Composition root (e.g. an autoload)
var c := TrServiceContainer.new()
c.singleton(InventoryStore, func() -> InventoryStore: return ConfigInventoryStore.new("user://inv.cfg"))
c.singleton(TrMediator, func(s: TrServiceContainer) -> TrMediator:
	var m := TrMediator.new()
	m.register(AddItemHandler.new(s.get_service(InventoryStore) as InventoryStore))
	return m)
var check: TrResult = c.validate()
assert(check.ok, check.message)

var mediator := c.get_service(TrMediator) as TrMediator
var result: TrResult = mediator.send(AddItemRequest.new(potion, 1))
if result.is_err():
	print(result.error, ": ", result.message)
```

## Documentation

- [core](docs/guide/core.md): `TrResult`, `TrOption`, `TrContracts`
- [di](docs/guide/di.md): `TrServiceContainer`, lifetimes, scopes, validation
- [messaging](docs/guide/messaging.md): `TrEventBus`, `TrMediator`, `TrBehavior`
- [modules](docs/guide/modules.md): `TrModule`, `TrBootstrap`, the `Truss` autoload and automatic injection
- [examples/minimal](examples/minimal): a feature through every layer, with failure modes
- [benchmarks](docs/benchmarks.md): cost compared to native signals and direct calls
- [RFC 0001](docs/rfcs/0001-truss-architecture.md): design, decisions and roadmap
- [CHANGELOG](CHANGELOG.md)

## Developing Truss

```bash
bash tools/install_gdunit.sh                                   # gdUnit4 v6.2.3 into addons/gdUnit4 (not committed)
godot --headless --path . --import
godot --headless --path . -s res://tools/compile_check.gd      # strict typing applies to addons/truss on 4.7+
GODOT_BIN="$(command -v godot)" addons/gdUnit4/runtest.sh -a res://tests -c --headless --ignoreHeadlessMode
godot --headless --path . -s res://tools/bench.gd
GODOT="$(command -v godot)" bash tools/run_example.sh             # example in every mode
```

## Roadmap

| Milestone | Content |
|---|---|
| M0 ✅ | Design accepted (RFC 0001), name, license, repository |
| M1 ✅ | `core`, `di`, synchronous `messaging`, benchmarks |
| M2 ✅ | `modules`, `TrBootstrap`, automatic injector, minimal example |
| M3 | Tooling: strict profile, `arch_check` v2, generators, Claude Code skill |
| M4 | `fsm`, editor panel, async handlers, example game |
| 1.0 | Frozen API, complete docs, Asset Library |

## Related

- [godot-market-place](https://github.com/jsperez852/godot-market-place): Claude Code plugins for Godot. Its
  `godot-architecture` plugin teaches the patterns Truss implements.
- [GF Framework](https://github.com/c76gn/gf-framework): a different take (layered toolkit with a global locator).
  The RFC compares both.

## Resumen en español

Truss es un framework de arquitectura para GDScript (Godot 4.5+), escrito en GDScript puro. Aporta:
- puertos `@abstract` que Godot verifica al cargar el script;
- inyección de dependencias desde una raíz de composición;
- eventos tipados, y comandos y consultas mediante un mediador con pipelines;
- módulos por feature con arranque ordenado;
- un perfil de tipado estricto y un linter de capas para CI.

Cada pieza es opcional y nada se ejecuta en cada frame. Ya están implementados y probados `core`, `di`,
`messaging`, los módulos con arranque ordenado y la inyección automática (hitos M1 y M2, en Godot 4.5.1 y 4.7.2).
`fsm` y las herramientas llegan en los siguientes hitos. La documentación está en inglés.

## License

[MIT](LICENSE)
