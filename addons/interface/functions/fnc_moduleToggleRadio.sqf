#include "script_component.hpp"
/*
 * Author: matidp4
 * Zeus module that toggles the radio power of the attached object.
 *
 * Arguments:
 * 0: Logic <OBJECT>
 * 1: Activated <BOOL>
 *
 * Return Value:
 * None
 *
 * Example:
 * [_logic, true] call live_radio_interface_fnc_moduleToggleRadio
 *
 * Public: No
 */

params ["_logic", "_activated"];

if !(_activated) exitWith { deleteVehicle _logic; };

private _object = attachedTo _logic;
deleteVehicle _logic;

if (isNull _object) exitWith {};

[_object] call FUNC(power);
