# Railwright

**Build smarter stations.**

> ## Beta / Work in progress
>
> **Railwright is under active development and should still be considered beta software.**
>
> The core generator supports item stations, fluid stations, native Factorio 2.1 parallel stackers, and experimental diagonal stackers. Railwright is already useful, but it is not yet feature-complete and unusual combinations of settings or modded entities may still need additional testing.
>
> Some options may change as the mod grows. Bug reports, blueprint examples, testing, and contributions are very welcome.

---

Railwright is an in-game train station blueprint generator for **Factorio 2.1**.

Instead of manually rebuilding the same station layouts, configure the train and station you need and Railwright generates the finished blueprint directly into your cursor.

Railwright is a modern successor inspired by **BurnySc2's original Train Station Blueprint Creator** and the later web-based version, rebuilt around the current Factorio runtime API and the prototypes loaded in your game.

---

## What's new in 0.3.6

- Optional support for compact loaders from **Deadlock's Stacking Beltboxes & Compact Loaders Continued**.
- Direct staggered splitter chains for compact-loader loading and unloading stations.
- Correct compact-loader directions on both sides of the train.
- A clearer generator window with a live blueprint summary.
- Immediate feedback for invalid train sizes and stacker lane counts.
- Contextual controls that appear only when they apply.
- Focused tooltips for important station and stacker options.
- Front-locomotive refuelling equipment no longer overlaps the train stop.

---

## Features

### Item loading and unloading stations

Create configurable cargo stations with support for:

- Loading and unloading stations
- Left-sided, right-sided, or double-sided layouts
- Configurable locomotive and cargo-wagon counts
- Single-headed and double-headed trains
- Optional train placement in the generated blueprint
- Configurable inserters, chests, belts, and splitters
- Optional compatible compact loaders
- Transfer filters
- Chest slot limits
- Logistic requester and buffer chest requests
- Request-from-buffer behaviour
- Belt flow toward the front, back, or no longitudinal belt output

Ordinary inserter stations remain the default. When **Deadlock's Stacking Beltboxes & Compact Loaders Continued** is installed, Railwright can use compatible 1x1 compact loaders as an alternative transfer method.

Railwright uses the actual prototypes loaded in your game, allowing many compatible entities and items from other mods to appear directly in its selectors.

---

### Fluid loading and unloading stations

Generate complete fluid stations with configurable:

- Loading or unloading direction
- Pump side and pump type
- Storage tank type
- Pipe type
- Number of storage-tank columns
- Optional pipe connections between tank rows
- Locomotive and fluid-wagon counts

The fluid generator lays out the station around the selected train configuration.

---

### Train stackers

Generate native Factorio 2.1 train stackers without manually placing every rail section and signal.

Supported parallel layouts:

- **Left-Right**
- **Right-Left**
- Configurable holding-lane count
- Configurable locomotive and wagon count for sizing

Both parallel layouts use native Factorio 2.1 rails and dedicated geometry for their respective directions.

#### Experimental diagonal stackers

Diagonal stackers are available again as an **experimental** option. They are constructed with Factorio's native rail-planner geometry and support both Left-Right and Right-Left directions.

The option is visible by default and can be hidden in **Settings > Mod settings > Per player**.

Diagonal layouts should be inspected before use in a live rail network. More combinations of train lengths, lane counts, and modded rail prototypes still need testing before the experimental label can be removed.

If you have Factorio 2.1 rail-generation experience, testing results and contributions are very welcome.

---

## Station behaviour

Generated stations can include configurable behaviour such as:

- Green and red circuit-network wiring
- Circuit connections between both sides of an item station
- Madzuri-style balanced loading and unloading for inserter stations
- Automatic locomotive refuelling
- Configurable fuel type and amount
- Manual or dynamic train limits
- Circuit-controlled train-stop enable/disable conditions
- Optional lamps around the station

The goal is to generate stations that are not only laid out, but already contain much of the behaviour and circuit logic you would otherwise build manually.

---

## Mod compatibility

Railwright does not rely entirely on a hard-coded list of vanilla items. Its entity and item selectors use the prototypes loaded in the current game.

This allows many compatible modded entities to be selected, including alternative:

- Inserters
- Compact loaders
- Chests
- Belts and splitters
- Pumps
- Storage tanks and pipes
- Fuel items
- Filter and logistic-request items

Not every mod can be supported automatically. Mods may introduce entities with custom scripts, unusual prototype definitions, or behaviour that differs from their vanilla counterpart. Compatibility improvements may be added where practical, and reports involving modded entities are welcome.

---

## How to use

1. Open or load a game with Railwright enabled.
2. Add the **Railwright** button to your shortcut bar if it is not already visible.
3. Click the Railwright shortcut.
4. Select the station or stacker type.
5. Configure the train, layout, entities, and behaviour options.
6. Click **Create blueprint**.
7. Place the generated blueprint, save it to your library, or modify it however you like.

---

## Known issues

- Diagonal stackers remain experimental while more train lengths, lane counts, and mod combinations are tested.
- Loader-based loading stations can look offset in the blueprint preview, but align correctly when placed in the world. Somehow. We have no idea why this works either.
- Inserter-based item stations have a minor belt-routing issue planned for a later release.
- Unusual modded prototypes may require additional capability detection even when they appear in a selector.

---

## Why Railwright?

Large factories often contain dozens or hundreds of train stations. Building every station manually becomes repetitive, especially when they need to follow the same standards for train length, belt layout, transfer configuration, circuit wiring, refuelling, train limits, and loading balance.

Railwright turns those repeated design decisions into configurable options.

**Configure it once, generate it, and get back to building the factory.**

---

## Development

Railwright is developed openly and remains under active development. Planned and investigated improvements include:

- Continued testing and refinement of diagonal stackers
- More advanced dynamic train-limit configuration
- Continued mod-compatibility improvements
- More localisation
- Fixing the remaining inserter-station belt-routing issue

Ideas, working blueprint references, testing, code contributions, and bug reports are greatly appreciated.

---

## Credits

Railwright is an independent modern implementation inspired by the work of **BurnySc2**, creator of the original **Burnys Train Station Blueprint Creator** and the later web-based Train Station Blueprint Creator.

Railwright is maintained by **goakiller900**.

---

## Source code and issues

Source code, development builds, bug reports, feature requests, and contributions:

https://github.com/goakiller900/Railwright

---

**Build smarter stations. Build bigger factories.**
