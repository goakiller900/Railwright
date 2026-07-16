# Railwright

[![Build Railwright Mod](https://github.com/goakiller900/Railwright/actions/workflows/build-mod.yml/badge.svg)](https://github.com/goakiller900/Railwright/actions/workflows/build-mod.yml)
[![GitHub release](https://img.shields.io/github/v/release/goakiller900/Railwright)](https://github.com/goakiller900/Railwright/releases)
[![Factorio 2.1](https://img.shields.io/badge/Factorio-2.1-orange)](https://factorio.com/)
[![License: GPL v3](https://img.shields.io/badge/License-GPLv3-blue)](LICENSE)

**Build smarter stations.**

Railwright is an in-game train station blueprint generator for Factorio 2.1.

The project is a modern successor inspired by BurnySc2's original **Train Station Blueprint Creator** (`BurnysTSBC`) and the later web-based Train Station Blueprint Creator. Railwright is a new implementation designed around the current Factorio runtime API and the prototypes that are actually available in the player's mod set.

## Current status — 0.3.3

Railwright 0.3.3 focuses the stacker generator on the two parallel layouts that are confirmed working with Factorio 2.1 native rails: **Left-Right** and **Right-Left**. The unreliable diagonal stacker option has been temporarily removed, and the stacker menu now hides station-only settings that do not apply to stacker blueprints.

### Station types

- Item loading stations.
- Item unloading stations.
- Fluid loading stations.
- Fluid unloading stations.
- Parallel stackers with Left-Right and Right-Left layouts.

### Train and layout settings

- Configurable locomotives per end and wagon count.
- Single-ended and double-headed trains for station blueprints.
- Optional train placement in generated station blueprints.
- Left, right, or both sides for item stations.
- Left or right pump side for fluid stations.
- Configurable storage-tank columns.
- Configurable stacker lane count and direction.

### Item station settings

- Runtime prototype pickers for inserters, chests, transport belts, and splitters.
- Inserter filters.
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

The native entity and item pickers use the prototypes loaded by the running game. This lets Railwright expose compatible entities and items from the player's actual mod set instead of relying on a hard-coded vanilla item database.

See [`changelog.txt`](changelog.txt) for version history and [`ROADMAP.md`](ROADMAP.md) for planned work.

## Diagonal stackers

Starting with **0.3.3**, diagonal stacker generation is temporarily unavailable. The experimental Factorio 2.1 version was not reliable enough to ship consistently, especially when lane count, train length, and signal placement changed.

If you have a reliable approach for generating diagonal stackers with modern Factorio 2.1 rails, contributions are very welcome. Please open a pull request with your implementation or a reproducible working layout that can be used as a reference.

## Known limitations

Railwright is still under active development and the generator has many possible setting combinations.

- Diagonal stackers are temporarily unavailable while a reliable Factorio 2.1 implementation is worked out.
- The automatic dynamic train-limit behavior is available, but the web generator's advanced custom arithmetic formula controls are not exposed yet.
- Unusual modded prototypes may still need additional capability detection even when they appear in a runtime picker.
- Broad testing across overhaul mod packs is ongoing.

## Installation for development

Clone or download the repository into your Factorio mods directory as a folder named either:

```text
railwright
```

or with the version suffix:

```text
railwright_0.3.3
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

To validate the release artwork locally:

```text
python tools/validate_png.py thumbnail.png graphics/railwright-shortcut-x56.png
```

To preview the GitHub release notes generated from a changelog entry:

```text
python tools/release_notes.py 0.3.3
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
data.lua                            Shortcut-bar prototype definitions
info.json                           Factorio mod metadata
changelog.txt                       Factorio-native release changelog
graphics/                           In-game shortcut and UI graphics
locale/                             Localisation
scripts/constants.lua               Shared identifiers and option lists
scripts/state.lua                   Persistent per-player settings and migrations
scripts/gui.lua                     In-game configuration interface
scripts/generator.lua               Generator dispatch and validation
scripts/generator_builder.lua       Shared blueprint entity/wire builder
scripts/generator_common.lua        Shared train and station behavior logic
scripts/generator_normal.lua        Item loading/unloading generation
scripts/generator_fluid.lua         Fluid loading/unloading generation
scripts/generator_stacker.lua       Parallel stacker generation
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
