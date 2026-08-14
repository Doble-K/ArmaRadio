#include "script_component.hpp"
/*
 * Author: Doble-K
 * Computes the radio jam interference factor from Crows-Electronic-Warfare
 * (VoiceCommsJammer) or, as a generic fallback, from the TFAR variable
 * tf_receivingDistanceMultiplicator (covers Antistasi and other jammers).
 *
 * Arguments:
 * 0: Player <OBJECT>
 *
 * Return Value:
 * Number <NUMBER> — interference factor in [0, 1]
 *
 * Example:
 * [player] call live_radio_manager_fnc_jamFactor
 *
 * Public: No
 */

params ["_player"];

// Zeus with immunity is not jammed
if (missionNamespace getVariable ["crowsew_main_zeus_jam_immune", false] && {!isNull (findDisplay 312)}) exitWith { 0 };

private _jamMap = missionNamespace getVariable ["crowsew_main_jamMap", nil];
if (isNil "_jamMap") exitWith {
    // Generic fallback: TFAR receiving distance multiplier (Antistasi, etc.)
    private _rx = _player getVariable ["tf_receivingDistanceMultiplicator", 1];
    if (_rx <= 1) exitWith { 0 };
    (_rx - 1) min 1
};

private _playerPos = getPosASL _player;
private _factor = 0;

{
    _x params ["", "_info"];
    _info params ["_unit", "_radFalloff", "_radEffective", "_enabled", "_capabilities"];
    if (!_enabled || {isNull _unit}) then {
        continue;
    };
    if !("VoiceCommsJammer" in _capabilities) then {
        continue;
    };

    private _dist = getPosASL _unit distance _playerPos;
    if (_dist > _radEffective + _radFalloff) then {
        continue;
    };

    private _thisFactor = 1;
    if (_dist > _radEffective) then {
        private _distPercent = abs (_dist - _radEffective) / _radFalloff;
        _thisFactor = 1 - _distPercent;
    };
    _factor = _factor max _thisFactor;
} forEach _jamMap;

_factor min 1
