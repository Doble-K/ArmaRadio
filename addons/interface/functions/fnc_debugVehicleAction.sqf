#include "script_component.hpp"

params [["_player", call CBA_fnc_currentUnit]];

private _vehicle = vehicle _player;
private _inVehicle = _vehicle isNotEqualTo _player;
private _compatible = _inVehicle && {_vehicle call FUNC(isCompatible)};
private _canOpen = _inVehicle && {_vehicle call FUNC(canOpen)};

[
    "vehicleCondition",
    _vehicle,
    _compatible && _canOpen,
    [
        _compatible,
        _canOpen,
        GVAR(enableCars),
        GVAR(enableArmored),
        GVAR(enableHelicopters),
        GVAR(enablePlanes),
        GVAR(enableShips),
        isClass (configOf _vehicle >> "ACE_SelfActions"),
        isClass (configOf _vehicle >> "ACE_Actions")
    ]
] call FUNC(debugInteraction)
