# Railwright

**Build smarter stations.**

Railwright is an in-game train station blueprint generator for Factorio 2.1.

The project is a modern successor inspired by BurnySc2's original **Train Station Blueprint Creator** (`BurnysTSBC`) and the later web-based Train Station Blueprint Creator. Railwright is a new implementation designed around the current Factorio runtime API and the prototypes that are actually available in the player's mod set.

## Current status

Railwright is in early development.

The first development milestone already includes:

- A Railwright button in the in-game top GUI.
- A native station configuration window.
- Loading and unloading station generation.
- Configurable locomotive and cargo-wagon counts.
- Single-ended and double-headed train layouts.
- One-sided or two-sided cargo handling.
- Native entity pickers for inserters, chests, and transport belts.
- Optional train placement in the generated blueprint.
- Direct creation of the generated blueprint in the player's cursor.
- Per-player settings stored in Factorio 2.x `storage`.

The native entity pickers deliberately use the prototypes loaded by the running game. This is the foundation for supporting overhaul mods without maintaining a hard-coded list of entity names.

## Planned features

The goal is to bring the useful feature set of the Train Station Blueprint Creator into a native Factorio 2.1 mod while modernizing the implementation:

- Filtered inserters using current Factorio filtering behavior.
- Logistic requester and buffer chest configuration.
- Automatic locomotive refuelling.
- Fluid loading and unloading stations.
- Circuit wire options.
- Madzuri-style balanced loading and unloading.
- Dynamic train limits.
- Train-stop enable conditions.
- Lamps and power poles.
- Modern Factorio 2.1 stackers using the current rail geometry.
- Better modded-entity capability detection and compatibility feedback.
- Blueprint previews and quality-of-life improvements to the GUI.

## Installation for development

Clone or download the repository into your Factorio mods directory as a folder named either:

```text
railwright
```

or with the version suffix:

```text
railwright_0.1.0
```

Start Factorio 2.1 and enable **Railwright** in the mod manager.

## Usage

1. Load a game.
2. Click the blueprint icon added by Railwright to the top GUI.
3. Configure the station.
4. Select entities from the currently loaded game for the inserter, chest, and belt options.
5. Click **Create blueprint**.
6. The generated blueprint is placed directly in your cursor.

## Project structure

```text
control.lua              Runtime event wiring
info.json                 Factorio mod metadata
locale/                   Localisation
scripts/constants.lua     Shared identifiers
scripts/state.lua         Persistent per-player settings
scripts/gui.lua           In-game configuration interface
scripts/generator.lua     Blueprint geometry and native blueprint creation
```

## Credits

Railwright is an independent modern implementation inspired by the original work of **BurnySc2** on `BurnysTSBC` / Train Station Blueprint Creator.

The web generator that preceded Railwright remains an important reference for station geometry and expected features:

- Original project: `BurnySc2/Factorio-Train-Station-Blueprint-Creator`
- Factorio 2.1 web fork: `goakiller900/Factorio-Train-Station-Blueprint-Creator`

## License

GNU General Public License v3.0. See `LICENSE`.
