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

{
    if (alive _y) then {
        private _pos = getPosASL _y;
        private _data = [_x, 0, 0, 0];
        if (_inZeus || {!(_y isEqualTo vehicle _player)}) then {
            private _ppos = eyePos _player;
            if (_inZeus) then {
                _ppos = getPosASL curatorCamera;
            };
            private _outOfRange = (_pos distance _ppos) > _range;
            if (_outOfRange != (_y getVariable [QGVAR(outOfRange), false])) then {
                _y setVariable [QGVAR(outOfRange), _outOfRange, true];
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

        private _quality = linearConversion [0, 1, getDammage _y, 0, 1, true];
        if (_quality != (_y getVariable [QGVAR(quality), 0])) then {
            _y setVariable [QGVAR(quality), _quality];
            EXT callExtension ["source:quality", [_x, _quality]];
        };
    } else {
        [QGVAR(stop), [_x]] call CBA_fnc_localEvent;
    };
} forEach GVAR(sources);
