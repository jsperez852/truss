# Contributing to Truss

Thanks for helping. Bug reports with a small reproduction are the most useful contribution; pull requests are
welcome too.

## Reporting a bug

Open an issue with the **Bug report** template. Include the Godot version (and whether it's the .NET build), the
Truss version (`addons/truss/plugin.cfg`), the smallest code that shows the problem, and what you expected.

## Proposing a feature

Open an issue with the **Feature request** template first. Describe the game problem, not only the API you want:
Truss adds pieces when real projects need them (see the evidence sections of the [RFCs](docs/rfcs)). Large
changes get an RFC in `docs/rfcs/` before code.

## Pull requests

1. Fork, create a branch from `main`.
2. Set up and run the checks (Godot 4.5.1 or later on your `PATH` as `godot`):

   ```bash
   bash tools/install_gdunit.sh
   godot --headless --path . --import
   godot --headless --path . -s res://tools/compile_check.gd
   GODOT_BIN="$(command -v godot)" addons/gdUnit4/runtest.sh -a res://tests -c --headless --ignoreHeadlessMode
   GODOT="$(command -v godot)" bash tools/test_tooling.sh
   GODOT="$(command -v godot)" bash tools/run_arena.sh
   ```

   CI runs these and the other `tools/*.sh` scripts on Godot 4.5.1 and 4.7.2.
3. Keep to the code style: typed GDScript that passes the strict profile (`tools/strict_profile.gd` describes it),
   doc comments (`##`) on public members, errors as `TrResult` for expected failures and `push_error` for misuse,
   no per-frame work unless the caller asks for it.
4. Add tests next to the existing ones in `tests/<module>/`. A bug fix comes with a test that fails without it.
5. Update the guide in `docs/guide/` and add a line to `CHANGELOG.md` under an "Unreleased" heading.
6. Documentation is in English. Spanish summaries are welcome in the README.

## Versioning

Truss follows [Semantic Versioning](https://semver.org/) with the usual pre-1.0 rule:

| Release | May contain | Example |
|---|---|---|
| Patch (`0.6.x`) | Fixes, docs, and additions that don't change existing behavior | A new option with a default that keeps today's behavior |
| Minor (`0.x.0`) | New pieces and, before 1.0, behavior changes | A new module; a default that changes |
| Major (`1.0` and later) | Breaking changes only in major versions | — |

Every behavior change is listed under **Changed** in `CHANGELOG.md` with what to do when upgrading, and the
release notes repeat it. Nothing is removed without being deprecated (a `push_warning` and a note in the guide)
for at least one minor version first. 1.0 freezes the API.

## License

By contributing you agree that your contribution is licensed under the [MIT License](LICENSE).
