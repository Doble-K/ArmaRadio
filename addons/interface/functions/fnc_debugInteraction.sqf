#include "script_component.hpp"

params ["_phase", "_target", "_result", ["_details", []]];

if (!GVAR(debugInteraction)) exitWith {_result};

private _player = call CBA_fnc_currentUnit;
private _vehicle = vehicle _player;
private _signature = [
    typeOf _target,
    typeOf _vehicle,
    _vehicle isNotEqualTo _player,
    assignedVehicleRole _player,
    _result
];
_signature append _details;

private _previous = GVAR(debugInteractionLast) getOrDefault [_phase, []];
if (_previous isEqualTo _signature) exitWith {_result};
GVAR(debugInteractionLast) set [_phase, _signature];

diag_log format [
    "[Live Radio][ACE] phase=%1 target=%2 vehicle=%3 inVehicle=%4 role=%5 result=%6 details=%7",
    _phase,
    typeOf _target,
    typeOf _vehicle,
    _vehicle isNotEqualTo _player,
    assignedVehicleRole _player,
    _result,
    _details
];

_result
