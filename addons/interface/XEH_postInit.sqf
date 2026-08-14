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
};

[QEGVAR(manager,metadataUpdated), {
    [uiNamespace getVariable QGVAR(display)] call FUNC(updateInfo);
}] call CBA_fnc_addEventHandler;
