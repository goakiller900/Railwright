# Railwright

[![Build Railwright Mod](https://github.com/goakiller900/Railwright/actions/workflows/build-mod.yml/badge.svg)](https://github.com/goakiller900/Railwright/actions/workflows/build-mod.yml)
[![GitHub release](https://img.shields.io/github/v/release/goakiller900/Railwright)](https://github.com/goakiller900/Railwright/releases)
[![Factorio 2.1](https://img.shields.io/badge/Factorio-2.1-orange)](https://factorio.com/)
[![License: GPL v3](https://img.shields.io/badge/License-GPLv3-blue)](LICENSE)

**Build smarter stations.**

Railwright is an in-game train station blueprint generator for Factorio 2.1.

The project is a modern successor inspired by BurnySc2's original **Train Station Blueprint Creator** (`BurnysTSBC`) and the later web-based Train Station Blueprint Creator. Railwright is a new implementation designed around the current Factorio runtime API and the prototypes that are actually available in the player's mod set.

## Current status — 0.3.8

Railwright 0.3.8 adds optional dynamic train-stop names for generated item and fluid stations while keeping the existing station and stacker layouts unchanged. Native Factorio 2.1 diagonal stackers remain available as an experimental feature.

When **Deadlock's Stacking Beltboxes & Compact Loaders Continued** is installed, item stations can use compatible compact loaders instead of inserters. Loader stations use direct staggered splitter chains appropriate for 1x1 loaders. This integration is optional; ordinary inserter stations remain the default.

### Station types

- Item loading stations.
- Item unloading stations.
- Fluid loading stations.
- Fluid unloading stations.
- Parallel stackers with Left-Right and Right-Left layouts.
- Experimental diagonal stackers with Left-Right and Right-Left layouts.

### Train and layout settings

- Configurable locomotives per end and wagon count.
- Single-ended and double-headed trains for station blueprints.
- Optional train placement in generated station blueprints.
- Left, right, or both sides for item stations.
- Left or right pump side for fluid stations.
- Configurable storage-tank columns.
- Configurable stacker lane count and direction.

### Item station settings

- Runtime prototype pickers for inserters, compatible compact loaders, chests, transport belts, and splitters.
- Inserter and compact-loader filters.
- Belt flow toward the front, back, or no longitudinal belt output.
- Chest slot limiting.
- Logistic requester/buffer chest requests.
- Request-from-buffer behavior.
- Madzuri-style balanced loading and unloading for non-logistic chests.

### Fluid station settings

- Runtime prototype pickers for pumps, storage tanks, and pipes.
- Configurable storage-tank columns.
- Optional pipe connections between tank rows.

### Station behavior

- Green and red circuit wiring between storage entities.
- Optional connection between both sides of item stations.
- Automatic locomotive refuelling with requester chests.
- Manual or dynamic train limits.
- Circuit-controlled train-stop enable/disable behavior.
- Optional lamps near power poles.
- Optional runtime-managed dynamic station names.

### Dynamic station names

Enable **Dynamic station name** to add one dedicated Railwright station-name combinator to a generated item or fluid station. Supply exactly one positive item or fluid signal to the combinator input and Railwright's runtime script renames the associated stop with a rich-text resource icon followed by the existing **Station name** value. For example, a base name of `Load` becomes `[item=iron-ore] Load` or `[fluid=crude-oil] Load`.

When the signal disappears, Railwright preserves the last valid dynamic name instead of flickering back to the base name. If more than one different resource is present, the input is ambiguous and the current valid name is preserved. Before any valid resource is seen, the configured station name remains unchanged. The combinator's direct output-red wire identifies its train stop; the runtime reads only the marker's input side and does not pass the resource signal through to the stop.

The dedicated entity currently reuses the vanilla decider-combinator visuals and audio. Its item and recipe are unlocked by the normal circuit-network technology. Actual renaming is performed by Railwright runtime scripting, not by blueprint-only circuit logic.

The native entity and item pickers use the prototypes loaded by the running game. This lets Railwright expose compatible entities and items from the player's actual mod set instead of relying on a hard-coded vanilla item database.

See [`changelog.txt`](changelog.txt) for version history and [`ROADMAP.md`](ROADMAP.md) for planned work.

## Diagonal stackers

Starting with **0.3.5**, the Railwright stacker menu shows a **Diagonal stacker (experimental)** checkbox by default. To hide it, open **Settings > Mod settings > Per player** and disable **Show experimental diagonal stacker option**.

The generator constructs its geometry on a temporary Factorio surface through the native rail-planner API, then uses the signal locations reported by the generated rail ends. In-game testing has covered both directions with short, standard, long, and ten-lane configurations, but broader testing is still needed before the experimental label is removed.

## Known limitations

Railwright is still under active development and the generator has many possible setting combinations.

- Diagonal stackers remain experimental and may still expose edge cases with unusual train sizes, lane counts, or modded rail prototypes.
- Loader-based loading stations can appear offset in the blueprint preview; the entities align correctly after the blueprint is placed in the world. Somehow. We have no idea why this works either.
- Inserter-based item stations have a minor belt-routing issue that is deferred to a later release.
- The automatic dynamic train-limit behavior is available, but the web generator's advanced custom arithmetic formula controls are not exposed yet.
- Unusual modded prototypes may still need additional capability detection even when they appear in a runtime picker.
- Broad testing across overhaul mod packs is ongoing.
- The Railwright station-name combinator intentionally uses vanilla decider-combinator artwork in 0.3.8.

## Installation for development

Clone or download the repository into your Factorio mods directory as a folder named either:

```text
railwright
```

or with the version suffix:

```text
railwright_0.3.8
```

Start Factorio 2.1 and enable **Railwright** in the mod manager.

## Automatic builds and releases

GitHub Actions validates the Lua syntax, required PNG artwork, and packaged mod on every branch push, pull request, and manual workflow run. Development ZIPs are available directly from the workflow run as artifacts.

The version is read from `info.json`, and the resulting Factorio-compatible archive is built as:

```text
dist/railwright_<version>.zip
```

The ZIP contains a single correctly named top-level mod directory and includes the Factorio-native `changelog.txt`.

Releases are intentionally restricted to `main`. To publish a new version:

1. Develop and test the change on a branch.
2. Update the version in `info.json`.
3. Add the matching version entry to `changelog.txt`.
4. Test the branch artifact in Factorio.
5. Merge the tested release into `main`.

The workflow then automatically creates the `v<version>` tag, generates GitHub Release notes from `changelog.txt`, attaches the packaged ZIP, and uploads that same ZIP to the Factorio Mod Portal when the version is not already published.

Existing release tags are never moved or overwritten.

See [`docs/RELEASING.md`](docs/RELEASING.md) for the full release process.

For local packaging, run:

```text
python tools/package_mod.py
```

On Windows, the equivalent native PowerShell build also creates a separate debug-command reference:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\build.ps1
```

To validate the release artwork locally:

```text
python tools/validate_png.py thumbnail.png graphics/railwright-shortcut-x56.png
```

To preview the GitHub release notes generated from a changelog entry:

```text
python tools/release_notes.py 0.3.8
```

## Usage

1. Load a game.
2. Add **Railwright** to the shortcut bar through Factorio's shortcut configuration if it is not already visible.
3. Click the Railwright shortcut-bar icon.
4. Select the station type.
5. Configure the train, station-specific options, and behavior settings.
6. Click **Create blueprint**.
7. The generated blueprint is placed directly in your cursor.

## Contributing

Feature and fix work should happen on branches rather than directly on `main`. Blueprint-generation reports should include the Railwright version, Factorio version, relevant mods, station settings, and the generated blueprint when practical.

Diagonal stacker contributions are especially welcome. If you have a reliable modern Factorio 2.1 solution, please open a pull request so it can be tested across different train lengths and lane counts.

See [`CONTRIBUTING.md`](CONTRIBUTING.md) for the development workflow. GitHub issue templates are available for bugs and feature requests.

## Project structure

```text
control.lua                         Runtime event wiring
data.lua                            Data-stage prototype registration
prototypes/station-name-combinator.lua Dedicated marker entity, item, recipe, and unlock
info.json                           Factorio mod metadata
changelog.txt                       Factorio-native release changelog
graphics/                           In-game shortcut and UI graphics
locale/                             Localisation
scripts/constants.lua               Shared identifiers and option lists
scripts/state.lua                   Persistent per-player settings and migrations
scripts/gui.lua                     In-game configuration interface
scripts/dynamic_station_names.lua   Runtime marker registration and stop naming
scripts/generator.lua               Generator dispatch and validation
scripts/generator_builder.lua       Shared blueprint entity/wire builder
scripts/generator_common.lua        Shared train and station behavior logic
scripts/generator_normal.lua        Item loading/unloading generation
scripts/generator_fluid.lua         Fluid loading/unloading generation
scripts/generator_stacker.lua       Parallel stacker generation
scripts/generator_stacker_diagonal.lua Experimental native diagonal stacker generation
settings.lua                        Per-player mod settings
build.ps1                           Native PowerShell local packager
tools/package_mod.py                Local/CI Factorio ZIP packager
tools/release_notes.py              Changelog-to-GitHub release note generator
tools/validate_png.py               PNG structure and release-art validation
docs/RELEASING.md                   Release process and safety rules
.github/workflows/build-mod.yml     Validation, packaging, releases, and portal uploads
```

## Credits

Railwright is an independent modern implementation inspired by the original work of **BurnySc2** on `BurnysTSBC` / Train Station Blueprint Creator.

The web generator that preceded Railwright remains an important reference for station geometry and expected features:

- Original project: `BurnySc2/Factorio-Train-Station-Blueprint-Creator`
- Factorio 2.1 web fork: `goakiller900/Factorio-Train-Station-Blueprint-Creator`

## License

GNU General Public License v3.0. See `LICENSE`.
