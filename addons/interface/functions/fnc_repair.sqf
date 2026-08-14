#include "script_component.hpp"
/*
 * Author: Doble-K
 * Repairs a burned radio on the given object, restoring it with the saved
 * station after a repair delay. Requires an engineer with a toolkit.
 *
 * Arguments:
 * 0: Object <OBJECT>
 *
 * Return Value:
 * None
 *
 * Example:
 * [_vehicle] call live_radio_interface_fnc_repair
 *
 * Public: No
 */

params ["_object"];

if !(_object getVariable [QEGVAR(manager,burned), false]) exitWith {};
if (_object getVariable [QGVAR(repairing), false]) exitWith {};

private _unit = call CBA_fnc_currentUnit;
if !([_unit] call FUNC(canRepair)) exitWith {};

_object setVariable [QGVAR(repairing), true, true];

[
    {
        params ["_object"];
        _object setVariable [QGVAR(repairing), false, true];

        if !(_object getVariable [QEGVAR(manager,burned), false]) exitWith {};

        _object setVariable [QEGVAR(manager,burned), false, true];
        _object setVariable [QEGVAR(manager,underwaterFactor), 0, true];

        private _station = _object getVariable [QEGVAR(manager,lastStation), (GVAR(stations) param [0, []]) param [2, ""]];
        if (_station != "") then {
            [_object, _station] call EFUNC(manager,play);
        };
    },
    [_object],
    5
] call CBA_fnc_waitAndExecute;
