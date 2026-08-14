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
private _towerFactor = [_player] call FUNC(towerFactor);

// Crows-EW / TFAR radio jammer interference
private _jamFactor = [_player] call FUNC(jamFactor);

{
    if (alive _y) then {
        private _pos = getPosASL _y;
        private _data = [_x, 0, 0, 0];
        if (_inZeus || {!(_y isEqualTo vehicle _player)}) then {
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

        private _damage = linearConversion [0, 1, getDammage _y, 0, 1, true];
        private _storm = 0.2 * rain;
        private _explosion = linearConversion [10, 0, time - GVAR(lastExplosion), 0, 1, true];
        private _burn = [_y] call FUNC(burn);
        private _target = (_damage + _storm + _explosion + _towerFactor + _jamFactor + _burn) min 1;

        private _current = _y getVariable [QGVAR(quality), 0];
        private _step = diag_deltaTime * 2;
        private _delta = _target - _current;
        private _smoothed = _current + (_delta min _step max -_step);
        if (abs (_smoothed - _current) > 0.005) then {
            _y setVariable [QGVAR(quality), _smoothed];
            EXT callExtension ["source:quality", [_x, _smoothed]];
        };

        if (diag_tickTime - (_y getVariable [QGVAR(lastExistsCheck), 0]) > 2) then {
            _y setVariable [QGVAR(lastExistsCheck), diag_tickTime];
            if (((EXT callExtension ["source:exists", [_x]]) select 0) isEqualTo "0") then {
                private _active = _y getVariable [QGVAR(active), []];
                if !(_active isEqualTo []) then {
                    EXT callExtension ["source:new", [_x, _active param [1, ""], _y getVariable [QGVAR(volume), 1]]];
                };
            };
        };
    } else {
        [QGVAR(stop), [_x]] call CBA_fnc_localEvent;
    };
} forEach GVAR(sources);
