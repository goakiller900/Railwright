# Releasing Railwright

Railwright releases are intentionally driven from `main`.

## Before merging a release

1. Test the branch build from GitHub Actions in Factorio 2.1.
2. Update `version` in `info.json`.
3. Add a matching top entry to `changelog.txt`.
4. Confirm the changelog describes all important player-visible changes.
5. Merge the tested branch into `main`.

## What happens after the merge

The `Build Railwright Mod` workflow will:

1. Validate all Lua files.
2. Build `railwright_<version>.zip`.
3. Generate GitHub release notes from the matching `changelog.txt` entry.
4. Verify the ZIP structure and bundled changelog.
5. Upload the ZIP as a workflow artifact.
6. Create `v<version>` from the current `main` commit when that tag does not exist.
7. Create or update the GitHub Release and attach the ZIP.
8. Upload the same ZIP to the Factorio Mod Portal when that version is not already published there.

## Safety rules

- Feature branches never publish releases.
- Existing version tags are never moved or overwritten.
- A version already published on the Mod Portal is not uploaded again.
- A version bump without a matching changelog entry fails before publication.
- The repository secret used for Mod Portal uploads is `FACTORIO_API_KEY`.

## Versioning

Use semantic versions in `info.json`:

- Patch: bug fixes and small compatibility fixes, for example `0.2.2`.
- Minor: new features that remain broadly compatible, for example `0.3.0`.
- Major: reserved for a future stable release with significant compatibility expectations.
