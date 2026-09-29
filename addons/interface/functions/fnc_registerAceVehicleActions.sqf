#include "script_component.hpp"

params ["_type", ["_inherit", false]];

if !(_type isKindOf "Car" || {_type isKindOf "Tank"} || {_type isKindOf "Helicopter"} || {_type isKindOf "Plane"} || {_type isKindOf "Ship"}) exitWith {};

private _vehicleChildren = {
    params ["_target", "_player"];
    private _actions = [];
    private _add = {
        params ["_id", "_name", "_statement", "_condition", ["_params", []]];
        private _action = [_id, _name, "", _statement, _condition, {}, _params] call ace_interact_menu_fnc_createAction;
        _actions pushBack [_action, [], _target];
    };

    [
        QGVAR(openRuntime),
        localize LSTRING(Open),
        { params ["_target"]; [_target] call FUNC(open) },
        { params ["_target"]; [_target] call FUNC(debugVehicleTargetAction) }
    ] call _add;
    [
        QGVAR(powerRuntime),
        localize LSTRING(Power),
        { params ["_target"]; [_target] call FUNC(power) },
        { params ["_target"]; [_target] call FUNC(isCompatible) && {_target call FUNC(canOpen)} }
    ] call _add;
    {
        _x params ["_suffix", "_label", "_volume"];
        [
            format ["%1%2", QGVAR(volumeRuntime), _suffix],
            format ["%1 %2", localize LSTRING(SetVolume), _label],
            { params ["_target", "_player", "_params"]; _params params ["_volume"]; [_target, _volume] call EFUNC(manager,volume) },
            { params ["_target"]; [_target] call FUNC(isCompatible) && {_target call FUNC(canOpen)} },
            _volume
        ] call _add;
    } forEach [["0", "0%", 0], ["25", "25%", 0.25], ["50", "50%", 0.5], ["100", "100%", 1]];
    [
        QGVAR(stationNextRuntime),
        localize LSTRING(StationNext),
        { params ["_target"]; [_target, 1] call FUNC(stationChange) },
        { params ["_target"]; [_target] call FUNC(isCompatible) && {_target call FUNC(canOpen)} }
    ] call _add;
    [
        QGVAR(stationPrevRuntime),
        localize LSTRING(StationPrev),
        { params ["_target"]; [_target, -1] call FUNC(stationChange) },
        { params ["_target"]; [_target] call FUNC(isCompatible) && {_target call FUNC(canOpen)} }
    ] call _add;
    [
        QGVAR(repairRuntime),
        localize LSTRING(Repair),
        { params ["_target"]; [_target] call FUNC(repair) },
        { params ["_target", "_player"]; [_target] call FUNC(isBurned) && {[_player] call FUNC(canRepair)} }
    ] call _add;
    _actions
};

private _vehicleAction = [
    QGVAR(vehicleRadioRuntime),
    localize LSTRING(FMRadioVehicle),
    "",
    { params ["_target", "_player"]; [vehicle _player] call FUNC(open) },
    { params ["_target", "_player"]; [_player] call FUNC(debugVehicleAction) },
    _vehicleChildren
] call ace_interact_menu_fnc_createAction;
[_type, 1, ["ACE_SelfActions"], _vehicleAction, _inherit] call ace_interact_menu_fnc_addActionToClass;

private _externalAction = [
    QGVAR(vehicleRadioExternalRuntime),
    localize LSTRING(FMRadioVehicle),
    "",
    { params ["_target"]; [_target] call FUNC(open) },
    { params ["_target"]; [_target] call FUNC(debugVehicleTargetAction) },
    _vehicleChildren
] call ace_interact_menu_fnc_createAction;
[_type, 0, ["ACE_MainActions"], _externalAction, _inherit] call ace_interact_menu_fnc_addActionToClass;
