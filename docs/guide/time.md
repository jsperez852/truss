# time: pause tokens, hit stop and app lifecycle

All three live on the `Truss` autoload and work **without booting** any module.

## Pause tokens

```gdscript
var token: TrPauseToken = Truss.pause.acquire(&"inventory_menu")
# ... later
token.release()
```

- The game stays paused (`SceneTree.paused`) while **any** token is held. Closing one menu can't unpause the game
  under a dialog that's still open.
- A token releases itself when it's freed. Keep it in a member variable of the menu and the pause ends when the
  menu goes away, even if it's closed in an unexpected way.
- When the last token is released, the pause state from before the first token comes back. Code that still sets
  `get_tree().paused` directly isn't overridden.
- `is_paused()`, `holders()` (`[&"inventory_menu"]`) and the `changed(paused)` signal. The debugger tab logs every change.
- `reset()` releases everything (for example on a scene change).

Nodes that must keep running while paused (the pause menu itself) still need
`process_mode = PROCESS_MODE_ALWAYS`.

## Hit stop

```gdscript
func _on_hit_landed() -> void:
	Truss.pause.hit_stop(0.08)          # 80 ms at 5 % speed
	Truss.pause.hit_stop(0.2, 0.3)      # a heavier hit: 200 ms at 30 %
```

- Changes `Engine.time_scale`, not `paused`, so UI, particles and audio keep running.
- Overlapping hit stops keep the **lowest** scale until the last one ends, then the previous time scale comes back.
- Scales are relative to the game's own time scale: during a 0.5× slow-motion, `hit_stop(0.1, 0.1)` runs at 0.05×.
- The duration is real time (a timer that ignores the time scale). Measured on Godot 4.5.1 and 4.7.2: within one
  frame of the requested time. With `--fixed-fps`, timers follow simulated time instead, which is what automated
  runs want.

## App lifecycle events

| Event (`TrAppEvents.*`) | Node notification | When |
|---|---|---|
| `FocusLost` / `FocusGained` | `NOTIFICATION_APPLICATION_FOCUS_OUT` / `_IN` | The window loses or regains focus |
| `Paused` / `Resumed` | `NOTIFICATION_APPLICATION_PAUSED` / `_RESUMED` | Android/iOS send the app to the background and back |
| `QuitRequested` | `NOTIFICATION_WM_CLOSE_REQUEST` | Close button or OS quit request |

All of them extend `TrAppEvents.AppEvent`. Use them through the bus or the autoload's signal:

```gdscript
bus.subscribe(TrAppEvents.FocusLost, func(_e: TrAppEvents.FocusLost) -> void: save_game())
Truss.app_event.connect(func(e: TrAppEvents.AppEvent) -> void: print(TrContracts.describe_value(e)))
```

The bus receives them only after `Truss.boot()` and only if a `TrEventBus` is registered; the signal always fires.

**Pause on focus loss**: enable `truss/lifecycle/pause_on_focus_loss` (Project Settings, default `false`). Truss then
holds a `focus_lost` token while the window is unfocused **or** the OS has paused the app, and releases it when both
are back. Recommended on mobile.

## A GDScript detail

During `NOTIFICATION_PREDELETE`, a `RefCounted` script can't call its own methods: the call fails with
"Attempt to call function ... in base 'null instance'" (seen on 4.5.1 and 4.7.2). `TrPauseToken` releases itself
inline for that reason. Keep the same in mind for your own cleanup code in `_notification`.
