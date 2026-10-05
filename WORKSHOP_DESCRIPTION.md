# Live Radio: Resynced

[b][color=#e05a00]STATUS: STANDBY — congelado hasta nuevo aviso.[/color][/b]

https://github.com/Doble-K/ArmaRadio

https://discord.gg/c6yMvSuh2Z

[b]Live Radio: Resynced[/b]

Positional Internet radio for Arma 3. Live Radio associates HTTP/HTTPS MP3
streams with vehicles, static radios and mission objects, then decodes and
plays them locally through positional OpenAL audio.

The sound gets quieter and changes direction as the listener moves around its
source. The current mod streams Internet audio; it does not simulate real FM/AM
frequencies or transmit music through TFAR.

Community fork of BrettMayson's
[url=https://github.com/BrettMayson/ArmaRadio]ArmaRadio[/url], based on upstream
v0.9.1.

[b]Audio and playback[/b]

[list]
[*]HTTP/HTTPS MP3 Internet streams with ICY/Shoutcast-style metadata.
[*]Positional 3D OpenAL audio with distance attenuation, listener orientation and Doppler.
[*]ONLINE/OFFLINE status in the radio interface.
[*]One shared decoder per URL on each client when multiple local radios use the same station.
[*]Per-source interference mixing, filtering, stream fade and slow modulation.
[*]Global volume, per-object volume, Streamer Mode and configurable Sound Range.
[/list]

[b]Interface and stations[/b]

[list]
[*]Station list, search, power control and volume bar.
[*]Custom stations through the customStations CBA setting.
[*]CfgRadioStations support from addon, campaign and mission config.
[*]Validation of custom station names and HTTP(S) URLs, with duplicate URLs ignored when catalogs are combined.
[*]Cars enabled by default; optional armored, helicopter, plane, ship and custom-class support.
[*]Controls for driver, commander, main gunner/co-pilot and optional secondary gunners.
[*]English and Spanish localization.
[/list]

[b]Interference and damage[/b]

[list]
[*]Optional degradation from source damage, rain and compatible jammer data.
[*]Three configurable radial interference profiles around selected tower object classes.
[*]Optional hard radio burn from engine damage or submersion, disabled by default.
[*]Engineer/toolkit repair for burned radios.
[/list]

The tower system currently creates interference around configured objects. It
does not transmit stations or extend station coverage. The Explosion
Interference option is present but currently inactive because no supported
explosion-event source is registered.

[b]ACE, Zeus and ZEN[/b]

[list]
[*]ACE power, volume, station and repair actions when ACE is loaded.
[*]ACE Hearing attenuation applied to Live Radio's global gain.
[*]CBA/vanilla fallback actions when ACE Interaction is absent.
[*]Vanilla Zeus power module.
[*]Optional ZEN modules, dialogs and context-menu controls.
[*]ZEN can attach a station to an arbitrary object and optionally keep it powered.
[/list]

[b]Optional compatibility inputs[/b]

[list]
[*]Crows-EW VoiceCommsJammer entries can affect local interference.
[*]Without a Crows jam map, tf_receivingDistanceMultiplicator can be used as a generic jammer fallback.
[*]A3A_side can be read by the optional tower side filter.
[/list]

These inputs are not complete TFAR or Antistasi integrations. Live Radio does
not currently read TFAR radio inventory, power, channel, volume or frequency,
and it has no Antistasi garage, report or coverage lifecycle.

[b]Requirements[/b]

[list]
[*]Arma 3 2.04 or newer, 64-bit.
[*]CBA_A3.
[*]Internet access on every client that plays streams.
[*]ACE3 is optional.
[*]ZEN is optional.
[/list]

[b]Current limitations[/b]

[list]
[*]Only MP3 streams are supported; AAC, HLS/M3U8 and playlists are not.
[*]There are no real FM/AM bands, RF frequencies or terrain propagation.
[*]Handheld, backpack and TFAR-controlled Internet radios are planned but not implemented.
[*]Audio timing is local to each client and is not sample-synchronized between players.
[*]Per-object state lasts for the mission; it is not persisted across missions.
[*]Automatic power-off currently defaults to 30 m / 120 s. Set either value to 0 to disable it if affected by the historical hosted-session shutdown issue.
[/list]

[b]Credits and licensing[/b]

Original project: BrettMayson and contributors.

Fork contributions: Doble-K.

Contribuciones de este fork: GPL-3.0-or-later. See the repository for full
attribution and license details.
