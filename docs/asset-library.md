# Publishing on the Godot Asset Library

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
| Download commit | the full commit hash of the release tag (`git rev-list -n 1 v0.6.0`) |
| Icon URL | `https://raw.githubusercontent.com/jsperez852/truss/v0.6.0/icon.png` (256×256 PNG) |
| License | MIT |
| Description | First paragraph of the README plus the Truss Lite link |

## What gets installed

The Asset Library downloads the repository archive at that commit. `.gitattributes` marks everything except
`addons/truss` as `export-ignore`, so the archive holds only the addon (with its own `LICENSE`). CI checks this
(step "Package contains only addons/truss").

## Before submitting a version

1. CI is green on the tag.
2. In an empty project: AssetLib tab → install → enable **Truss** in Project Settings → Plugins. The `Truss`
   autoload appears in Project Settings → Globals.
3. Run a scene from the editor that creates `TrPhases.new(&"test")` and calls `start()`: the **Truss** tab of the
   Debugger panel shows the phase.
