#include "script_component.hpp"
/*
 * Author: Brett Mayson,  matidp4
 * Checks if the player can open the interface
 *
 * Arguments:
 * 0: Object <OBJECT>
 *
 * Return Value:
 * BOOLEAN
 *
 * Example:
 * [_object] call live_radio_interface_fnc_canOpen
 *
 * Public: No
 */

params ["_object"];

if (_object isKindOf "Land_FMradio_F") exitWith {true};
if !(missionNamespace getVariable [QGVAR(driverAndCommanderOnly), false]) exitWith {true};

private _player = call CBA_fnc_currentUnit;

if (driver _object == _player) exitWith {true};
if (commander _object == _player) exitWith {true};

// Main gunner / co-pilot seat: crew, controlled by its own setting
if (gunner _object == _player) exitWith {
    missionNamespace getVariable [QGVAR(mainGunnerAndCopilotCanControl), true]
};

// Secondary turrets / door gunners: only with the "All Gunners" setting on
private _turretCrew = fullCrew [_object, "turret", false];
private _playerTurret = _turretCrew select {(_x select 0) isEqualTo _player};
if (_playerTurret isNotEqualTo []) exitWith {
    private _path = (_playerTurret select 0) select 3;
    (count _path > 0) && {missionNamespace getVariable [QGVAR(allGunnersCanControl), false]}
};

// Land vehicles without a commander position: only the front passenger,
// the cargo occupant closest to the driver's seat
if (fullCrew [_object, "commander", true] isEqualTo [] && {_object isKindOf "Car" || {_object isKindOf "Tank"}}) exitWith {
    private _driver = driver _object;
    private _passengers = fullCrew [_object, "cargo", false];
    private _front = objNull;
    if (isNull _driver) then {
        _front = (_passengers param [0, []]) param [0, objNull];
    } else {
        private _best = 1e10;
        {
            _x params ["_unit"];
            private _dist = _unit distance _driver;
            if (_dist < _best) then {
                _best = _dist;
                _front = _unit;
            };
        } forEach _passengers;
    };
    _front isEqualTo _player
};

false
