#include "script_component.hpp"
/*
 * Author: matidp4
 * Applies the effective global gain to all sources, accounting for
 * streamer mode and ACE hearing (earplugs / deafness).
 *
 * Arguments:
 * 0: Gain <NUMBER> (default: 1)
 *
 * Return Value:
 * None
 *
 * Example:
 * [0.3] call live_radio_manager_fnc_applyGain
 *
 * Public: No
 */

params [["_gain", 1]];

if (GVAR(streamerMode)) then {
    _gain = 0;
};

if (isClass (configFile >> "CfgPatches" >> "ace_hearing")) then {
    _gain = _gain
        * (missionNamespace getVariable ["ace_hearing_volume", 1])
        * (missionNamespace getVariable ["ace_hearing_volumeAttenuation", 1]);
};

EXT callExtension ["source:global_gain", [_gain]];
