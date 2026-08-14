#include "script_component.hpp"
/*
 * Author: matidp4
 * Refreshes the radio display for the given object if it is open.
 *
 * Arguments:
 * 0: Object <OBJECT>
 *
 * Return Value:
 * None
 *
 * Example:
 * [_object] call live_radio_interface_fnc_refresh
 *
 * Public: No
 */

params ["_object"];

private _display = uiNamespace getVariable QGVAR(display);
if (isNull _display) exitWith {};
if (_object isNotEqualTo (_display getVariable QGVAR(object))) exitWith {};

private _active = _object getVariable [QEGVAR(manager,active), []];
_display setVariable [QGVAR(powered), _active isNotEqualTo []];

private _ctrlPower = _display displayCtrl IDC_POWER;
[_ctrlPower, false] call FUNC(handlePower);

private _volume = _object getVariable [QEGVAR(manager,volume), DEFAULT_VOLUME];
[_display, _volume] call FUNC(handleVolume);

[_display] call FUNC(updateInfo);
