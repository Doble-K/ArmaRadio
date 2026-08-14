# Live Radio (Arma 3)

A positional FM radio mod for Arma 3. Radio stations are streamed over the internet and played through an OpenAL extension (`live_radio.dll` / `live_radio_x64.dll`) so the audio is fully positional — it gets quieter and changes direction as you move around the vehicle or the static radio.

This repository is a working fork of [BrettMayson/ArmaRadio](https://github.com/BrettMayson/ArmaRadio) (v0.9.1) with the feature set and fixes tracked in [`roadmap.md`](roadmap.md).

## Features

- Live internet radio streams (ICY metadata / Shoutcast-style MP3) decoded inside the extension.
- Fully positional 3D audio via OpenAL: distance attenuation, Doppler, listener orientation driven by the player (or Zeus curator camera).
- In-game interface (list of stations, search, power toggle, volume bar) and stream status indicator (ONLINE/OFFLINE).
- Per-vehicle volume stored on the object (persisted on the network variable) and restored when a mission starts.
- CBA settings:
  - Volume Multiplier (default 30%)
  - Streamer Mode (mute everything)
  - Sound Range (m)
  - Auto Off Range / Auto Off Time (idle radios power down)
  - Driver and Commander Only (default ON)
  - Configurable vehicle categories (Cars, Armored, Helicopters, Planes, Ships) + custom classes
- ACE integration: self-interaction quick controls (power, volume up/down, next/prev station), actions on static radios (`Land_FMradio_F`), Zeus module and Zeus actions, and hearing attenuation (earplugs/deafness).
- Fallback player actions when ACE is not loaded.
- Interference: vehicle damage, rain, and recent explosions degrade the audio (static/distortion).
- Short static click when powering a radio on or off.
- Multilanguage strings (English / Spanish) via stringtables.

## Requirements

- Arma 3 (2.04+)
- [CBA](https://steamcommunity.com/sharedfiles/filedetails/?id=450814997)
- [ACE](https://steamcommunity.com/sharedfiles/filedetails/?id=463939057) — optional; quick actions, Zeus and hearing integration are skipped when it is not loaded
- [HEMTT](https://hemtt.dev/) — to build the SQF addons (PBOs)
- Rust toolchain (stable) with the `i686` and `x86_64` MSVC targets — to build the extension DLLs
- OpenAL32.dll (bundled in `resources/`; extracted automatically next to the extension at runtime)

## Building

### 1. Extension (Rust)

```bash
# 64-bit DLL (required)
rustup target add x86_64-pc-windows-msvc
cargo build --release --target x86_64-pc-windows-msvc

# 32-bit DLL (optional; Arma 3 no longer supports 32-bit)
rustup target add i686-pc-windows-msvc
cargo build --release --target i686-pc-windows-msvc
```

Note: cross-compiling from Linux requires the Windows MSVC linker to be configured (see the CI workflow `.github/workflows/arma.yaml`, which builds on `windows-latest`). Copy the produced DLLs into the project root as `live_radio.dll` / `live_radio_x64.dll` (the `.hemtt/project.toml` includes both in the release package).

### 2. Addons (SQF, HEMTT)

```bash
hemtt dev    # builds PBOs into .hemttout/build (for launching)
hemtt release # builds releases/live_radio-latest.zip (requires the DLLs in project root)
hemtt launch # builds and launches Arma with CBA + ACE
```

### 3. Testing

```bash
cargo test        # unit tests (ICY metadata parsing, stream lifecycle, extension smoke test)
cargo clippy      # lints
hemtt check       # validates configs and SQF
```

The GitHub Actions workflow (`arma.yaml`) builds both DLLs on Windows, packs them with HEMTT, and uploads a ready-to-install zip.

## Repository layout

```
.
├── Cargo.toml                  # Rust crate: live_radio (cdylib)
├── src/                        # The Rust extension
│   ├── lib.rs                  # arma-rs init, heartbeat, click, smoke test
│   ├── audio.rs                # OpenAL device bootstrap (embeds OpenAL32.dll)
│   ├── listener.rs             # Listener position/orientation (listener:dir)
│   ├── source.rs               # Sound sources, commands, global gain, quality/static
│   ├── streams/mod.rs          # Stream registry, reconnect, fan-out to listeners
│   ├── streams/read.rs         # Remote stream reader + ICY metadata parser
│   ├── vector3.rs              # Position/velocity helper
│   └── logger.rs               # Rust log -> Arma callback bridge
├── resources/                  # Embedded assets (OpenAL32.dll)
├── addons/
│   ├── main/                   # Prefix/module headers and macros
│   ├── manager/                # Source lifecycle, volume, gain, tick, heartbeat
│   └── interface/              # UI, CBA settings, ACE/Zeus actions, functions
├── include/                    # HEMTT includes (Arma & CBA headers)
├── .hemtt/project.toml         # HEMTT project config
├── .github/workflows/          # CI (build + package) and release (GitHub + Workshop)
├── mod.cpp                     # Mod name / dir (@live_radio)
├── roadmap.md                  # Improvement plan and status (P0–P3)
└── BLOQUEADOS.md               # Tracked blocked items and decisions required
```

## Architecture overview

SQF on the Arma side drives the extension over `callExtension`; the extension streams, decodes and plays audio through its own OpenAL context, and pushes metadata/status back to the game via `ExtensionCallback`.

```
        Arma 3 (SQF)                        live_radio.dll (Rust)
  ┌───────────────────────┐          ┌───────────────────────────────┐
  │ CBA settings          │  cmds    │ listener:dir                  │
  │ fnc_play/stop/volume  │ ───────> │ source:new/pos/gain/quality/  │
  │ fnc_tick (per frame)  │          │   global_gain/exists          │
  │ heartbeat             │          │ id / click / heartbeat        │
  └───────────┬───────────┘          └──────────────┬────────────────┘
              │                                     │
              │  ExtensionCallback                   │ Streams (reqwest+simplemad)
              │  title / status / live_radio_log     │ -> sources (alto/OpenAL)
              └──────────────────────────────────────┘
```

See [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) for the full command protocol, module breakdown and event flow.

## Roadmap and status

- [roadmap.md](roadmap.md) — prioritized plan (P0 quick wins → P3 far-future) with checkboxes for what is done.
- [BLOQUEADOS.md](BLOQUEADOS.md) — items that were intentionally left unfinished, why, and what is needed to unblock them.
- [docs/WORKFLOW.md](docs/WORKFLOW.md) — the reproducible workflow used to plan, implement, verify and track this feature set (36 commits), including the full commit log.

## License / attribution

Original project by BrettMayson (MIT). Contributions from mharis001 (interface overhaul, metadata) and matidp4 (several improvements implemented in this fork).
