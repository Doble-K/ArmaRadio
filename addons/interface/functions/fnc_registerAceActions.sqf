#include "script_component.hpp"

if (!hasInterface || {!isClass (configFile >> "CfgPatches" >> "ace_interaction")}) exitWith {};

private _personalAction = [
    QGVAR(personalRadioRuntime),
    localize LSTRING(FMRadioPersonal),
    "",
    { params ["_target", "_player"]; [_player] call FUNC(open) },
    { params ["_target", "_player"]; [_player] call FUNC(debugPersonalAction) }
] call ace_interact_menu_fnc_createAction;

["CAManBase", 1, ["ACE_SelfActions"], _personalAction, true] call ace_interact_menu_fnc_addActionToClass;

{
    [_x, true] call FUNC(registerAceVehicleActions);
} forEach ["Car", "Tank", "Helicopter", "Plane", "Ship"];
