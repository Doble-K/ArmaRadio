# Live Radio: Resynced

https://github.com/Doble-K/ArmaRadio

https://discord.gg/c6yMvSuh2Z

[b]Live Radio: Resynced[/b]

Positional live FM radio for Arma 3. Internet stations are decoded by the extension and played through positional OpenAL audio. The radio gets quieter and changes direction as you move around the vehicle or static radio, including Doppler movement.

Community fork of BrettMayson's [url=https://github.com/BrettMayson/ArmaRadio]ArmaRadio[/url], based on upstream v0.9.1. This fork adds fixes, gameplay features, configurable vehicle support and ACE/Zeus/ZEN integration.

[b]Audio and playback[/b]

[list]
[*]Live internet radio streams using ICY/Shoutcast-style MP3 metadata.
[*]Fully positional 3D audio through OpenAL with distance attenuation, movement and listener orientation.
[*]ONLINE/OFFLINE stream status in the radio interface.
[*]Improved per-source static and modulation for damage and interference.
[*]Global static toggle in Addon Options, enabled by default.
[/list]

[b]Interface and stations[/b]

[list]
[*]Station list, search, power control and volume bar.
[*]Custom stations through the customStations CBA setting.
[*]Stations from config, campaign and mission CfgRadioStations are combined and deduplicated by URL.
[*]Per-object volume stored over the network and restored when the mission starts.
[*]English and Spanish localization.
[/list]

[b]CBA settings[/b]

[list]
[*]Volume Multiplier, default 30%.
[*]Streamer Mode to mute all radio sources.
[*]Sound Range.
[*]Driver and Commander Only.
[*]Main Gunner and Co-pilot access, plus optional secondary gunner access.
[*]Vehicle categories: Cars, Armored, Helicopters, Planes and Ships.
[*]Custom vehicle classes.
[*]Configurable radio stations and interference towers.
[*]Radio static toggle.
[*]Optional burned radio system, disabled by default.
[/list]

[b]ACE integration[/b]

[list]
[*]Power, volume and station controls from ACE interaction.
[*]Static radio interaction for Land_FMradio_F.
[*]Repair Radio action for engineers with a toolkit.
[*]Hearing attenuation from ACE earplugs and tinnitus/deafness factors.
[*]Vanilla fallback actions when ACE is not loaded.
[/list]

[b]Zeus and ZEN[/b]

[list]
[*]Vanilla Zeus radio power module and Zeus actions.
[*]ZEN modules and context menu controls.
[*]ZEN module to add an FM radio to a selected object.
[*]ZEN option to keep an object radio powered on when persistent radios are enabled.
[/list]

[b]Interference and damage[/b]

Radio audio can be affected by vehicle damage, rain, explosions, radio towers, TFAR/Antistasi interference and Crows-EW jammers. The radio can progressively degrade and, when the optional burn system is enabled, stop working until repaired.

[b]Requirements[/b]

[list]
[*]Arma 3.
[*]CBA_A3.
[*]ACE3 is optional. ACE actions, ACE repair and hearing integration are skipped when ACE is not loaded; vanilla actions remain available.
[*]ZEN is optional. ZEN modules and context actions are skipped when ZEN is not loaded.
[/list]

[b]Known limitations[/b]

[list]
[*]Auto power-off is disabled by default while a spontaneous power-off report is investigated.
[*]The Rust decoder currently follows upstream v0.9.1 to avoid audio loops introduced by experimental reconnection changes.
[*]Handheld and backpack radio integration is planned, but is not included yet.
[/list]

[b]Credits and licensing[/b]

Original project: BrettMayson and contributors.

Fork contributions: Doble-K.

The upstream code remains under the MIT license. Fork contributions are licensed under GPL-3.0-or-later. See the repository for full attribution and license details.
