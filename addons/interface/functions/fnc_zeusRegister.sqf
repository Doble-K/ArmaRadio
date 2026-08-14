#include "script_component.hpp"
/*
 * Author: Doble-K
 * Registers ZEN (Zeus Enhanced) integration: custom modules in the Zeus
 * modules tree, context menu actions and dialogs for radio control.
 * Reuses the existing interface/manager functions.
 *
 * Arguments:
 * None
 *
 * Return Value:
 * None
 *
 * Example:
 * call live_radio_interface_fnc_zeusRegister
 *
 * Public: No
 */

// ZEN not loaded
if (!isClass (configFile >> "CfgPatches" >> "zen_custom_modules")) exitWith {};

// --- Custom modules (Zeus modules tree) ---
// Module functions receive [_position ASL, _attachedObject]

["Live Radio", "Toggle Radio Power", {
    params ["", "_object"];
    if (isNull _object) exitWith {
        [LLSTRING(SelectObject)] call zen_common_fnc_showMessage;
    };
    [_object] call FUNC(power);
}] call zen_custom_modules_fnc_register;

["Live Radio", "Radio Volume Up", {
    params ["", "_object"];
    if (isNull _object) exitWith {
        [LLSTRING(SelectObject)] call zen_common_fnc_showMessage;
    };
    [_object, 0.1] call FUNC(volumeChange);
}] call zen_custom_modules_fnc_register;

["Live Radio", "Radio Volume Down", {
    params ["", "_object"];
    if (isNull _object) exitWith {
        [LLSTRING(SelectObject)] call zen_common_fnc_showMessage;
    };
    [_object, -0.1] call FUNC(volumeChange);
}] call zen_custom_modules_fnc_register;

["Live Radio", "Next Station", {
    params ["", "_object"];
    if (isNull _object) exitWith {
        [LLSTRING(SelectObject)] call zen_common_fnc_showMessage;
    };
    [_object, 1] call FUNC(stationChange);
}] call zen_custom_modules_fnc_register;

["Live Radio", "Previous Station", {
    params ["", "_object"];
    if (isNull _object) exitWith {
        [LLSTRING(SelectObject)] call zen_common_fnc_showMessage;
    };
    [_object, -1] call FUNC(stationChange);
}] call zen_custom_modules_fnc_register;

// Dialog module: set the radio station from a list
["Live Radio", "Set Radio Station", {
    params ["", "_object"];
    if (isNull _object) exitWith {
        [LLSTRING(SelectObject)] call zen_common_fnc_showMessage;
    };

    private _active = _object getVariable [QEGVAR(manager,active), []];
    private _currentURL = _active param [1, ""];
    private _defaultIndex = (GVAR(stations) findIf { (_x param [2, ""]) isEqualTo _currentURL }) max 0;

    private _names = GVAR(stations) apply { _x param [0, ""] };

    [LLSTRING(SetStation), [["COMBO", [LLSTRING(Station), format ["%1", _currentURL]], [_names, [], _defaultIndex]]], {
        params ["_values", "_args"];
        _values params ["_name"];
        private _index = GVAR(stations) findIf { (_x param [0, ""]) isEqualTo _name };
        private _url = (GVAR(stations) param [_index, []]) param [2, ""];
        if (_url != "") then {
            [_args, _url] call EFUNC(manager,play);
        };
    }, {}, _object] call zen_dialog_fnc_create;
}] call zen_custom_modules_fnc_register;

// Dialog module: set the radio volume
["Live Radio", "Set Radio Volume", {
    params ["", "_object"];
    if (isNull _object) exitWith {
        [LLSTRING(SelectObject)] call zen_common_fnc_showMessage;
    };

    private _volume = _object getVariable [QEGVAR(manager,volume), DEFAULT_VOLUME];

    [LLSTRING(SetVolume), [["SLIDER", [LLSTRING(Volume), format ["%1", _volume]], [MIN_VOLUME, MAX_VOLUME, _volume, 2]]], {
        params ["_values", "_args"];
        _values params ["_volume"];
        [_args, _volume] call EFUNC(manager,volume);
    }, {}, _object] call zen_dialog_fnc_create;
}] call zen_custom_modules_fnc_register;

// --- Context menu (right-click actions) ---
// Statement/condition receive [_position, _objects, _groups, _waypoints,
// _markers, _hoveredEntity, _args]

if (!isClass (configFile >> "CfgPatches" >> "zen_context_menu")) exitWith {};

private _parent = [
    QGVAR(zeusMenu),
    LLSTRING(FMRadio),
    "",
    {},
    { !isNull (_this select 5) && {(_this select 5) call FUNC(isCompatible)} }
] call zen_context_menu_fnc_createAction;

[_parent, [], 0] call zen_context_menu_fnc_addAction;

private _actions = [
    [LLSTRING(Power), QGVAR(zeusPower), { [(_this select 5)] call FUNC(power) }],
    [LLSTRING(VolumeUp), QGVAR(zeusVolumeUp), { [(_this select 5), 0.1] call FUNC(volumeChange) }],
    [LLSTRING(VolumeDown), QGVAR(zeusVolumeDown), { [(_this select 5), -0.1] call FUNC(volumeChange) }],
    [LLSTRING(StationNext), QGVAR(zeusStationNext), { [(_this select 5), 1] call FUNC(stationChange) }],
    [LLSTRING(StationPrev), QGVAR(zeusStationPrev), { [(_this select 5), -1] call FUNC(stationChange) }]
];

{
    _x params ["_displayName", "_name", "_code"];

    private _action = [_name, _displayName, "", _code, {
        !isNull (_this select 5) && {(_this select 5) call FUNC(isCompatible)}
    }] call zen_context_menu_fnc_createAction;

    [_action, [QGVAR(zeusMenu)], 0] call zen_context_menu_fnc_addAction;
} forEach _actions;
