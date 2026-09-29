#include "script_component.hpp"

params [["_player", call CBA_fnc_currentUnit]];

private _compatible = _player call FUNC(isCompatible);
private _canOpen = _player call FUNC(canOpen);
private _haveSWRadio = missionNamespace getVariable ["TFAR_fnc_haveSWRadio", {}];
private _hasTFARRadio = if (_haveSWRadio isEqualType {}) then {call _haveSWRadio} else {false};

[
    "personalCondition",
    _player,
    _compatible && _canOpen,
    [_compatible, _canOpen, _hasTFARRadio, isClass (configOf _player >> "ACE_SelfActions")]
] call FUNC(debugInteraction)
