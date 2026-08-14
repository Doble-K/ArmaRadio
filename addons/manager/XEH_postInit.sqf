#include "script_component.hpp"

if (hasInterface) then {
    private _gain = [GVAR(volumeMultiplier), 0] select (GVAR(streamerMode));
    EXT callExtension ["source:global_gain", [_gain]];

    GVAR(lastExplosion) = -999;
    addMissionEventHandler ["Explosion", {
        GVAR(lastExplosion) = time;
    }];

    [QGVAR(start), {
        params ["_id", "_url", "_source"];
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
        EXT callExtension ["source:gain", [_id, _gain]];
    }] call CBA_fnc_addEventHandler;

    [FUNC(tick)] call CBA_fnc_addPerFrameHandler;
    [FUNC(heartbeat), 0.75] call CBA_fnc_addPerFrameHandler;

    {
        private _active = _x getVariable [QGVAR(active), []];
        if !(_action isEqualTo []) then {
            [QGVAR(start), [_active#0, _active#1, _x]] call CBA_fnc_localEvent;
        };
    } forEach allMissionObjects "";
};

if (isServer && !hasInterface) then {
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

    if ((tolower _name) isEqualTo "live_radio_log") exitWith {
        LOG_SYS(_function,_data);
    };
    if !((tolower _name) isEqualTo "live_radio") exitWith {};
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
