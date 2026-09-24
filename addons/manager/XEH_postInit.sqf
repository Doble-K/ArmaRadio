#include "script_component.hpp"

if (hasInterface) then {
    [GVAR(volumeMultiplier)] call FUNC(applyGain);

    GVAR(explosionEvents) = [];
    private _registerExplosionHandlers = {
        {
            if (isNil {_x getVariable QGVAR(explosionHandler)}) then {
                _x setVariable [QGVAR(explosionHandler), _x addEventHandler ["Explosion", {
                    params ["_object", "_damage", "_type"];
                    private _hit = if (_type isEqualType "") then {
                        getNumber (configFile >> "CfgAmmo" >> _type >> "hit")
                    } else {
                        1
                    };
                    private _intensity = linearConversion [0, 100, ((_damage max _hit) max 1), 0, 1, true];
                    GVAR(explosionEvents) pushBack [getPosASL _object, time, _intensity];
                    GVAR(explosionEvents) = GVAR(explosionEvents) select { time - (_x#1) < 4 };
                }]];
            };
        } forEach allMissionObjects "";
    };
    call _registerExplosionHandlers;
    [{
        params ["_registerExplosionHandlers"];
        call _registerExplosionHandlers;
    }, 1, [_registerExplosionHandlers]] call CBA_fnc_addPerFrameHandler;

    GVAR(hearingFactor) = -1;
    [{
        private _factor = 1;
        if (isClass (configFile >> "CfgPatches" >> "ace_hearing")) then {
            _factor = (missionNamespace getVariable ["ace_hearing_volume", 1])
                * (missionNamespace getVariable ["ace_hearing_volumeAttenuation", 1]);
        };
        if (_factor != GVAR(hearingFactor)) then {
            GVAR(hearingFactor) = _factor;
            [GVAR(volumeMultiplier)] call FUNC(applyGain);
        };
    }] call CBA_fnc_addPerFrameHandler;

    [QGVAR(start), {
        params ["_id", "_url", "_source"];

        // A fast station change can deliver start before the previous stop has
        // removed the old local source. Keep one OpenAL source per object.
        {
            EXT callExtension ["source:destroy", [_x]];
            GVAR(sources) deleteAt _x;
        } forEach ((keys GVAR(sources)) select {
            (GVAR(sources) get _x) isEqualTo _source && {_x isNotEqualTo _id}
        });

        EXT callExtension ["source:new", [_id, _url, _source getVariable [QGVAR(volume), 1]]];
        GVAR(sources) set [_id, _source];
        [QGVAR(metadataUpdated), [_id, ""]] call CBA_fnc_localEvent;
    }] call CBA_fnc_addEventHandler;

    [QGVAR(stop), {
        params ["_id"];
        EXT callExtension ["source:destroy", [_id]];
        GVAR(sources) deleteAt _id;
        GVAR(sourcesTitles) deleteAt _id;
        GVAR(sourcesStatus) deleteAt _id;
    }] call CBA_fnc_addEventHandler;

    [QGVAR(volume), {
        params ["_id", "_gain"];
        private _object = GVAR(sources) getOrDefault [_id, objNull];
        if (_object getVariable [QGVAR(outOfRange), false]) then {
            _gain = 0;
        };
        EXT callExtension ["source:gain", [_id, _gain]];
    }] call CBA_fnc_addEventHandler;

    [FUNC(tick)] call CBA_fnc_addPerFrameHandler;
    [FUNC(heartbeat), 0.75] call CBA_fnc_addPerFrameHandler;

    {
        private _active = _x getVariable [QGVAR(active), []];
        if (_active isNotEqualTo []) then {
            [QGVAR(start), [_active#0, _active#1, _x]] call CBA_fnc_localEvent;
        };
    } forEach allMissionObjects "";
};

if (isServer) then {
    GVAR(autoOffLastCheck) = 0;
    [{
        if (time - GVAR(autoOffLastCheck) < 2) exitWith {};
        GVAR(autoOffLastCheck) = time;

        if (GVAR(autoOffRange) <= 0 || GVAR(autoOffTime) <= 0) exitWith {};

        private _players = allUnits select { isPlayer _x };
        {
            private _object = _x;
            if (_object getVariable [QGVAR(active), []] isNotEqualTo []) then {
                private _near = false;
                {
                    if ((_x distance _object) < GVAR(autoOffRange)) exitWith { _near = true; };
                } forEach _players;

                if (_near) then {
                    _object setVariable [QGVAR(autoOffLastSeen), time];
                } else {
                    private _lastSeen = _object getVariable [QGVAR(autoOffLastSeen), time];
                    if (time - _lastSeen >= GVAR(autoOffTime)) then {
                        [_object, ""] call FUNC(play);
                    };
                };
            };
        } forEach allMissionObjects "";
    }] call CBA_fnc_addPerFrameHandler;
};

addMissionEventHandler ["ExtensionCallback", {
    params ["_name", "_function", "_data"];

    if ((toLower _name) isEqualTo "live_radio_log") exitWith {
        LOG_SYS(_function,_data);
    };
    if ((toLower _name) isNotEqualTo "live_radio") exitWith {};
    switch (_function) do {
        case "title": {
            (parseSimpleArray _data) params ["_id", "_title"];
            GVAR(sourcesTitles) set [_id, _title];
            [QGVAR(metadataUpdated), [_id, _title]] call CBA_fnc_localEvent;
        };
        case "status": {
            (parseSimpleArray _data) params ["_id", "_status"];
            GVAR(sourcesStatus) set [_id, _status];
            [QGVAR(metadataUpdated), [_id, ""]] call CBA_fnc_localEvent;
        };
    };
}];
