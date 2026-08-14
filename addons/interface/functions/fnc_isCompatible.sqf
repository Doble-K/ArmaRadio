#include "script_component.hpp"
/*
 * Author: matidp4
 * Checks if the given vehicle is compatible with the radio.
 *
 * Arguments:
 * 0: Vehicle <OBJECT>
 *
 * Return Value:
 * BOOLEAN
 *
 * Example:
 * [_vehicle] call live_radio_interface_fnc_isCompatible
 *
 * Public: No
 */

params ["_object"];

if (_object isKindOf "Land_FMradio_F") exitWith {true};

private _categories = [
    [QGVAR(enableCars), "Car"],
    [QGVAR(enableArmored), "Tank"],
    [QGVAR(enableHelicopters), "Helicopter"],
    [QGVAR(enablePlanes), "Plane"],
    [QGVAR(enableShips), "Ship"]
];

{
    _x params ["_setting", "_cfgClass"];
    if ((missionNamespace getVariable [_setting, false]) && {_object isKindOf _cfgClass}) exitWith {true};
} forEach _categories;

private _customClasses = parseSimpleArray (missionNamespace getVariable [QGVAR(customVehicleClasses), "[]"]);
{
    if (_object isKindOf _x) exitWith {true};
} forEach _customClasses;

false
