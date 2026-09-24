#include "script_component.hpp"
/*
 * Author: Doble-K
 * Computes the interference factor from nearby radio towers (TFAR/Antistasi).
 *
 * Arguments:
 * 0: Player <OBJECT>
 *
 * Return Value:
 * Array <ARRAY> — interference factors for cones 1, 2 and 3, each in [0, 1]
 *
 * Example:
 * [player] call live_radio_manager_fnc_towerFactor
 *
 * Public: No
 */

params ["_player"];

private _strength = GVAR(interferenceTowerStrength);
if (_strength <= 0) exitWith { [0, 0, 0] };

private _outerRadii = [GVAR(cone1OuterRadius), GVAR(cone2OuterRadius), GVAR(cone3OuterRadius)];
private _innerRadii = [GVAR(cone1InnerRadius), GVAR(cone2InnerRadius), GVAR(cone3InnerRadius)];
private _scanRadius = (GVAR(interferenceTowerRadius) max (selectMax _outerRadii));
if (_scanRadius <= 0) exitWith { [0, 0, 0] };

private _towerClasses = parseSimpleArray GVAR(interferenceTowers);
if (_towerClasses isEqualTo []) exitWith { [0, 0, 0] };
if (_towerClasses isEqualTo ["Land_Communication_F"]) then {
    _towerClasses append [
        "Land_TTowerBig_1_F",
        "Land_TTowerBig_2_F",
        "Land_TTowerBig_2_ruins_F",
        "Land_TTowerSmall_1_F",
        "Land_TTowerSmall_2_F"
    ];
};

// Collect nearby towers with throttle (every 3s) and cache them
if (diag_tickTime - GVAR(towersLastScan) > 3) then {
    GVAR(towersLastScan) = diag_tickTime;
    GVAR(nearbyTowers) = nearestObjects [getPosASL _player, _towerClasses, _scanRadius];
};

private _playerPos = getPosASL _player;
private _playerSide = side _player;
private _sideFilter = GVAR(interferenceTowerSideFilter);
private _factors = [0, 0, 0];

{
    private _dist = getPosASL _x distance _playerPos;
    if (_dist <= _scanRadius) then {
        if (_sideFilter) then {
            private _towerSide = _x getVariable ["A3A_side", _x getVariable ["side", side _x]];
            if (_towerSide == sideUnknown) then {
                _towerSide = side _x;
            };
            if (_towerSide != sideUnknown && {_playerSide != sideUnknown}) then {
                private _friend = _towerSide getFriend _playerSide;
                private _enemy = (_friend param [0, 1]) < 0.6;
                if !(_enemy) then {
                    continue;
                };
            };
        };
        {
            private _index = _forEachIndex;
            private _outer = _outerRadii select _index;
            private _inner = _innerRadii select _index min _outer;
            if (_outer > 0 && {_outer > _inner}) then {
                private _factor = ((_outer - _dist) / (_outer - _inner)) max 0 min 1;
                _factors set [_index, ((_factors select _index) + _strength * _factor) min 1];
            };
        } forEach _outerRadii;
    };
} forEach GVAR(nearbyTowers);

_factors
