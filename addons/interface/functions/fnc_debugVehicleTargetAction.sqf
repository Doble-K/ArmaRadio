#include "script_component.hpp"

params ["_target"];
private _result = _target call FUNC(isCompatible) && {_target call FUNC(canOpen)};
[
    "vehicleTargetCondition",
    _target,
    _result,
    [_target call FUNC(isCompatible), _target call FUNC(canOpen), isClass (configOf _target >> "ACE_Actions")]
] call FUNC(debugInteraction)
