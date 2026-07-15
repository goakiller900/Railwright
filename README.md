# Railwright

**Build smarter stations.**

Railwright is an in-game train station blueprint generator for Factorio 2.1.

The project is a modern successor inspired by BurnySc2's original **Train Station Blueprint Creator** (`BurnysTSBC`) and the later web-based Train Station Blueprint Creator. Railwright is a new implementation designed around the current Factorio runtime API and the prototypes that are actually available in the player's mod set.

## Current status — 0.2.1

Railwright 0.2.1 expands the first working in-game build into the full station-generator foundation.

### Station types

- Item loading stations.
- Item unloading stations.
- Fluid loading stations.
- Fluid unloading stations.
- Vertical stackers.
- Diagonal stackers.

### Train and layout settings

- Configurable locomotives per end and wagon count.
- Single-ended and double-headed trains.
- Optional train placement in generated blueprints.
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

## Development status

Railwright is still under active development. The 0.2.1 generators are the first in-game port of the behavior and station logic from the working web generator and need broad in-game testing across all combinations.

Planned follow-up work includes:

- More detailed dynamic train-limit formula controls.
- Improved capability detection for unusual modded entities.
- A native preview before creating the blueprint.
- Rebuilding stacker templates with modern Factorio 2.1 rail geometry instead of compatibility rail prototypes.
- Additional GUI quality-of-life improvements.

## Installation for development

Clone or download the repository into your Factorio mods directory as a folder named either:

```text
railwright
```

or with the version suffix:

```text
railwright_0.2.1
```

Start Factorio 2.1 and enable **Railwright** in the mod manager.

## Automatic builds and releases

GitHub Actions automatically validates the Lua syntax and packages the mod on every push to `main`, every pull request, and manual workflow run.

The version is read directly from `info.json`, and the resulting Factorio-compatible archive is built as:

```text
dist/railwright_<version>.zip
```

The ZIP contains a single correctly named top-level mod directory:

```text
railwright_<version>/
```

Development builds are available from the workflow run as a GitHub Actions artifact.

To publish a release:

1. Update the version in `info.json`.
2. Create and push a matching tag, for example `v0.2.1`.
3. GitHub Actions verifies that the tag matches `info.json`.
4. A GitHub Release is created automatically with `railwright_0.2.1.zip` attached.

For local packaging, run:

```text
python tools/package_mod.py
```

## Usage

1. Load a game.
2. Click the blueprint icon added by Railwright to the top GUI.
3. Select the station type.
4. Configure the train, station-specific options, and behavior settings.
5. Click **Create blueprint**.
6. The generated blueprint is placed directly in your cursor.

## Project structure

```text
control.lua                         Runtime event wiring
info.json                            Factorio mod metadata
locale/                              Localisation
scripts/constants.lua                Shared identifiers and option lists
scripts/state.lua                    Persistent per-player settings and migrations
scripts/gui.lua                      In-game configuration interface
scripts/generator.lua                Generator dispatch and validation
scripts/generator_builder.lua        Shared blueprint entity/wire builder
scripts/generator_common.lua         Shared train and station behavior logic
scripts/generator_normal.lua         Item loading/unloading generation
scripts/generator_fluid.lua          Fluid loading/unloading generation
scripts/generator_stacker.lua        Vertical and diagonal stacker generation
tools/package_mod.py                 Local/CI Factorio ZIP packager
.github/workflows/build-mod.yml      Automatic validation, packaging, and releases
```

## Credits

Railwright is an independent modern implementation inspired by the original work of **BurnySc2** on `BurnysTSBC` / Train Station Blueprint Creator.

The web generator that preceded Railwright remains an important reference for station geometry and expected features:

- Original project: `BurnySc2/Factorio-Train-Station-Blueprint-Creator`
- Factorio 2.1 web fork: `goakiller900/Factorio-Train-Station-Blueprint-Creator`

## License

GNU General Public License v3.0. See `LICENSE`.
