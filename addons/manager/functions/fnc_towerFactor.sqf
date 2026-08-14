#include "script_component.hpp"
/*
 * Author: Doble-K
 * Computes the interference factor from nearby radio towers (TFAR/Antistasi).
 *
 * Arguments:
 * 0: Player <OBJECT>
 *
 * Return Value:
 * Number <NUMBER> — interference factor in [0, 1]
 *
 * Example:
 * [player] call live_radio_manager_fnc_towerFactor
 *
 * Public: No
 */

params ["_player"];

private _radius = GVAR(interferenceTowerRadius);
private _strength = GVAR(interferenceTowerStrength);
if (_radius <= 0 || {_strength <= 0}) exitWith { 0 };

private _towerClasses = parseSimpleArray GVAR(interferenceTowers);
if (_towerClasses isEqualTo []) exitWith { 0 };

// Collect nearby towers with throttle (every 3s) and cache them
if (diag_tickTime - GVAR(towersLastScan) > 3) then {
    GVAR(towersLastScan) = diag_tickTime;
    GVAR(nearbyTowers) = nearestObjects [getPosASL _player, _towerClasses, _radius];
};

private _playerPos = getPosASL _player;
private _playerSide = side _player;
private _sideFilter = GVAR(interferenceTowerSideFilter);
private _factor = 0;

{
    private _dist = getPosASL _x distance _playerPos;
    if (_dist <= _radius) then {
        if (_sideFilter) then {
            private _towerSide = _x getVariable ["A3A_side", _x getVariable ["side", side _x]];
            if (_towerSide == sideUnknown) then {
                _towerSide = side _x;
            };
            if (_towerSide != sideUnknown && {_playerSide != sideUnknown}) then {
                private _enemy = (_towerSide getFriend _playerSide) select 0 < 0.6;
                if !(_enemy) then {
                    continue;
                };
            };
        };
        _factor = _factor + _strength * (1 - _dist / _radius);
    };
} forEach GVAR(nearbyTowers);

_factor min 1
