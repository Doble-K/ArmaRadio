# Workflow — How this feature set was planned, implemented and tracked

This document explains the reproducible workflow used to take the mod from upstream
`BrettMayson/ArmaRadio` (v0.9.1) to the current state (36 commits ahead of
`origin/main`, all from the working session of 2026-08-14). It is meant as a
playbook: follow the same phases and rules to extend the mod again (or to re-do
the whole process on a fresh fork) without losing decisions, rationale or track of
what is still blocked.

---

## Phase 0 — Setup

1. Fork/clone the upstream repo.
2. Create a working branch on top of `origin/main`:
   ```bash
   git checkout -b improve main
   ```
3. Verify the toolchain before touching anything:
   ```bash
   cargo test        # extension smoke tests pass
   cargo clippy      # baseline lints
   hemtt dev         # PBOs build
   hemtt check       # configs/SQF validate
   ```
4. Confirm the DLLs (`live_radio.dll` / `live_radio_x64.dll`) are present in the
   project root for `hemtt release`; they are produced by the CI workflow
   (`.github/workflows/arma.yaml`) on Windows runners.

## Phase 1 — Planning (no code)

Write the improvement plan as `roadmap.md`, ordered by **urgency and simplicity**
(P0 = quick wins / urgent → P3 = far future). Rules applied while writing it:

- Items are phrased as generic upstream-friendly improvements; original mod names
  and default radio stations are never changed.
- Every item is a checkbox (`- [ ]`) with concrete acceptance criteria.
- Sub-notes capture decisions (e.g. "the DLL starts at 100%, the slider default is
  never applied on its own"), because they explain *why* a change is needed.
- Open design questions are parked in a dedicated "Dudas / decisiones abiertas"
  section instead of blocking work.
- The plan is kept in Spanish (the working language of the sessions); code and
  user-facing strings remain bilingual ES/EN.

## Phase 2 — Implementation cycle (repeated per feature)

Order: **P0 → P1 → P2 → P3**, and within a feature, **least invasive layer first**
(settings/macros → SQF → Rust) so each change is verifiable on its own.

Per feature the loop is:

1. **Read the current code** for the touched file(s) first — never assume
   structure. Grep for the symbols the feature touches (settings, functions,
   commands).
2. **Make one atomic commit per feature.** Small, descriptive messages in
   imperative mood ("add X", "fix Y", "guard Z"). Do not bundle unrelated changes.
3. **Verify after each commit** where possible:
   - Rust changes: `cargo test` and `cargo clippy`.
   - SQF/config changes: `hemtt check` (catch macro/typo issues early).
4. **Cross-layer features in dependency order** — e.g. the sound-range feature
   was committed as: setting first, then tick/volume behavior, then edge-case
   fixes. Each commit leaves the tree buildable.
5. **Keep the roadmap truthful**: mark items `- [x]` as soon as their code lands.

### Concrete example — P0 "Vehículos compatibles configurables"

Committed in three steps (`4fa9d61` → `0aff38b` → `78ed56c`):

1. Add the CBA settings (cars/armored/helicopters/planes/ships/custom classes).
2. Add `fnc_isCompatible.sqf` evaluating them.
3. Wire the filter into the ACE action condition and the fallback actions.

### Concrete example — P1 "Rango de sonido" (`cd5fd8c`, `83851ce`)

1. Add the `Sound Range` CBA setting + mute sources out of range in `fnc_tick`.
2. Follow-up fix: also respect the range on live volume changes and treat
   `range == 0` as "disabled" (no mute).

## Phase 3 — Integration bug fixing

After the main features landed, a second pass fixed cross-feature bugs found by
re-reading the code (this fork had no in-game test run available, so correctness
was verified by inspection + tests). Typical categories:

- **Lifecycle/ordering**: `8ba35b6` (typo re-initializing active radios on mission
  start), `b4ef506` (clear `active` before firing `stop` so panels show off
  state), `8d1a2bf` (restore sources lost to heartbeat cleanup).
- **Defensive parsing**: `d2391cb` (guard `isCompatible` parse and null display in
  `updateInfo`), `bea112f` (unambiguous `exitWith` return in `isCompatible`).
- **Robustness under edge cases**: `cc16df5` (no stations available → guard power
  toggle), `6988716` (auto-power-off also on hosted servers), `f766b34` (status
  label positioned beside the power button without overlap).
- **Rust concurrency/streaming**: `07f13f5` (static when the stream thread dies +
  hardened ICY metadata reads), `79840fd` (atomic check-and-insert + generation in
  `Streams::listen`), `e5dc47c` (auto-reconnect + keep static while offline),
  `fa5c207` (restart a dead source when replaying the same offline station).
- **Tests to lock behavior**: `90b33bc` added unit tests for ICY metadata parsing
  (single/multiple titles, missing title, null padding) after the parser was
  hardened.

## Phase 4 — Blocked items tracking (`BLOQUEADOS.md`)

Items that were deliberately left unfinished are logged with:
- **What was attempted** (and what *is* done, if partial).
- **Why it stayed blocked** (technical contradiction, undefined scope, missing
  design decision).
- **What is needed to unblock** (concrete next step or open decision).

Examples from the session:

| Item | Why blocked | What unblocks it |
| --- | --- | --- |
| P2.2 optional distance interference | Redundant with OpenAL distance model + hard sound-range cut | Decide whether a soft transition (progressive static) is wanted |
| P3.3 hand radios / backpack radio | Requires redesigning the source system to track carrying units | Define concrete items and scope |
| P3.4 per-vehicle volume persistence | Profile persistence per vehicle class can stomp volumes across equal vehicles | Design decision: persist per class, per unique object, or session-only |
| P2 ACE hearing | Not blocked — completed; note kept with verification details | — |

Tracked items are also re-verified against external sources when relevant (e.g.
the ACE `ACE_ZeusActions` structure was checked against the ACE3/ZEN source before
committing `d0b210f`).

## Rules of the flow (summary)

1. **One feature = one commit**; descriptive imperative messages.
2. **Least invasive layer first** within a feature.
3. **Verify with `cargo test` / `cargo clippy` / `hemtt check`** after touching Rust
   or configs.
4. **Do not touch** default radio stations or the mod's original display names.
5. **Keep strings bilingual** (stringtable ES/EN); sort them.
6. **Keep the roadmap and blocked list current** — they are the single source of
   truth for what remains.
7. When a feature spans layers and has edge cases, expect a small follow-up-fix
   phase; budget for it instead of trying to get everything in one shot.

## Commit log (36 commits over `origin/main`)

Sorted chronologically (oldest first). Category: P0–P3 roadmap items, `fix`
integration/edge-case fixes, `test` unit tests, `docs` tracking.

| Commit | Category | Message |
| --- | --- | --- |
| `24a5bae` | P0 | default volume to 30% |
| `4036fbb` | P0 | driver and commander only defaults to true |
| `74895a7` | P0 | add streamer mode setting to mute all sources |
| `4ea9b3a` | P0 | re-apply global gain on mission start |
| `4fa9d61` | P0 | add configurable vehicle compatibility settings |
| `0aff38b` | P0 | add isCompatible vehicle check function |
| `78ed56c` | P0 | filter radio action by isCompatible for all vehicle categories |
| `ffbb864` | P0 | add stream online/offline status indicator |
| `89434c1` | P0 | localize settings and interface strings (ES/EN) |
| `07f13f5` | P1 | play static when stream thread dies and harden icy metadata reading |
| `79840fd` | P1 | fix race condition in stream listen with atomic check-insert and generation |
| `204e614` | P1 | add quick control ACE actions for power, volume and station |
| `cd5fd8c` | P1 | add configurable sound range to mute sources outside radius |
| `d4fc05e` | P1 | refresh open display on remote start, stop and volume changes |
| `2be49f8` | P2 | add server-side auto power off for idle radios |
| `893675e` | P2 | add damage-based interference via source quality command |
| `8fa5cb6` | fix | fix config macro args, sort stringtables and lint warnings |
| `00c7ed6` | P3 | play short static click when powering radio on or off |
| `6ab99db` | P2 | add environmental interference from rain and nearby explosions |
| `36d79a9` | P3 | add Zeus module and ACE Zeus actions to toggle radio power |
| `0f3a971` | P2 | scale global gain with ACE hearing earplugs and deafness |
| `f295340` | docs | update roadmap status and add blocked items tracking |
| `8ba35b6` | fix | fix typo re-initializing active radios on mission start |
| `cc16df5` | fix | guard power toggle when no stations are available |
| `fa5c207` | fix | restart dead source when replaying the same offline station |
| `6988716` | fix | run auto power off on hosted servers too |
| `b4ef506` | fix | clear active before firing stop so panels show off state |
| `e5dc47c` | P1 | auto-reconnect streams and keep static while offline |
| `8a15625` | fix | add root-level ACE Zeus actions and handle unit targets in power |
| `83851ce` | fix | respect sound range on volume changes and treat zero range as disabled |
| `f766b34` | fix | position stream status beside power button without overlap |
| `d2391cb` | fix | guard isCompatible parse and null display in updateInfo |
| `d0b210f` | docs | update blocked tracking with verified Zeus actions structure |
| `bea112f` | fix | fix isCompatible return with unambiguous exitWith flag |
| `8d1a2bf` | fix | restore sources lost to heartbeat cleanup |
| `90b33bc` | test | add unit tests for icy metadata parsing |

## How to replicate on a fresh fork

```bash
git clone <your-fork> && cd <repo>
git checkout -b improve origin/main
# Phase 1: write roadmap.md (see existing one)
# Phase 2..3: implement in the order above, one commit per feature, verify each
# Phase 4: keep BLOQUEADOS.md current
cargo test && cargo clippy && hemtt check   # before pushing
git push -u origin improve
```

The current `roadmap.md` checkboxes and `BLOQUEADOS.md` entries are the exact
source of truth for what was done and what remains — replicate from them, in the
same P0→P3 order.
