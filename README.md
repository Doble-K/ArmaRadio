# Live Radio: Resynced (Arma 3)

**STATUS: STANDBY — congelado hasta nuevo aviso.**

Live Radio: Resynced is a positional **Internet radio** mod for Arma 3. It
associates HTTP/HTTPS audio streams with vehicles, static radios and other
mission objects, then plays them locally through an OpenAL extension so their
volume and direction change with the listener's position.

This repository is a community fork of
[BrettMayson/ArmaRadio](https://github.com/BrettMayson/ArmaRadio), based on
upstream v0.9.1.

## Terminology and scope

The current implementation is not an RF, FM or AM simulation:

- A station is a display name, an optional picture and an Internet stream URL.
- Changing station changes the URL; there is no radio frequency or band.
- Audio is downloaded independently by every client and is not carried through
  Arma voice chat, TFAR or a game server.
- `FM Radio` remains in parts of the UI and in the Arma classname
  `Land_FMradio_F`. In the current release it is a thematic label, not a real
  FM transmission model.

TFAR and Antistasi are not required and are not complete integrations. The
limited compatibility inputs that currently exist are documented below.

## Current capabilities

### Internet streams and audio

- HTTP and HTTPS MP3 streams decoded by the Rust extension with `simplemad`.
- ICY/Shoutcast metadata (`StreamTitle`) and ONLINE/OFFLINE status callbacks.
- Positional OpenAL audio with distance attenuation, listener orientation and
  Doppler.
- One HTTP decoder per unique URL in each client process, shared by local sound
  sources that use that URL.
- Global volume multiplier, per-object volume, streamer mode and a configurable
  hard sound-range limit.
- Optional power click and local interference mixing with filters, program
  attenuation and slow modulation.

### Stations and controls

- Searchable in-game station list with power, volume and stream status.
- `customStations` CBA setting using `[name, url]` entries.
- `CfgRadioStations` support from addon, campaign and mission config using
  `name`, optional `picture` and `url` fields.
- Catalog validation for non-empty names and HTTP(S) URLs, with URL-based
  deduplication when custom and config stations are combined.
- Vehicles selected by category or custom classname, plus `Land_FMradio_F`.
- Cars enabled by default; armored vehicles, helicopters, planes and ships are
  optional categories.
- Driver, commander, main gunner/co-pilot and secondary-gunner access settings.
- Vanilla/CBA player actions when ACE Interaction is absent.
- ACE controls and repair actions when ACE is present.
- Vanilla Zeus power module plus optional ZEN modules, dialogs and context menu.
- ZEN can attach a station to an arbitrary object and can mark it to remain
  powered while the persistent-radio option is enabled.

### Interference and radio damage

The current signal processing is an audio-effect model, not RF propagation.
Each client computes normalized interference factors and sends them to the
local extension:

- General channel: source-object damage, rain, compatible jammer data and the
  optional burn progression.
- Three independent radial tower profiles, called `cone1`, `cone2` and `cone3`
  internally, based on the listener's distance to configured tower objects.
- Local MP3 interference resources, high-pass/low-pass filtering, stream fade
  and gradual modulation mixed per sound source.
- Optional hard burn from engine damage or submersion, disabled by default.
  A burned radio stays off until repaired by an engineer with a toolkit.

Configured towers currently produce **interference**. They do not broadcast a
station, extend station coverage or act as transmitters.

The Explosion Interference setting is still present, but the current runtime
does not collect explosion events and its factor is always zero. Explosion
peaks remain planned work.

### Network behavior

- The active URL, source ID, volume and relevant radio flags are stored as
  networked variables on the source object.
- CBA global events propagate start, stop and volume changes.
- Joining clients reconstruct local sources by scanning the networked object
  state.
- The server checks idle radios every two seconds. With the current defaults, a
  radio is switched off after no player has been within 30 m for 120 seconds.

The clients do not share an audio clock or stream offset, so two players can
hear slightly different points in the same live stream.

## Integration matrix

| Component | Required | Current behavior |
| --- | --- | --- |
| CBA_A3 | Yes | Settings, XEH lifecycle, events, per-frame handlers and fallback actions. |
| ACE3 | No | Interaction actions, repair checks and hearing attenuation. |
| ZEN | No | Zeus modules, dialogs and context-menu actions. |
| Crows Electronic Warfare | No | Reads `crowsew_main_jamMap` and converts enabled `VoiceCommsJammer` entries into local interference. |
| TFAR | No | If no Crows jam map exists, reads `tf_receivingDistanceMultiplicator` as a generic jammer fallback only. |
| Antistasi | No | Can read `A3A_side` when the optional tower side filter is enabled. No campaign lifecycle integration exists. |

The current code does **not** read TFAR radios, channels or frequencies, and it
does not provide handheld or backpack Internet-radio receivers. Those items are
future work in [`roadmap.md`](roadmap.md) and [`docs/STATUS.md`](docs/STATUS.md).

## Known limitations

- MP3 streams are supported; AAC, OGG, HLS/M3U8 and playlists are not.
- There are no FM/AM bands, RF frequencies, transmitters, terrain propagation,
  line-of-sight reception or channel overlap.
- Handheld, backpack and TFAR-controlled radios are not implemented.
- Antistasi garage, repair, availability, report and coverage logic is not
  implemented.
- The Rust stream worker does not contain a continuous reconnect loop. SQF can
  recreate a desired source after its local worker dies, but playback continuity
  is not guaranteed.
- Per-object state lasts for the mission and supports JIP; it is not persisted
  across missions or in the player's profile.
- `Keep Radio On` prevents an object from being powered off while enabled; it is
  not cross-mission persistence.
- Automatic power-off is enabled by the current 30 m / 120 s defaults despite a
  historical report of spontaneous shutdown in hosted play. Set either value to
  `0` to disable it.
- Explosion interference is currently inactive, as described above.

## Installing

1. Install CBA_A3.
2. Extract the release so the `@live_radio` directory contains the PBOs and
   `live_radio_x64.dll`.
3. Load `@live_radio` on every client that must hear or control radios. Load it
   on the server when using synchronized settings and server-side automatic
   power-off.
4. For a signed dedicated server, install the release key in the server's
   `keys` directory.

`OpenAL32.dll` is embedded in the extension and extracted next to it when
needed. Internet access to every configured station is required on each client.

## Configuring stations

### CBA setting

The `customStations` edit box accepts an SQF simple array. The same text is also
valid JSON for this two-column structure:

```json
[
  ["Classic Rock 109", "http://listen.classicrock109.com:10042"],
  ["My station", "https://example.org/stream.mp3"]
]
```

Entries require a non-empty name and an `http` or `https` URL. Invalid entries
and duplicate URLs are ignored. This is a pasted configuration format: the mod
does not read JSON files from disk and does not require `-filePatching`.

If no valid custom entry remains, the catalog falls back to
`CfgRadioStations`. When custom entries are valid, config entries are added and
deduplicated by URL.

### Mission config

```cpp
class CfgRadioStations {
    class MyStation {
        name = "My station";
        picture = "";
        url = "https://example.org/stream.mp3";
    };
};
```

## Requirements

### Runtime

- Arma 3 2.04 or newer, 64-bit.
- [CBA_A3](https://steamcommunity.com/sharedfiles/filedetails/?id=450814997).
- Internet access on clients.
- ACE3 and ZEN are optional.

### Development

- [HEMTT](https://hemtt.dev/) for PBO builds.
- Stable Rust with the `x86_64-pc-windows-msvc` target for the extension.
- A Windows MSVC linker. The release workflow builds the DLL on Windows.

Arma 3 no longer supports the 32-bit runtime. Release packages contain only
`live_radio_x64.dll`.

## Building and checking

```bash
rustup target add x86_64-pc-windows-msvc
cargo build --release --target x86_64-pc-windows-msvc
```

Place the resulting DLL in the project root as `live_radio_x64.dll`, then run:

```bash
hemtt dev
hemtt check
hemtt release
```

Rust checks:

```bash
cargo test
cargo clippy
```

Some Rust tests exercise a live Internet stream and OpenAL device rather than
being isolated unit tests; they require a suitable runtime environment.

## Repository layout

```text
.
|-- src/                         Rust extension: HTTP, MP3, mixer and OpenAL
|-- addons/main/                 Shared version, macros and CBA dependency
|-- addons/manager/              Runtime state, extension bridge and interference
|-- addons/interface/            Catalog, UI, actions, ACE, Zeus and ZEN
|-- resources/                   Embedded OpenAL and interference audio assets
|-- docs/ARCHITECTURE.md         Current implementation and command protocol
|-- docs/BUILD.md                PBOs, DLL and local build instructions
|-- roadmap.md                   Future work only
|-- docs/STATUS.md               Current status, known issues and decisions
|-- CHANGELOG.md                 Release history
|-- WORKSHOP_DESCRIPTION.md      Steam Workshop copy
|-- docs/archive/                Historical planning and workflow documents
`-- docs/RADIO_BROADCAST_DESIGN.md Future FM/AM design proposal
```

## Architecture overview

```text
Mission/config/CBA catalog
          |
          v
SQF interface -> manager object state -> CBA global events
                                      |
                         each client with an interface
                                      |
                                      v
                         live_radio_x64.dll (Rust)
                         |-- HTTP/ICY + MP3 decoder
                         |-- per-source interference mixer
                         `-- positional OpenAL output
```

SQF decides which URL an object should play, synchronizes that desired state and
computes position/interference values. The extension downloads, decodes, mixes
and plays the audio locally. See
[`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md) for the exact current flow.

## Documentation status

- [`README.md`](README.md) and
  [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md) describe the current runtime.
- [`CHANGELOG.md`](CHANGELOG.md) records released and unreleased changes.
- [`roadmap.md`](roadmap.md) contains future work only.
- [`docs/STATUS.md`](docs/STATUS.md) lists current capabilities, known issues,
  unimplemented features and decisions still needed.
- [`docs/BUILD.md`](docs/BUILD.md) explains the three PBOs, the native DLL and
  the local packaging process.
- [`docs/archive/ROADMAP_HISTORY.md`](docs/archive/ROADMAP_HISTORY.md) preserves
  the former cumulative roadmap without treating it as current status.
- [`docs/archive/WORKFLOW_2026-08-14.md`](docs/archive/WORKFLOW_2026-08-14.md)
  is a historical record of the initial fork work, not the current feature
  matrix.

## Contributors

- **BrettMayson** - original project author and upstream maintainer.
- **mharis001** - interface overhaul and stream metadata upstream.
- **matidp4** (Matias Di Palma) - driver/commander restriction and improvements
  incorporated into this fork.
- **Doble-K** - fork author and maintainer.

## License

- Contribuciones de este fork: [GPL-3.0-or-later](LICENSE).
