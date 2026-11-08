# Changelog

All notable changes to Truss are documented here. The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/)
and the project uses [Semantic Versioning](https://semver.org/). Until 1.0, minor versions may break the API.

## [Unreleased] — 0.2.0 (milestone M2)

### Added
- `modules`: `TrModule` (`dependencies`, `register`, `start`, `stop`, `module_name`) and `TrBootstrap`
  (dependency ordering, missing-dependency, cycle and duplicate detection, container validation before any
  `start`, `shutdown` in reverse order).
- `TrInjector`: calls `_inject(c)` before `_ready()` through `SceneTree.node_added`, once per node; explicit
  `inject` / `inject_tree`; switchable container for scopes.
- `Truss` autoload and editor plugin (`plugin.cfg`), with the `truss/injection/automatic` project setting.
- `examples/minimal` with `tools/run_example.sh`, which checks the normal run and three failure modes.
- 90 gdUnit4 tests.

### Changed
- `TrContracts.describe()` names unnamed scripts (inner classes) by their first named base class.
- `TrBootstrap.add_all()` and `Truss.boot()` accept any `Array` of modules, so array literals work from dynamic calls.

## 0.1.0 (milestone M1)

### Added
- `core`: `TrResult` (success/failure, `unwrap`, `unwrap_or`, `map`, `and_then`), `TrOption`, `TrContracts`
  (`implements`, `require`, `describe`, `describe_value`; safe with freed objects).
- `di`: `TrServiceContainer` with singleton, scoped, transient and instance lifetimes, child scopes with overrides,
  contract checks on every resolution, cycle detection with the full chain, `validate()` that collects every
  problem, and `dispose()`.
- `messaging`: `TrEvent` and `TrEventBus` (subscription by class, base-class delivery, freed-handler cleanup,
  `unsubscribe_all`); `TrRequest`, `TrRequestHandler`, `TrMediator` and `TrBehavior` pipelines.
- 67 gdUnit4 tests, passing on Godot 4.5.1 and 4.7.2.
- Strict typing profile for Truss's own code (`directory_rules`, Godot 4.7+), `tools/compile_check.gd`,
  `tools/bench.gd` and a GitHub Actions matrix for Godot 4.5.1 and 4.7.2.
