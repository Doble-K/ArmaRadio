# Changelog

All notable changes to this fork are documented in this file.

This repository is a working fork of [BrettMayson/ArmaRadio](https://github.com/BrettMayson/ArmaRadio),
based on upstream **v0.9.1**. The fork's original contributions are
licensed GPL-3.0-or-later (see [LICENSE](LICENSE)).

## [STANDBY]

Status: **STANDBY — congelado hasta nuevo aviso.** Upstream cambió a una
licencia restrictiva; no se incorporarán más cambios de upstream bajo esa
licencia y el fork queda congelado a partir de esta entrada.

## [Unreleased]

### Added

- Optional interference diagnostics with detected tower classes, distances and
  current channel factors.
- Explicit default tower class coverage for the vanilla communication-tower
  variants.
- First handheld FM prototype for TFAR SW radios through ACE self actions. The
  personal source is local to its owner and does not read TFAR frequencies,
  channels, PTT or power.

### Changed

- Keep personal and vehicle FM radio actions available from ACE self-interaction
  while the player is inside a vehicle; the two interfaces now resolve their
  respective player and vehicle targets independently.
- Refactored the client stream pool so OpenAL source lifetime and shared HTTP
  stream lifetime are tracked separately, with a 30-second idle grace period.
- `source:exists` now checks whether the local source worker is alive before SQF
  decides to recreate it.
- Grouped CBA settings by audio, interference, tower interference, behavior and
  debug categories.
- Hardened custom station validation for names, HTTP(S) URLs and duplicate URLs.
- Release packaging is 64-bit only (`live_radio_x64.dll`), matching current
  Arma 3 support.

### Removed

- Removed the unsupported explosion object-handler scheduler. The Explosion
  Interference setting remains visible, but the current runtime contribution is
  zero until a supported event source is implemented.

### Documentation

- Define the current product as positional Internet radio rather than real FM.
- Document the exact scope of Crows-EW, TFAR and Antistasi compatibility inputs.
- Separate current runtime behavior from historical and future roadmap work.
- Document the relationship with upstream and the policy for selectively porting
  generic upstream improvements.

## [1.2.0] - 2026-09-24

Local interference processing is now available for radio streams.

### Added

- Preloaded and decoded local interference resources with shared caching.
- Per-source local mixing with independent quality and cone channels.
- Gradual streaming filters, configurable fade-out and slow modulation.
- Configurable cone settings, independent interference toggles and tower factors.
- Local explosion interference peaks with distance and intensity falloff.
- English and Spanish settings for the new interference controls.

### Changed

- General interference is sent through the local `source:interference` command.

### Known limitations at release

- The explosion-peak implementation depended on object handlers that were not
  viable for generic nearby explosions. It was removed after the release; the
  feature is currently inactive.
- ACE controls, repair, crew permissions and combined ZEN controls still require
  full manual in-game QA.
- Handheld/backpack radios, per-profile volume and Antistasi garage/repair
  integration were not included. They remain tracked in `roadmap.md` and
  `docs/STATUS.md`.

## [1.1.0] - 2026-09-23

Maintenance and polish release on top of the 1.0.0 fork features.

### Added

- **Custom stations parsing hardening** — `customStations` Addon Options values
  now work whether returned as a serialized string, an array, or text with
  surrounding whitespace.
- Enhanced launcher metadata and updated launcher logos.
- Polished Workshop description.

### Changed

- Modernized the GitHub Actions toolchain (build and release workflows).
- Cleaned HEMTT SQF notices (`isEqualTo`/`isNotEqualTo` style cleanup).
- Documented roadmap continuation items (Advanced ACE Repair, multi-backend
  repair plan, handheld routing and radio profiles).

## [1.0.0] - 2026-08-14

First fork release. Everything below is relative to upstream **v0.9.1**.

### Added

- **CBA settings:**
  - Volume Multiplier (slider, default 30%).
  - Streamer Mode (mutes all radio sources, including new ones).
  - Sound Range (m) — sources outside the range are muted (0 disables).
  - Auto Off Range / Auto Off Time for idle radios (30 m / 120 s defaults).
  - Driver and Commander Only (default ON).
  - All Gunners Can Control Radio (main gunner, Tank/Helicopter/Plane only).
  - Configurable vehicle compatibility: enable per category (Cars, Armored,
    Helicopters, Planes, Ships) plus custom vehicle classes.
  - Custom radio stations (`customStations`, SQF array of `[name, url]`) as the
    primary station source, deduplicated by URL, combined with
    `CfgRadioStations` from config/campaign/mission; the default stations are
    kept as fallback.
  - Generic radio-tower interference: object classnames, radius, strength and
    an optional enemy-side filter that can read `A3A_side`.
  - Crows-EW / TFAR radio jammer interference.
  - Burned radio: engine damage threshold (`radioMotorDamageThreshold`) and
    underwater burn time (`underwaterBurnTime`).
  - Play Click Sound on power on/off.
  - EN/ES tooltips for every setting in Addon Options.
- **Stream status indicator** (ONLINE/OFFLINE) in the radio panel.
- **English/Spanish localization** (stringtables) for the interface and actions.
- **ACE integration:** quick self-interaction controls (power, volume, next/prev
  station), a "Set Radio Volume" submenu with fixed percentages (0/25/50/100%),
  an external "Repair Radio" action usable from outside the vehicle, Zeus
  actions, and vanilla fallback player actions when ACE is not loaded.
- **Zeus and ZEN (Zeus Enhanced) integration:** Zeus module to toggle radio
  power, ZEN custom modules, right-click context menu, dialogs and a combined
  power/station/volume module.
- **Burned radio state:** progressive static from engine damage/submersion, the
  radio burns out and stops working until repaired by an engineer with a
  toolkit (repair delay, saved station restored).
- **Interference:** from vehicle damage, rain, the initial explosion path, radio
  towers and radio jammers, with gradual transitions. The explosion path was
  subsequently replaced and then removed; it is inactive in current code.
- **ACE hearing integration:** earplugs/deafness volume factors scale the
  radio's global gain.
- **Extension (Rust):** `source:quality` interference command and online/offline
  status callbacks (with a `reported` flag so streams that die before sending
  data still report offline).
- **Hardened ICY metadata reading** with unit tests.
- **Project documentation:** README, architecture, workflow, roadmap, blocked
  items tracker and this changelog.
- **Launcher metadata** and unified mod name "Live Radio".

### Changed

- Default volume multiplier from 50% to 30%.
- "Driver and Commander Only" default from OFF to ON.
- Burn trigger from overall vehicle damage to **engine (HitEngine) damage** via
  the configurable `radioMotorDamageThreshold` (default 0.8), replacing
  `radioBurnDamage`.
- ACE volume control from incremental steps to a **fixed percentage submenu**;
  incremental steps remain only for hotkey-style use (Zeus/ZEN).
- Passengers can control the radio when the vehicle has **no commander seat**
  (first two cargo seats); an empty commander seat stays driver-only.
- Station list is now configurable (`customStations`) with the defaults kept as
  fallback instead of being the immutable source.
- Stream status repositioned beside the power button.

### Fixed

- ACE quick volume/station actions not working (config macro argument bug).
- Explosion interference using an invalid mission event handler
  (`Unknown enum value: Explosion`), replaced with object event handlers.
- Sound range not applied on volume changes; a zero range now disables the
  limit instead of muting everything.
- `isCompatible` return value and defensive parsing/guard cases.
- Sources lost to the heartbeat watchdog cleanup; active radios re-created on
  mission start (including a typo fix).
- Power toggle crash when no stations are configured.
- Race condition that could open two streams when switching stations quickly
  (atomic check-and-insert).
- Audio segment repeating in a loop (decoder desync) — resolved by reverting
  the decoder to upstream v0.9.1.
- ZEN set-station dialog now looks up the selected station by name.
- Lint/type warnings (config macro args, stringtable sorting, `getFriend` type).

### Removed

- **Decoder enhancements reverted** to upstream v0.9.1 to eliminate the audio
  loop: stream auto-reconnect, continuous offline static, 4 s static pre-roll
  and fast underrun recovery. Re-implementation is documented as pending in the
  roadmap.

### Known limitation

- Auto power-off shipped with 30 m / 120 s defaults despite an unresolved
  spontaneous-shutdown report in hosted play. Setting either value to `0`
  disables the handler.

## Contributors

- **BrettMayson** — original project author and upstream maintainer.
- **mharis001** — interface overhaul and stream metadata (upstream).
- **matidp4** (Matías Di Palma) — driver/commander-only restriction and several
  improvements incorporated into this fork.
- **Doble-K** — fork author and maintainer: feature set, fixes, CBA settings,
  ACE/Zeus/ZEN integration, licensing and documentation in this fork.

## License

Fork contributions by Doble-K: **GPL-3.0-or-later** (see `LICENSE`).
