#include "script_component.hpp"
/*
 * Author: Doble-K
 * Tracks and applies the "burned radio" state for a source object.
 *
 * Two causes burn the radio:
 * - Engine damage above GVAR(radioMotorDamageThreshold).
 * - Staying underwater for longer than GVAR(underwaterBurnTime).
 *
 * Before burning, a growing factor (0..1) is returned so fnc_tick can mix
 * it into source:quality (progressive static/cutouts). Once the factor
 * reaches 1 the radio is marked burned, saved its station and turned off.
 * Leaving the water before burning makes the factor decay gradually.
 *
 * Arguments:
 * 0: Object <OBJECT>
 *
 * Return Value:
 * Number <NUMBER> — burn interference factor in [0, 1]
 *
 * Example:
 * [_vehicle] call live_radio_manager_fnc_burn
 *
 * Public: No
 */

params ["_object"];

if (_object getVariable [QGVAR(burned), false]) exitWith { 1 };

// Damage factor: reaches 1 exactly at the motor burn threshold
private _engineDamage = _object getHitPointDamage "HitEngine";
if (isNil "_engineDamage") then { _engineDamage = 0; };
private _damageFactor = linearConversion [0, GVAR(radioMotorDamageThreshold), _engineDamage, 0, 1, true];

// Underwater factor with gradual decay when out of the water
private _underwaterFactor = _object getVariable [QGVAR(underwaterFactor), 0];
if ((getPosASLW _object) select 2 < 0) then {
    private _since = _object getVariable [QGVAR(underwaterSince), 0];
    if (_since == 0) then {
        _object setVariable [QGVAR(underwaterSince), time];
        _since = time;
    };
    _underwaterFactor = ((time - _since) / GVAR(underwaterBurnTime)) max _underwaterFactor;
} else {
    _object setVariable [QGVAR(underwaterSince), 0];
    _underwaterFactor = (_underwaterFactor - 0.05) max 0;
};
_object setVariable [QGVAR(underwaterFactor), _underwaterFactor];

private _factor = (_damageFactor max _underwaterFactor) min 1;

// Burn: destroy the source and turn the radio off, persisting the state
if (_factor >= 1) then {
    _object setVariable [QGVAR(burned), true, true];
    _object setVariable [QGVAR(lastStation), _object getVariable [QGVAR(active), []] param [1, ""], true];
    [_object, ""] call FUNC(play);
};

_factor
