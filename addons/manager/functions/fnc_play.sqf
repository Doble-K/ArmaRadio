#include "script_component.hpp"

params ["_source", "_url"];

private _ret = "";
private _previous = _source getVariable [QGVAR(active), []];
if (GVAR(debugAudio)) then {
    diag_log format [
        "[Live Radio][Audio] play request source=%1 type=%2 url=%3 previous=%4",
        _source,
        typeOf _source,
        _url,
        _previous
    ];
};

// A persistent radio cannot be powered off while the feature is enabled.
if (_url isEqualTo "" && {GVAR(enablePersistentRadios)} && {_source getVariable [QGVAR(keepPowered), false]}) exitWith {
    ((_source getVariable [QGVAR(active), []]) param [0, ""])
};

// A burned radio cannot be turned back on until it is repaired
if ((_source getVariable [QGVAR(burned), false]) && {_url isNotEqualTo ""}) exitWith { "" };

private _existing = _source getVariable [QGVAR(active), []];
if (_existing isNotEqualTo []) then {
    private _id = _existing select 0;
    if (((_existing select 1) isEqualTo _url) && {GVAR(sourcesStatus) getOrDefault [_id, "online"] isNotEqualTo "offline"}) then {
        _ret = _id;
    } else {
        if (GVAR(debugAudio)) then {
            diag_log format [
                "[Live Radio][Audio] replacing source=%1 oldId=%2 oldUrl=%3 newUrl=%4",
                _source,
                _id,
                _existing select 1,
                _url
            ];
        };
        _source setVariable [QGVAR(active), nil, true];
        [QGVAR(stop), [_id]] call CBA_fnc_globalEvent;
    };
};

if (_ret isNotEqualTo "") exitWith {
    if (GVAR(debugAudio)) then {
        diag_log format ["[Live Radio][Audio] reusing existing source=%1 id=%2", _source, _ret];
    };
    _ret
};
if (_url isEqualTo "") exitWith {
    _source setVariable [QGVAR(active), nil, true];
};

private _id = EXT callExtension ["id", []] select 0;

_source setVariable [QGVAR(active), [_id, _url], true];

[QGVAR(start), [_id, _url, _source]] call CBA_fnc_globalEvent;

_id
