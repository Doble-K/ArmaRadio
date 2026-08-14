#include "script_component.hpp"

ADDON = false;

#include "XEH_PREP.hpp"

ADDON = true;

GVAR(stations) = [];

[
    QGVAR(customStations),
    "EDITBOX",
    [LLSTRING(CustomStations), LLSTRING(CustomStationsDescription)],
    LLSTRING(Category),
    "[[""Classic Rock 109"",""http://listen.classicrock109.com:10042""],[""PulseEDM Dance Music"",""http://pulseedm.cdnstream1.com:8124/1373_128""],[""Live Ireland"",""http://192.111.140.11:8058/stream?type=http&nocache=325927""]]",
    1
] call CBA_fnc_addSetting;

// Build the station list from customStations (primary) + config sources, dedup by URL.
private _customStations = [];
private _customText = missionNamespace getVariable [QGVAR(customStations), "[]"];
if (count _customText > 0 && {(toArray _customText) param [0, 91] == 91}) then {
    _customStations = parseSimpleArray _customText;
};

private _seenURLs = createHashMap;

// Normalize custom stations [name, url] -> [name, "", url], dedup by URL
{
    if (_x isEqualType [] && {count _x >= 2} && {(_x select 0) isEqualType ""} && {(_x select 1) isEqualType ""}) then {
        _x params ["_name", "_url"];
        if !(_seenURLs getOrDefault [_url, false]) then {
            _seenURLs set [_url, true];
            GVAR(stations) pushBack [_name, "", _url];
        };
    };
} forEach _customStations;

private _configStations = [];
{
    _configStations append (configProperties [_x >> "CfgRadioStations", "isClass _x"] apply {
        [getText (_x >> "name"), getText (_x >> "picture"), getText (_x >> "url")]
    });
} forEach [configFile, campaignConfigFile, missionConfigFile];

// Fallback: if customStations is empty or unparseable, use the config stations
if (GVAR(stations) isEqualTo []) then {
    GVAR(stations) append _configStations;
} else {
    // Combine with config sources, dedup by URL
    {
        _x params ["_name", "_picture", "_url"];
        if !(_seenURLs getOrDefault [_url, false]) then {
            _seenURLs set [_url, true];
            GVAR(stations) pushBack _x;
        };
    } forEach _configStations;
};

GVAR(stations) sort true;

[
    QGVAR(driverAndCommanderOnly),
    "CHECKBOX",
    [LLSTRING(DriverAndCommanderOnly), LLSTRING(DriverAndCommanderOnlyDescription)],
    LLSTRING(Category),
    true,
    1
] call CBA_fnc_addSetting;

[
    QGVAR(allGunnersCanControl),
    "CHECKBOX",
    [LLSTRING(AllGunnersCanControl), LLSTRING(AllGunnersCanControlDescription)],
    LLSTRING(Category),
    false,
    1
] call CBA_fnc_addSetting;

[
    QGVAR(enableCars),
    "CHECKBOX",
    [LLSTRING(EnableCars), LLSTRING(EnableCarsDescription)],
    LLSTRING(Category),
    true,
    1
] call CBA_fnc_addSetting;

[
    QGVAR(enableArmored),
    "CHECKBOX",
    [LLSTRING(EnableArmored), LLSTRING(EnableArmoredDescription)],
    LLSTRING(Category),
    false,
    1
] call CBA_fnc_addSetting;

[
    QGVAR(enableHelicopters),
    "CHECKBOX",
    [LLSTRING(EnableHelicopters), LLSTRING(EnableHelicoptersDescription)],
    LLSTRING(Category),
    false,
    1
] call CBA_fnc_addSetting;

[
    QGVAR(enablePlanes),
    "CHECKBOX",
    [LLSTRING(EnablePlanes), LLSTRING(EnablePlanesDescription)],
    LLSTRING(Category),
    false,
    1
] call CBA_fnc_addSetting;

[
    QGVAR(enableShips),
    "CHECKBOX",
    [LLSTRING(EnableShips), LLSTRING(EnableShipsDescription)],
    LLSTRING(Category),
    false,
    1
] call CBA_fnc_addSetting;

[
    QGVAR(customVehicleClasses),
    "EDITBOX",
    [LLSTRING(CustomVehicleClasses), LLSTRING(CustomVehicleClassesDescription)],
    LLSTRING(Category),
    "[]",
    1
] call CBA_fnc_addSetting;
