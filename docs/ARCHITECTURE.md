# Architecture

This document describes how the Live Radio mod works end to end: the Rust extension, the SQF addons, the command protocol between them, and the runtime data model.

## High-level data flow

```
Arma 3 (SQF)                        live_radio.dll (Rust)
─────────────────────────            ─────────────────────────────────────────
XEH_preInit                          Extension loads once (EXT callExtension "")
XEH_preStart                          -> "start" call (unregistered command, harmless)
XEH_postInit                          -> listener:dir every frame (fnc_tick)
                                       -> source:new on radio power on
                                       -> source:pos / source:gain / source:quality
                                       -> source:exists (liveness check)
                                       -> heartbeat (0.75 s)
                                       -> source:global_gain on settings change
                                       -> id (generates a per-radio id)
                                       -> click (power on/off static sound)
                                       <- callbacks: title, status, live_radio_log
```

The SQF layer is a thin state machine. It decides *what* to play and *where* it is; the extension decides *how* to play it (streaming, decoding, 3D positioning, effects).

## Rust extension (`src/`)

Crate: `live_radio` (`crate-type = ["cdylib"]`), built with `arma-rs` 1.x. The extension exposes command *groups* (`listener`, `source`) plus top-level commands (`id`, `heartbeat`, `click`).

### `lib.rs`
- `#[arma] pub fn init() -> Extension` — builds the extension:
  - `listener::group()` and `source::group()` (namespaced commands).
  - top-level commands `id`, `heartbeat`, `click`.
  - initializes the Rust logger bridged to Arma (`logger::init`).
- Spawns a watchdog thread: if more than 3 s pass without a heartbeat, calls `source::cleanup()` (frees all sources/streams). The SQF side sends a heartbeat every 0.75 s and re-creates dead sources (`source:exists` + `source:new` in `fnc_tick`).
- `command_id()` — random 8-char lowercase alphanumeric id used as the key that SQF and the extension share for each radio.
- `command_click()` — plays a short random static click (used by power on/off).
- Integration smoke test `radio1` exercises the full extension lifecycle headless.

### `audio.rs`
- Singleton `Audio::get() -> Option<Arc<Alto>>`.
- On first use it ensures `OpenAL32.dll` exists next to the extension; if not, it extracts the embedded copy from `resources/` (via `rust_embed`) and writes it to disk. Then loads the default OpenAL device.

### `listener.rs`
- Singleton `Listener::get() -> Option<Arc<Context>>` — lazily opens the OpenAL device/context, sets the listener at origin with identity orientation, `meters_per_unit = 1.0`, `DistanceModel::Exponent`, `doppler_factor = 0.2`.
- `listener:dir dx dy dz ux uy uz` — sets the listener orientation each frame from the player (or the Zeus curator camera).

### `source.rs`
- `Sources` registry: `HashMap<String, Mutex<SoundSource>>` guarded by `RwLock` (singleton).
- `SoundSource::new(ctx, id, url, gain)` spawns a thread that:
  1. Calls `Streams::listen(url)` to obtain a `StreamListener`.
  2. Creates an OpenAL streaming source, applies soft spatialization and the *effective* gain (`specific_gain × global_gain`).
  3. Runs a command loop over a private `mpsc` channel:
     - `SetPos` (position + computed velocity), `SetGain`, `SetQuality`, `RefreshGain`, `Destroy`.
  4. Drains `StreamPacket`s from the stream receiver:
     - `Data(samples, freq)` — converts to mono, applies quality (damage/interference) by mixing in random static and attenuating amplitude, marks the source online (fires `status=online` callback once), reuses buffers when `buffers_processed() > 200`, queues and plays.
     - `Title(title)` — fires the `title` callback.
  5. If the receiver is `Empty` and the stream is no longer `active`, marks the source offline once (`status=offline`), flushes queued buffers and continuously feeds a low-volume white-noise buffer so the radio emits static instead of going silent (until new data or a `Close`/disconnect arrives).
- Commands:
  - `source:new id url gain` — register a new source (insert into map).
  - `source:destroy id` — remove from map (drops the `SoundSource`, which sends `Destroy`).
  - `source:pos id x y z` — relative position (SQF sends player-relative offsets; the extension also computes velocity for Doppler).
  - `source:gain id gain` — per-source gain.
  - `source:quality id quality` — quality in `[0, 1]`; `0` = clean, `1` = pure static.
  - `source:exists id` — `"1"`/`"0"` liveness probe.
  - `source:global_gain gain` — global gain `[0, 1]` (volume multiplier × ACE hearing × streamer mode). Stored as an `AtomicU8` (`0..255`) in the group state; on change it forces every source to `RefreshGain`.
- `cleanup()` — clears the whole map (watchdog).

### `streams/mod.rs`
- `Streams` registry: `HashMap<String, Stream>` (one decoder per unique URL, shared/fan-out across radio sources).
- `Stream` holds:
  - `count: Arc<AtomicU8>` — number of active listeners; the decoder thread shuts down at 0.
  - `senders: Senders` — broadcast list of `Sender<StreamPacket>`.
  - `active: Arc<AtomicBool>` — true while a decoder is producing frames.
  - `generation: Arc<AtomicUsize>` — bumped on every (re)start so a stale decoder supersedes itself.
- `Streams::listen(url)` — get-or-create:
  - If the URL exists: `count.fetch_add(1)`; if it was 0 the stream is restarted; a new sender is pushed.
  - Otherwise: create a `Stream` (count 1), start it, insert.
  - The atomic check-and-insert under the map write lock removes the race where two radios could start the same URL twice.
- `Stream::start(url)` — spawns a decoder thread that loops:
  - Connect via `RemoteStream::new`; on failure retry every 2 s while `count > 0` and generation is current.
  - Decode MP3 with `simplemad`; convert stereo frames to mono (`alto::Mono<f32>`).
  - Broadcast `Data` frames to all senders; prune dead senders.
  - When the decoder ends (EOF/connection drop): `active=false`, reconnect after 2 s if still needed.
  - `generation` check prevents two decoder loops from running for the same URL after a restart.
- `StreamListener` — the per-source endpoint: owns the `Receiver<StreamPacket>` and shared `count`/`active`; on drop it decrements the count and prunes the sender.

### `streams/read.rs`
- `RemoteStream` implements `std::io::Read` over the `reqwest::blocking` HTTP response.
- Sends `Icy-MetaData: 1` and reads the `icy-metaint` header; if present, splits the byte stream into audio data + ICY metadata blocks.
- `read_metadata()` reads a 1-byte length, multiplies by 16, reads the metadata block, and regex-extracts `StreamTitle='...';` entries, broadcasting a `Title` packet to all senders.
- The `Read` implementation is hardened: it always consumes exactly `interval` bytes before reading a metadata block (no recursion on short reads, no infinite `read==0` loop).
- Unit tests cover the ICY regex: single/multiple titles, missing title, and null-padded blocks.

### `logger.rs`
- Bridges the `log` crate into Arma: every record (up to `Debug`) is forwarded as callback `live_radio_log` and also printed to stdout.

### `vector3.rs`
- `Vector3` with `update(x, y, z, dt) -> velocity` used to compute Doppler velocity from consecutive positions.

## SQF addons (`addons/`)

HEMTT component layout. Prefix: `live_radio` (`z\live_radio`). Addon components: `main`, `manager`, `interface`.

### `main`
- Headers only: `script_mod.hpp` (prefix, version, `EXT` macro = `"live_radio"`), `script_macros.hpp` (CBA common macros + `PREP`), `script_version.hpp`, `config.cpp` (`CfgPatches` requiring `cba_settings`), `stringtable.xml`.

### `manager` — audio lifecycle, server-side, gain
- `XEH_preInit.sqf`: initializes `GVAR(sources)` / `GVAR(sourcesTitles)` / `GVAR(sourcesStatus)` hash maps, loads the extension once, registers CBA settings:
  - `volumeMultiplier` (slider, default 0.3)
  - `streamerMode` (checkbox, default false)
  - `soundRange` (slider, default 200 m; 0 disables)
  - `autoOffRange` (default 30 m), `autoOffTime` (default 120 s)
- `XEH_postInit.sqf`:
  - Client (`hasInterface`): applies initial gain (`applyGain`), registers per-frame `tick` and `heartbeat` handlers, sets up the ACE-hearing per-frame poll, handles `Explosion` mission events (`GVAR(lastExplosion)`), and re-creates active radios on mission start from each object's `active` variable.
  - Event handlers:
    - `QGVAR(start)`: `source:new` + record into `GVAR(sources)`, fire `metadataUpdated`.
    - `QGVAR(stop)`: `source:destroy` + remove from hash maps.
    - `QGVAR(volume)`: `source:gain` (respects out-of-range mute).
  - Server (`isServer`): auto-power-off per-frame loop — for each radio with an active stream, if no player is within `autoOffRange` for `autoOffTime`, calls `FUNC(play)` with `""` (turns it off for everyone).
  - `ExtensionCallback` handler dispatches `live_radio` callbacks: `title` → `GVAR(sourcesTitles)`; `status` → `GVAR(sourcesStatus)`; both fire `metadataUpdated`.
- Functions:
  - `fnc_play.sqf` — power on/off for an object. If the object already plays the same URL and it is online, keeps it; otherwise stops the previous stream and starts the new one. Generates the id, stores `active = [id, url]` on the object (networked), and fires the global `start`/`stop` events.
  - `fnc_volume.sqf` — sets `QGVAR(volume)` on the object (networked) and fires the global `volume` event.
  - `fnc_tick.sqf` — per-frame on each client:
    1. Updates listener orientation from the player (or Zeus camera).
    2. For each active source: skips positional updates when the player rides the radio's vehicle; otherwise computes player-relative position, applies the `soundRange` mute (out-of-range → gain 0), and sends `source:pos`.
    3. Computes interference quality = `damage` + rain storm (`0.2*rain`) + recent explosions, clamps to 1, sends `source:quality` only when it changes.
    4. Liveness check every 2 s: if `source:exists` returns `"0"`, re-creates the source (`source:new`).
  - `fnc_applyGain.sqf` — computes effective global gain: `volumeMultiplier`, forced to 0 in streamer mode, multiplied by ACE hearing factors (`ace_hearing_volume` × `ace_hearing_volumeAttenuation`) when ACE is present; sends `source:global_gain`.
  - `fnc_heartbeat.sqf` — sends `heartbeat`.
  - `fnc_applyGain` is also invoked by the settings `onChange` handlers and by the ACE-hearing poll.

### `interface` — UI, settings, actions
- `XEH_preInit.sqf`: gathers stations from `configFile`/`campaignConfigFile`/`missionConfigFile` `CfgRadioStations` (`name`, `picture`, `url`), sorts them; registers CBA settings: `driverAndCommanderOnly` (default true), `enableCars` (true), `enableArmored`, `enableHelicopters`, `enablePlanes`, `enableShips` (false), `customVehicleClasses` (edit box, JSON-like array string).
- `XEH_postInit.sqf`: if ACE is not loaded, registers fallback player actions for static radios and vehicles (open, power, volume up/down, next/prev station). Subscribes to manager events (`start`/`stop`/`volume`/`metadataUpdated`) to refresh an open display.
- `CfgVehicles.hpp`: adds `ACE_SelfActions` to `Car`, `Tank`, `Helicopter`, `Plane`, `Ship` (filtered by `isCompatible` + `canOpen`); `ACE_Actions` for `Land_FMradio_F`; defines the Zeus module `ModuleToggleRadio`.
- `CfgZeusActions.hpp`: root-level `ACE_ZeusActions` submenu to toggle radio power on compatible units.
- `gui.hpp`: the in-game dialog (list, search bar/button, picture, name, description, ONLINE/OFFLINE status, power button, volume icon + bar, OK).
- Functions:
  - `fnc_open.sqf` — creates the dialog, wires control handlers, initializes list, power and volume state.
  - `fnc_isCompatible.sqf` — returns true for `Land_FMradio_F`, any category whose CBA setting is on, or any `isKindOf` a custom class. (Custom classes parsed defensively; unparseable strings fall back to empty.)
  - `fnc_canOpen.sqf` — `driverAndCommanderOnly` gate (player must be driver or commander).
  - `fnc_power.sqf` — toggles power on an object; remembers the last station; plays a click.
  - `fnc_volumeChange.sqf` — steps volume by ±0.1, clamped to `MIN_VOLUME`/`MAX_VOLUME` (0–2).
  - `fnc_stationChange.sqf` — cycles previous/next station only while powered on.
  - `fnc_refresh.sqf` — re-syncs an open display to the object's real state (power, volume, info).
  - `fnc_moduleToggleRadio.sqf` — Zeus module: toggles power of the attached object, then deletes the logic.
  - UI handlers (`handlePower`, `handleVolume`, `handleListSelect`, `handleSearch*`, `handleVolumeMouse`/`ButtonUp`/`ButtonDown`) and `updateList`/`updateInfo`.

## Command protocol reference

All commands go through `EXT callExtension [command, args]` where `EXT` is `"live_radio"`. Array args are serialized; results come back as an array (`[return_value, code]`).

| Command | Arguments | Purpose |
| --- | --- | --- |
| `""` (empty) | — | Load the extension (no-op warm-up) |
| `id` | — | Returns a fresh 8-char lowercase id for a radio |
| `heartbeat` | — | Keeps the watchdog alive (0.75 s cadence) |
| `click` | — | Plays a short static click (power on/off) |
| `listener:dir` | `dx dy dz ux uy uz` | Set listener orientation from player/Zeus camera |
| `source:new` | `id url gain` | Register + start a positional source |
| `source:destroy` | `id` | Stop and remove a source |
| `source:pos` | `id x y z` | Set relative position (velocity derived for Doppler) |
| `source:gain` | `id gain` | Set per-source gain |
| `source:quality` | `id quality` | Set interference `[0,1]` (0 clean, 1 static) |
| `source:exists` | `id` | Liveness check → `"1"`/`"0"` |
| `source:global_gain` | `gain` | Global gain `[0,1]` across all sources |

## Extension callbacks (SQF → `addMissionEventHandler ["ExtensionCallback", ...]`)

| Name | Function | Data |
| --- | --- | --- |
| `live_radio` | `title` | `[id, "Artist - Song"]` — current stream title |
| `live_radio` | `status` | `[id, "online"` or `"offline"]` — stream availability |
| `live_radio_log` | `record.target()` | `[LEVEL, message]` — Rust log output |

## Runtime data model (SQF)

| Key | Scope | Meaning |
| --- | --- | --- |
| `GVAR(sources)` | client | `HashMap<id, object>` active radios |
| `GVAR(sourcesTitles)` | client | `HashMap<id, title>` last title per radio |
| `GVAR(sourcesStatus)` | client | `HashMap<id, "online"/"offline">` status per radio |
| `QGVAR(active)` | object (networked) | `[id, url]` what the radio plays (or `[]`) |
| `QGVAR(volume)` | object (networked) | per-object volume (default 1, range 0–2) |
| `QGVAR(quality)` | object (local cache) | last interference factor sent to the extension |
| `QGVAR(outOfRange)` | object (local cache) | whether the source is muted by `soundRange` |
| `GVAR(lastExplosion)` | client | time of the most recent explosion |
| `GVAR(hearingFactor)` | client | cached ACE hearing factor (to avoid re-applying every frame) |

`manager` runs on all machines (client-driven sources) and the server (auto-power-off). `interface` runs wherever players interact with radios and where the Zeus curator is.
