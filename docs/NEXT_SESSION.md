# Next Session Handoff

## Current Git State

- Checked-out branch: `test/baseline`
- `test/baseline`: commit `1285146`, roadmap notes for handheld routing and JSON radio profiles.
- `test/custom-stations-parser`: commit `5aa3975`, unvalidated robustness change for `customStations` parsing.
- `main`: commit `134ea55`, includes the current version bump to 1.1.0.
- `fork/main`: still points to `d569b9e`; local branches have not been pushed after that point.
- The roadmap commit `1285146` was created on `test/baseline`; cherry-pick it onto `main` when the branch is ready.

## Recent Commits

- `154b9d3` updates `logo_ca.paa` and `logo_over_ca.paa` using `nueva.png` and `nueva2.png`.
- `62a0583` adds the corrected Steam Workshop description in `WORKSHOP_DESCRIPTION.md`.
- `5aa3975` hardens `customStations` parsing. It passed `hemtt check` but was not tested in-game; the reported streaming problem was caused by an incorrect system link.
- `1285146` documents handheld routing inside vehicles and the future `radio_profile.json` source of truth.

## Launcher Assets

- `logo_ca.paa`: normal launcher icon, generated from `nueva.png`.
- `logo_over_ca.paa`: hover launcher icon, generated from `nueva2.png`.
- `picture_ca.paa`: Workshop/large picture, intentionally unchanged.

## Untracked User Assets

Do not delete without confirmation:

- `nueva.png`
- `nueva2.png`
- `resources/Interferencia radio 1.mp3`
- `resources/interferencia de Radio 2.mp3`
- `resources/interferencia de Radio 3.mp3`

## Next Work

1. Test the known-good baseline with the system link correctly configured.
2. Test `5aa3975` separately before including it in a Workshop release.
3. Cherry-pick the roadmap handoff commit onto `main` when appropriate.
4. Push only the commits intended for the next release.
5. Implement the multi-backend repair core before the ACE/Advanced-ACE-Repair adapter.
6. Later design the handy routing modes and mission/server `radio_profile.json` loader.

## Important Design Decisions

- ACE, vanilla actions and Zeus must share one repair core.
- Advanced-ACE-Repair is an optional reference/integration, not a required dependency.
- TFAR Standalone remains an optional interoperability layer; it must not replace Live Radio's audio backend.
- A mission/server radio profile should become the source of truth when present; `customStations` remains fallback until that behavior is implemented and tested.
