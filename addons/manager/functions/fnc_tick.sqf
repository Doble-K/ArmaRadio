#include "script_component.hpp"

private _player = call CBA_fnc_currentUnit;
private _inZeus = !(isNull (findDisplay 312));

private _range = GVAR(soundRange);

private _data = if (_inZeus) then {
    private _d = vectorDir curatorCamera;
    _d append vectorUp curatorCamera;
    _d
} else {
    private _d = eyeDirection _player;
    _d append vectorUp _player;
    _d
};
EXT callExtension ["listener:dir", _data];

// Radio tower interference (TFAR/Antistasi), throttled in FUNC(towerFactor)
private _towerFactors = [_player] call FUNC(towerFactor);

// Crows-EW / TFAR radio jammer interference
private _jamFactor = [_player] call FUNC(jamFactor);

{
    if (alive _y) then {
        private _pos = getPosASL _y;
        private _data = [_x, 0, 0, 0];
        if (_inZeus || {_y isNotEqualTo vehicle _player}) then {
            private _ppos = eyePos _player;
            if (_inZeus) then {
                _ppos = getPosASL curatorCamera;
            };
            private _outOfRange = _range > 0 && {(_pos distance _ppos) > _range};
            if (_outOfRange != (_y getVariable [QGVAR(outOfRange), false])) then {
                _y setVariable [QGVAR(outOfRange), _outOfRange];
                EXT callExtension ["source:gain", [_x, if (_outOfRange) then { 0 } else { _y getVariable [QGVAR(volume), 1] }]];
            };
            _data = [
                _x,
                (_pos#0 - _ppos#0) toFixed 2,
                (_pos#1 - _ppos#1) toFixed 2,
                (_pos#2 - _ppos#2) toFixed 2
            ];
        };
        EXT callExtension ["source:pos", _data];

        private _damage = if (GVAR(enableDamageInterference)) then {
            linearConversion [0, 1, getDammage _y, 0, 1, true]
        } else {
            0
        };
        private _storm = if (GVAR(enableWeatherInterference)) then { 0.2 * rain } else { 0 };
        private _explosion = if (GVAR(enableExplosionInterference)) then {
            linearConversion [10, 0, time - GVAR(lastExplosion), 0, 1, true]
        } else {
            0
        };
        private _jam = [0, _jamFactor] select GVAR(enableJammerInterference);
        private _burn = if (GVAR(enableBurnInterference)) then { [_y] call FUNC(burn) } else { 0 };
        private _target = if (GVAR(enableStatic)) then {
            (_damage + _storm + _explosion + _jam + _burn) min 1
        } else {
            0
        };

        private _current = _y getVariable [QGVAR(quality), 0];
        private _step = diag_deltaTime * 2;
        private _delta = _target - _current;
        private _smoothed = _current + (_delta min _step max -_step);
        private _cone1 = if (GVAR(enableStatic) && {GVAR(enableCone1)}) then {
            private _factor = _towerFactors select 0;
            if (_factor > 0) then {
                _factor * linearConversion [0, 1, GVAR(cone1VolumeStart), GVAR(cone1VolumeEnd), _factor, true]
            } else {
                0
            }
        } else {
            0
        };
        private _cone2 = if (GVAR(enableStatic) && {GVAR(enableCone2)}) then {
            private _factor = _towerFactors select 1;
            if (_factor > 0) then {
                _factor * linearConversion [0, 1, GVAR(cone2VolumeStart), GVAR(cone2VolumeEnd), _factor, true]
            } else {
                0
            }
        } else {
            0
        };
        private _cone3 = if (GVAR(enableStatic) && {GVAR(enableCone3)}) then {
            private _factor = _towerFactors select 2;
            if (_factor > 0) then {
                _factor * linearConversion [0, 1, GVAR(cone3VolumeStart), GVAR(cone3VolumeEnd), _factor, true]
            } else {
                0
            }
        } else {
            0
        };
        private _targets = [_smoothed, _cone1, _cone2, _cone3];
        private _previousTargets = _y getVariable [QGVAR(interferenceTargets), [0, 0, 0, 0]];
        private _targetsChanged = false;
        {
            if (abs ((_targets select _forEachIndex) - (_previousTargets select _forEachIndex)) > 0.005) exitWith {
                _targetsChanged = true;
            };
        } forEach _targets;
        private _fadeChanged = abs ((_y getVariable [QGVAR(interferenceFade), -1]) - GVAR(streamFadeOut)) > 0.005;
        if (_fadeChanged || {_targetsChanged}) then {
            _y setVariable [QGVAR(quality), _smoothed];
            _y setVariable [QGVAR(interferenceTargets), _targets];
            _y setVariable [QGVAR(interferenceFade), GVAR(streamFadeOut)];
            EXT callExtension ["source:interference", [_x, _smoothed, _cone1, _cone2, _cone3, GVAR(streamFadeOut)]];
        };

        if (diag_tickTime - (_y getVariable [QGVAR(lastExistsCheck), 0]) > 2) then {
            _y setVariable [QGVAR(lastExistsCheck), diag_tickTime];
            if (((EXT callExtension ["source:exists", [_x]]) select 0) isEqualTo "0") then {
                private _active = _y getVariable [QGVAR(active), []];
                if (_active isNotEqualTo []) then {
                    EXT callExtension ["source:new", [_x, _active param [1, ""], _y getVariable [QGVAR(volume), 1]]];
                };
            };
        };
    } else {
        [QGVAR(stop), [_x]] call CBA_fnc_localEvent;
    };
} forEach GVAR(sources);
