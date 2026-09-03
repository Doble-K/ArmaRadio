#include "script_component.hpp"
/*
 * Author: Doble-K
 * Rebuilds the runtime station list from customStations and config sources.
 *
 * Arguments:
 * None
 *
 * Return Value:
 * None
 *
 * Public: No
 */

GVAR(stations) = [];

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
