# Benchmarks

`tools/bench.gd` compares Truss with native Godot mechanisms. Run it with:

```bash
godot --headless --path . -s res://tools/bench.gd -- --iterations=200000
```

Results on Godot 4.7.2 (official editor build, which is a debug build), Windows 11, 200,000 iterations, 2026-11-08.
Compare rows with each other, not with other machines. CI prints the same table for every push in the job summary.

| Operation | µs per call |
|---|---|
| native signal emit (3 handlers) | 0.97 |
| `TrEventBus.publish` (3 handlers) | 3.95 |
| `TrEventBus.publish` with a new event each time | 5.78 |
| direct `handler.handle()` call | 2.65 |
| `TrMediator.send` (0 behaviors) | 6.70 |
| `TrMediator.send` (2 behaviors) | 14.87 |
| `TrServiceContainer.get_service` (created singleton) | 2.45 |
| `TrServiceContainer.get_service` (transient) | 12.67 |
| plain `Counter.new()` | 1.19 |

## Reading the numbers

- The event bus costs about **4× a native signal**. At 60 FPS a frame lasts 16,667 µs, so a few hundred events per
  frame are affordable, but per-entity, per-frame notifications should stay on signals or direct calls.
- `TrMediator.send` adds about 4 µs over a direct call, plus about 4 µs per behavior. Use it for actions
  (a few per frame at most), not for movement.
- Resolve services once (in `_inject` or a constructor) and keep the reference. Don't call `get_service` in `_process`.
