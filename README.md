# Truss

**Structured architecture for GDScript.** Ports checked by the engine, dependency injection from a composition root,
typed events, commands and queries through a mediator, feature modules, a strict typing profile and a layer linter,
all in pure GDScript for Godot 4.5+.

> Status: **design accepted, implementation not started** (milestone M0). Read the design in
> [RFC 0001](docs/rfcs/0001-truss-architecture.md). Nothing here is ready to install yet.

## Why

GDScript is great for prototyping. As projects grow, logic ends up trapped in nodes, autoloads become global state,
and string-based calls fail only at runtime. Truss brings the tools of Clean / hexagonal architecture to GDScript
without changing the language or fighting the editor:

| Piece | What it gives you |
|---|---|
| `core` | `TrResult` for expected errors, `TrContracts` helpers on top of native `@abstract` ports |
| `di` | `TrServiceContainer` with app/scene scopes, cycle detection, startup validation, automatic `_inject()` before `_ready` |
| `messaging` | Typed `TrEvent` bus, `TrMediator` for commands and queries with pipeline behaviors |
| `modules` | `TrModule` per feature, `TrBootstrap` composition root with dependency-ordered startup |
| `fsm` | Hierarchical node-based state machine |
| `tooling` | Strict typing profile, `arch_check.gd` layer-boundary linter for CI, generators, editor panel |

Every piece is optional. Nothing runs per frame unless you call it.

## Roadmap

| Milestone | Content |
|---|---|
| M0 ✅ | Design accepted (RFC 0001), name, license, repository |
| M1 | `core`, `di`, synchronous `messaging`, benchmarks |
| M2 | `modules`, `TrBootstrap`, injector, minimal example |
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

Cada pieza es opcional y nada se ejecuta en cada frame. El diseño está aprobado
([RFC 0001](docs/rfcs/0001-truss-architecture.md), en inglés), pero la implementación todavía no ha empezado.

## License

[MIT](LICENSE)
