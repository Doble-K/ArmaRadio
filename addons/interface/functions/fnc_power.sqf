#include "script_component.hpp"
/*
 * Author: matidp4
 * Toggles the radio power for the given object.
 *
 * Arguments:
 * 0: Object <OBJECT>
 *
 * Return Value:
 * None
 *
 * Example:
 * [_object] call live_radio_interface_fnc_power
 *
 * Public: No
 */

params ["_object"];

if (_object isKindOf "Man") then {
    _object = vehicle _object;
};

private _active = _object getVariable [QEGVAR(manager,active), []];

if (_active isEqualTo []) then {
    private _url = _object getVariable [QGVAR(lastStation), (GVAR(stations) param [0, []]) param [2, ""]];
    if (_url != "") then {
        [_object, _url] call EFUNC(manager,play);
        EXT callExtension ["click", []];
    };
} else {
    _object setVariable [QGVAR(lastStation), _active param [1, ""], true];
    [_object, ""] call EFUNC(manager,play);
    EXT callExtension ["click", []];
};
