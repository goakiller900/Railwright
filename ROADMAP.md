# Railwright Roadmap

Railwright is already capable of generating item stations, fluid stations, and stackers. The next milestones focus on replacing remaining compatibility-era foundations first, then expanding station behavior and workflow features on top of a fully modern Factorio 2.1 base.

## Current priority — 0.3.0

### Modern rail generation

- Rebuild stacker templates around native Factorio 2.1 rail geometry.
- Replace `legacy-straight-rail` and `legacy-curved-rail` with the current rail prototypes used by Factorio 2.1.
- Recreate and validate vertical and diagonal stacker geometry using native straight, half-diagonal, and curved rail pieces.
- Verify rail signals and chain signals are positioned correctly for every supported stacker direction.
- Remove the dependency on compatibility/legacy rail prototypes entirely.
- Add regression fixtures for known-good stacker layouts before expanding the available layouts.
- Add more stacker layouts after the modern geometry foundation is stable.

## Next

### Full website behavior parity

- Expose advanced dynamic train-limit arithmetic settings.
- Review all circuit behavior against the working web generator.
- Verify Madzuri behavior for loading and unloading combinations.
- Expand requester/buffer chest controls where Factorio's current blueprint format allows it.

### Better GUI and workflow

- Group settings more clearly as the option count grows.
- Add contextual help/tooltips for behavior settings.
- Add a blueprint preview or summary before generation.
- Add reusable presets for common train and station layouts.

### Mod compatibility

- Improve capability detection for unusual modded inserters, containers, belts, pumps, tanks, and pipes.
- Handle optional Space Age entities and mechanics without making Space Age a hard dependency.
- Test against large overhaul mod sets, including Pyanodon-style prototype collections.

## Later ideas

- Save and name multiple Railwright presets per player.
- Generate coordinated station and stacker blueprint books.
- Import/export Railwright configuration strings.
- Additional station layouts and sequential/multi-stop designs.
- More localisation languages.

The roadmap is intentionally flexible. Correct blueprint generation and safe compatibility take priority over adding more options quickly.
