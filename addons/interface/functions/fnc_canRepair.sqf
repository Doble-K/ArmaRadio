#include "script_component.hpp"
/*
 * Author: Doble-K
 * Checks if the given unit can repair a burned radio (engineer + toolkit).
 *
 * Arguments:
 * 0: Unit <OBJECT>
 *
 * Return Value:
 * BOOLEAN
 *
 * Example:
 * [player] call live_radio_interface_fnc_canRepair
 *
 * Public: No
 */

params ["_unit"];

private _engineer = if (isClass (configFile >> "CfgPatches" >> "ace_repair")) then {
    _unit getVariable ["ace_isEngineer", 0]
} else {
    _unit getVariable ["isEngineer", 0]
};
if (_engineer <= 0) exitWith { false };

("ACE_ToolBox" in (items _unit)) || {("ToolKit" in (items _unit))}
