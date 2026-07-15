# Contributing to Railwright

Thanks for helping improve Railwright.

## Development workflow

Railwright uses `main` as the release branch. Feature and fix work should happen on dedicated branches and be merged only after the generated mod ZIP has been tested in Factorio.

1. Create a branch from the latest `main`.
2. Keep the branch focused on one feature, fix, or project-maintenance task.
3. Push the branch and download the ZIP produced by GitHub Actions.
4. Test the generated blueprint in Factorio 2.1.
5. Open a pull request describing what changed and what was tested.
6. Merge only when the branch is ready to become part of the next release.

Do not manually move or recreate release tags. The release workflow creates `v<version>` from `main` and refuses to overwrite an existing version tag.

## Release changes

Before a new version is merged to `main`:

- Update `version` in `info.json`.
- Add a matching entry to `changelog.txt`.
- Make sure the changelog entry describes player-visible changes, fixes, and compatibility notes.
- Test the GitHub Actions artifact in-game.

CI requires the current `info.json` version to exist in `changelog.txt`.

## Reporting blueprint-generation bugs

Blueprint bugs are easiest to reproduce when the report includes:

- Railwright version.
- Factorio version.
- Relevant installed mods or overhaul pack.
- Station type.
- Train layout and Railwright settings used.
- The generated blueprint string when practical.
- A screenshot or exact error message when relevant.

For rail or stacker problems, screenshots showing the attempted placement are especially useful.

## Code guidelines

- Keep generator responsibilities separated between normal stations, fluid stations, stackers, and shared helpers.
- Prefer runtime prototype checks over hard-coded assumptions when supporting modded entities.
- Keep persistent settings migration-friendly by adding defaults rather than resetting player state.
- Validate user-selected prototypes before generating a blueprint.
- Run Lua syntax checks and package the mod before considering a change complete.

## Credits and upstream work

Railwright is an independent modern implementation inspired by BurnySc2's original Train Station Blueprint Creator and the later web generator. When porting or adapting non-trivial logic from another project, keep attribution clear and preserve any applicable license requirements.
