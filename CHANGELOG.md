# Changelog

All notable changes to this fork are documented in this file.

This repository is a working fork of [BrettMayson/ArmaRadio](https://github.com/BrettMayson/ArmaRadio),
based on upstream **v0.9.1** (MIT). The fork's original contributions are
licensed GPL-3.0 (see [LICENSE](LICENSE) and [LICENSE-MIT](LICENSE-MIT)).

## [Unreleased]

### Pending
- Verify in-game: ACE quick controls, repair, gunner and passenger control, the
  combined ZEN module and the settings tooltips (manual QA).
- Decide on the `ClassicRock109` default station (replace, remove or keep).
- Diagnose the spontaneous power-off bug before re-enabling auto power-off.
- Handheld and backpack radios; persistent per-profile volume; Antistasi
  heal/garage integration for burned radios.

## [1.0.0] - 2026-08-14

First fork release. Everything below is relative to upstream **v0.9.1**.

### Added

- **CBA settings:**
  - Volume Multiplier (slider, default 30%).
  - Streamer Mode (mutes all radio sources, including new ones).
  - Sound Range (m) — sources outside the range are muted (0 disables).
  - Auto Off Range / Auto Off Time for idle radios (disabled by default pending
    a spontaneous power-off bug).
  - Driver and Commander Only (default ON).
  - All Gunners Can Control Radio (main gunner, Tank/Helicopter/Plane only).
  - Configurable vehicle compatibility: enable per category (Cars, Armored,
    Helicopters, Planes, Ships) plus custom vehicle classes.
  - Custom radio stations (`customStations`, SQF array of `[name, url]`) as the
    primary station source, deduplicated by URL, combined with
    `CfgRadioStations` from config/campaign/mission; the default stations are
    kept as fallback.
  - Radio tower interference (TFAR/Antistasi): tower classnames, radius,
    strength and optional enemy-side filter.
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
- **Interference:** from vehicle damage, rain, recent explosions, radio towers
  and radio jammers, with gradual (faded) transitions instead of hard cuts.
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

- **Auto power-off** disabled by default (settings default to 0) pending
  diagnosis of the spontaneous power-off bug.
- **Decoder enhancements reverted** to upstream v0.9.1 to eliminate the audio
  loop: stream auto-reconnect, continuous offline static, 4 s static pre-roll
  and fast underrun recovery. Re-implementation is documented as pending in the
  roadmap.

## Contributors

- **BrettMayson** — original project author and upstream maintainer.
- **mharis001** — interface overhaul and stream metadata (upstream).
- **matidp4** (Matías Di Palma) — driver/commander-only restriction and several
  improvements incorporated into this fork.
- **Doble-K** — fork author and maintainer: feature set, fixes, CBA settings,
  ACE/Zeus/ZEN integration, licensing and documentation in this fork.

## License

- Upstream code (BrettMayson/ArmaRadio): **MIT** (see `LICENSE-MIT`).
- Fork contributions by Doble-K: **GPL-3.0-or-later** (see `LICENSE`).

The combined work is distributed under GPL-3.0, with the upstream MIT portions
keeping their license and copyright notices.
