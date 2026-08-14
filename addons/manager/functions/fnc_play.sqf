#include "script_component.hpp"

params ["_source", "_url"];

private _ret = "";

private _existing = _source getVariable [QGVAR(active), []];
if !(_existing isEqualTo []) then {
    private _id = _existing select 0;
    if (((_existing select 1) isEqualTo _url) && {GVAR(sourcesStatus) getOrDefault [_id, "online"] isNotEqualTo "offline"}) then {
        _ret = _id;
    } else {
        _source setVariable [QGVAR(active), nil, true];
        [QGVAR(stop), [_id]] call CBA_fnc_globalEvent;
    };
};

if !(_ret isEqualTo "") exitWith {};
if (_url isEqualTo "") exitWith {
    _source setVariable [QGVAR(active), nil, true];
};

private _id = EXT callExtension ["id", []] select 0;

_source setVariable [QGVAR(active), [_id, _url], true];

[QGVAR(start), [_id, _url, _source]] call CBA_fnc_globalEvent;

_id
