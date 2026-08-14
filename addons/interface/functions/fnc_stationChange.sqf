#include "script_component.hpp"
/*
 * Author: matidp4
 * Changes to the previous or next station for the given object.
 *
 * Arguments:
 * 0: Object <OBJECT>
 * 1: Direction <NUMBER> (-1 previous, 1 next; default: 1)
 *
 * Return Value:
 * None
 *
 * Example:
 * [_object, 1] call live_radio_interface_fnc_stationChange
 *
 * Public: No
 */

params ["_object", ["_direction", 1]];

private _active = _object getVariable [QEGVAR(manager,active), []];
if (_active isEqualTo []) exitWith {};

private _currentURL = _active param [1, ""];
private _index = GVAR(stations) findIf { (_x param [2, ""]) isEqualTo _currentURL };
if (_index == -1) then {
    _index = 0;
};

private _count = count GVAR(stations);
if (_count == 0) exitWith {};

_index = (_index + _direction + _count) % _count;

private _url = (GVAR(stations) param [_index, []]) param [2, ""];
if (_url != "") then {
    [_object, _url] call EFUNC(manager,play);
};
