#include "script_component.hpp"

ADDON = false;

#include "XEH_PREP.hpp"

ADDON = true;

GVAR(stations) = [];

{
    private _stations = configProperties [_x >> "CfgRadioStations", "isClass _x"] apply {
        [getText (_x >> "name"), getText (_x >> "picture"), getText (_x >> "url")]
    };

    GVAR(stations) append _stations;
} forEach [configFile, campaignConfigFile, missionConfigFile];

GVAR(stations) sort true;

[
    QGVAR(driverAndCommanderOnly),
    "CHECKBOX",
    "Driver and Commander Only",
    "Live Radio",
    true,
    1
] call CBA_fnc_addSetting;

[
    QGVAR(enableCars),
    "CHECKBOX",
    "Enable for Cars",
    "Live Radio",
    true,
    1
] call CBA_fnc_addSetting;

[
    QGVAR(enableArmored),
    "CHECKBOX",
    "Enable for Armored",
    "Live Radio",
    false,
    1
] call CBA_fnc_addSetting;

[
    QGVAR(enableHelicopters),
    "CHECKBOX",
    "Enable for Helicopters",
    "Live Radio",
    false,
    1
] call CBA_fnc_addSetting;

[
    QGVAR(enablePlanes),
    "CHECKBOX",
    "Enable for Planes",
    "Live Radio",
    false,
    1
] call CBA_fnc_addSetting;

[
    QGVAR(enableShips),
    "CHECKBOX",
    "Enable for Ships",
    "Live Radio",
    false,
    1
] call CBA_fnc_addSetting;

[
    QGVAR(customVehicleClasses),
    "EDITBOX",
    "Custom vehicle classes",
    "Live Radio",
    "[]",
    1
] call CBA_fnc_addSetting;
