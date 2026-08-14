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
    LLSTRING(DriverAndCommanderOnly),
    LLSTRING(Category),
    true,
    1
] call CBA_fnc_addSetting;

[
    QGVAR(enableCars),
    "CHECKBOX",
    LLSTRING(EnableCars),
    LLSTRING(Category),
    true,
    1
] call CBA_fnc_addSetting;

[
    QGVAR(enableArmored),
    "CHECKBOX",
    LLSTRING(EnableArmored),
    LLSTRING(Category),
    false,
    1
] call CBA_fnc_addSetting;

[
    QGVAR(enableHelicopters),
    "CHECKBOX",
    LLSTRING(EnableHelicopters),
    LLSTRING(Category),
    false,
    1
] call CBA_fnc_addSetting;

[
    QGVAR(enablePlanes),
    "CHECKBOX",
    LLSTRING(EnablePlanes),
    LLSTRING(Category),
    false,
    1
] call CBA_fnc_addSetting;

[
    QGVAR(enableShips),
    "CHECKBOX",
    LLSTRING(EnableShips),
    LLSTRING(Category),
    false,
    1
] call CBA_fnc_addSetting;

[
    QGVAR(customVehicleClasses),
    "EDITBOX",
    LLSTRING(CustomVehicleClasses),
    LLSTRING(Category),
    "[]",
    1
] call CBA_fnc_addSetting;
