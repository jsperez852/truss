# Publishing on the Godot Asset Library

Guía paso a paso en español: [asset-library.es.md](asset-library.es.md).

What the submission form at https://godotengine.org/asset-library/asset/submit needs. Submitting is done by the
repository owner, logged in on the Asset Library.

| Field | Value |
|---|---|
| Title | Truss |
| Category | Scripts |
| Godot version | 4.5 |
| Version | the release, for example `0.6.0` |
| Repository host / URL | GitHub, `https://github.com/jsperez852/truss` |
| Issues URL | `https://github.com/jsperez852/truss/issues` |
| Download commit | the full commit hash of the release tag (`git rev-list -n 1 v0.6.0`); today's `main` is `987c4be491fd62feb924604cdeae12ee8cdd1e88` |
| Icon URL | `https://raw.githubusercontent.com/jsperez852/truss/v0.6.0/icon.png` (256×256 PNG) |
| License | MIT |
| Description | First paragraph of the README plus the Truss Lite link |

## What gets installed

The Asset Library downloads the repository archive at that commit. `.gitattributes` marks everything except
`addons/truss` as `export-ignore`, so the archive holds only the addon (with its own `LICENSE`). CI checks this
(step "Package contains only addons/truss").

## Verified for 0.6.0 (2026-11-08)

Done in a test project built from `git archive` of commit `987c4be` (the content the Asset Library downloads), on
Godot 4.5.1 (.NET build, Windows) and 4.7.2 (standard, Windows):

| Check | Result |
|---|---|
| Archive content | only `addons/truss` (87 files, with `LICENSE` and `icon.svg`) |
| Enabling the plugin (`EditorInterface.set_plugin_enabled`, the same call as the Plugins checkbox) | `[autoload]` gets `Truss="*res://addons/truss/truss.gd"` on 4.5.1 and `Truss="*uid://c7rd5ndqrad32"` on 4.7.2 (the uid of `truss.gd`, shipped in the package); `[editor_plugins]` lists `res://addons/truss/plugin.cfg` |
| Running a scene with `TrPhases.new(&"round")` connected to a debugger (`--remote-debug`) | three `truss:phase` messages (`["round", "", "title"]`, `["round", "title", "playing"]`, `["round", "playing", "over"]`), without `Truss.boot()` |
| `examples/arena` connected to a debugger | `truss:boot` (5 modules, 11 services), 42 `truss:event`, 4 `truss:request` (one async) |
| Truss tab (`TrDebugPanel`) fed with those messages | [docs/images/debugger-tab.png](images/debugger-tab.png) |

Not covered: clicking the checkbox and opening the tab in a running editor window by hand.

## Before submitting a version

1. CI is green on the tag.
2. In an empty project: AssetLib tab → install → enable **Truss** in Project Settings → Plugins. The `Truss`
   autoload appears in Project Settings → Globals.
3. Run a scene from the editor that creates `TrPhases.new(&"test")` and calls `start()`: the **Truss** tab of the
   Debugger panel shows the phase.
