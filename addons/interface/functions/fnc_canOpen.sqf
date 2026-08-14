#include "script_component.hpp"
/*
 * Author: Brett Mayson,  matidp4
 * Checks if the player can open the interface
 *
 * Arguments:
 * 0: Object <OBJECT>
 *
 * Return Value:
 * BOOLEAN
 *
 * Example:
 * [_object] call live_radio_interface_fnc_canOpen
 *
 * Public: No
 */

params ["_object"];

if (_object isKindOf "Land_FMradio_F") exitWith {true};
if !(missionNamespace getVariable [QGVAR(driverAndCommanderOnly), false]) exitWith {true};

private _player = call CBA_fnc_currentUnit;

if (driver _object == _player) exitWith {true};
if (commander _object == _player) exitWith {true};

// Main gunner controls only with the setting on and for armored/aircraft classes
if (gunner _object == _player) exitWith {
    (missionNamespace getVariable [QGVAR(allGunnersCanControl), false])
    && {_object isKindOf "Tank" || {_object isKindOf "Helicopter"} || {_object isKindOf "Plane"}}
};

// Vehicles without a commander position: delegate control to the first two passengers
if (fullCrew [_object, "commander", true] isEqualTo []) exitWith {
    private _passengers = fullCrew [_object, "cargo", false];
    private _first = _passengers param [0, []] param [0, objNull];
    private _second = _passengers param [1, []] param [0, objNull];
    (_first isEqualTo _player) || (_second isEqualTo _player)
};

false
