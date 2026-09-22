# Contributing

Issues and pull requests: <https://github.com/LeoStumpf/ZoneCraft/issues>. Small, focused
changes are easiest to take. Work happens directly on `main`.

## Licence

ZoneCraft is **AGPL-3.0-or-later**. By contributing you agree your change is under the same
licence. Every non-generated `.dart` file carries this 15-line header, and
`test/license_test.dart` fails when one does not:

```dart
// ZoneCraft — composable zone layers on OpenStreetMap.
// Copyright (C) 2026 Leo Stumpf <leo.m.stumpf@gmail.com>
//
// This program is free software: you can redistribute it and/or modify it
// under the terms of the GNU Affero General Public License as published by
// the Free Software Foundation, either version 3 of the License, or (at your
// option) any later version.
//
// This program is distributed in the hope that it will be useful, but WITHOUT
// ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
// FITNESS FOR A PARTICULAR PURPOSE.  See the GNU Affero General Public
// License for more details.
//
// You should have received a copy of the GNU Affero General Public License
// along with this program.  If not, see <https://www.gnu.org/licenses/>.
```

Generated code (`*.g.dart`, `test/generated_migrations/`) is exempt: a header there would
not survive the next `build_runner` run.

## The gate

Every push to `main` runs CI (see [Continuous Integration and Releases](Continuous-Integration-and-Releases.md)), which is the same
gate `scripts/build.sh` runs locally: the lockfile is honoured, `dart format`, `flutter
analyze`, `flutter test`, then a **release** build. Run `scripts/build.sh --install --run`
and look at the change on a device before you push — an emulator-less runner cannot tell
you a control is unreachable or a band is invisible.

## Rules that are tests

Some of the project's invariants are guard tests that read files, so a change that breaks
one fails fast rather than on a device. The ones you are most likely to meet:

| Test | What it holds |
|---|---|
| `test/license_test.dart` | The header above on every `.dart` file; the docs name the AGPL. |
| `test/app_id_test.dart` | The app id `io.github.leostumpf.zonecraft` agrees across Gradle, Kotlin, the MethodChannel on both sides, the User-Agent and the scripts. |
| `test/app_info_test.dart` | `kAppVersion` equals `pubspec.yaml`'s version; the User-Agent carries it. |
| `test/android_manifest_test.dart` | The share/view intent filters stay separate from the `zonecraft://` one; `https` and `mailto` are queried. |
| `test/tile_source_test.dart` | The community OSM tile source never allows prefetch. |
| `test/migration_test.dart` | Every schema version has a snapshot in `drift_schemas/` and migrates. |
| `test/export_roundtrip_test.dart` | `export → import → export` is byte-identical for every type. |
| `test/map_controls_test.dart` | No two map controls in one area share an icon. |
| `test/layer_actions_test.dart`, `test/selection_test.dart` | Every layer type's actions and editor are stated, not inferred. |

## Rules that are not tests

- **No telemetry, ever.** No crash reporting, analytics or advertising id. Anything that
  sends data has to be reflected in `PRIVACY.md`, the About screen and the Play data-safety
  answers — which is why nothing does.
- **Every outbound HTTP call has a timeout**, and every request to a donated service goes
  through a pacer. No autocomplete against Nominatim; its policy forbids it.
- **Number entry goes through `parseDecimal`**, never bare `double.tryParse` — a
  comma-decimal locale would otherwise make a field silently do nothing.
- **A layer action is defined once** (`lib/ui/layer_actions.dart`) and a map control once
  (`lib/ui/map_controls.dart`); the menus, sheets and guide all render those lists. Never add
  one inline.
- **Schema changes are append-only** and must dump a snapshot — see
  [Database and Migrations](Database-and-Migrations.md).
- **A control that cannot act is greyed and says why when pressed**; a control the layer's
  type can never use is hidden. See [Architecture](Architecture.md).

Planning notes and checklists are kept out of the repository (a local, gitignored
`planning/` folder); the repo root carries only the public documents. The wiki you are reading
is where user and developer documentation lives.
