#include "script_component.hpp"

if (!isClass (configFile >> "CfgPatches" >> "ace_interaction")) then {
    private _staticActions = [
        [localize LSTRING(FMRadio), { [cursorTarget] call FUNC(open) }],
        [localize LSTRING(Power), { [cursorTarget] call FUNC(power) }],
        [localize LSTRING(VolumeUp), { [cursorTarget, 0.1] call FUNC(volumeChange) }],
        [localize LSTRING(VolumeDown), { [cursorTarget, -0.1] call FUNC(volumeChange) }],
        [localize LSTRING(StationNext), { [cursorTarget, 1] call FUNC(stationChange) }],
        [localize LSTRING(StationPrev), { [cursorTarget, -1] call FUNC(stationChange) }]
    ];
    {
        _x params ["_name", "_code"];
        [[
            _name,
            _code,
            "", 1, true, true, "",
            'cursorTarget isKindOf "Land_FMradio_F"',
            5
        ]] call CBA_fnc_addPlayerAction;
    } forEach _staticActions;

    private _staticRepairActions = [
        [localize LSTRING(Repair), { [cursorTarget] call FUNC(repair) }]
    ];
    {
        _x params ["_name", "_code"];
        [[
            _name,
            _code,
            "", 1, true, true, "",
            'cursorTarget isKindOf "Land_FMradio_F" && cursorTarget call live_radio_interface_fnc_isBurned && [player] call live_radio_interface_fnc_canRepair',
            5
        ]] call CBA_fnc_addPlayerAction;
    } forEach _staticRepairActions;

    private _vehicleActions = [
        [localize LSTRING(FMRadio), { [vehicle (call CBA_fnc_currentUnit)] call FUNC(open) }],
        [localize LSTRING(Power), { [vehicle (call CBA_fnc_currentUnit)] call FUNC(power) }],
        [localize LSTRING(VolumeUp), { [vehicle (call CBA_fnc_currentUnit), 0.1] call FUNC(volumeChange) }],
        [localize LSTRING(VolumeDown), { [vehicle (call CBA_fnc_currentUnit), -0.1] call FUNC(volumeChange) }],
        [localize LSTRING(StationNext), { [vehicle (call CBA_fnc_currentUnit), 1] call FUNC(stationChange) }],
        [localize LSTRING(StationPrev), { [vehicle (call CBA_fnc_currentUnit), -1] call FUNC(stationChange) }]
    ];
    {
        _x params ["_name", "_code"];
        [[
            _name,
            _code,
            "", 1, true, true, "",
            QUOTE(vehicle (call CBA_fnc_currentUnit) call FUNC(isCompatible) && vehicle (call CBA_fnc_currentUnit) call FUNC(canOpen)),
            5
        ]] call CBA_fnc_addPlayerAction;
    } forEach _vehicleActions;

    private _vehicleRepairActions = [
        [localize LSTRING(Repair), { [vehicle (call CBA_fnc_currentUnit)] call FUNC(repair) }]
    ];
    {
        _x params ["_name", "_code"];
        [[
            _name,
            _code,
            "", 1, true, true, "",
            'vehicle (call CBA_fnc_currentUnit) call live_radio_interface_fnc_isBurned && [player] call live_radio_interface_fnc_canRepair',
            5
        ]] call CBA_fnc_addPlayerAction;
    } forEach _vehicleRepairActions;
};

[QEGVAR(manager,start), {
    params ["", "", "_source"];
    [_source] call FUNC(refresh);
}] call CBA_fnc_addEventHandler;

[QEGVAR(manager,stop), {
    params ["_id"];
    private _display = uiNamespace getVariable QGVAR(display);
    if (isNull _display) exitWith {};
    private _object = _display getVariable QGVAR(object);
    if ((_object getVariable [QEGVAR(manager,active), []] param [0, ""]) isEqualTo _id) then {
        [_object] call FUNC(refresh);
    };
}] call CBA_fnc_addEventHandler;

[QEGVAR(manager,volume), {
    params ["_id", "_gain"];
    private _display = uiNamespace getVariable QGVAR(display);
    if (isNull _display) exitWith {};
    private _object = _display getVariable QGVAR(object);
    if ((_object getVariable [QEGVAR(manager,active), []] param [0, ""]) isEqualTo _id) then {
        [_display, _gain] call FUNC(handleVolume);
    };
}] call CBA_fnc_addEventHandler;

[QEGVAR(manager,metadataUpdated), {
    [uiNamespace getVariable QGVAR(display)] call FUNC(updateInfo);
}] call CBA_fnc_addEventHandler;

// ZEN (Zeus Enhanced) integration: modules, context menu and dialogs
if (isClass (configFile >> "CfgPatches" >> "zen_custom_modules")) then {
    call FUNC(zeusRegister);
};
