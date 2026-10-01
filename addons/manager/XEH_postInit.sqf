#include "script_component.hpp"

private _requestedAudioMode = GVAR(audioMode);
GVAR(audioModeEffective) = switch (_requestedAudioMode) do {
    case 1: {
        parseNumber (missionNamespace getVariable ["live_radio_tfarAvailable", false])
    };
    case 2: {
        if !(missionNamespace getVariable ["live_radio_tfarAvailable", false]) then {
            0
        } else {
            [1, 2] select (missionNamespace getVariable ["live_radio_tfarRealtimeAvailable", false])
        }
    };
    default { 0 };
};
if (_requestedAudioMode != GVAR(audioModeEffective)) then {
    diag_log format [
        "[Live Radio][Audio] requested backend=%1 unavailable; using backend=%2",
        _requestedAudioMode,
        GVAR(audioModeEffective)
    ];
};
if (GVAR(debugTfarRealtime)) then {
    diag_log format [
        "[Live Radio][TFAR Realtime] requested=%1 effective=%2 tfar=%3 realtimePbo=%4",
        _requestedAudioMode,
        GVAR(audioModeEffective),
        missionNamespace getVariable ["live_radio_tfarAvailable", false],
        missionNamespace getVariable ["live_radio_tfarRealtimeAvailable", false]
    ];
};

if (hasInterface) then {
    [GVAR(volumeMultiplier)] call FUNC(applyGain);

    GVAR(explosionEvents) = [];

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

        if (GVAR(debugAudio)) then {
            diag_log format [
                "[Live Radio][Audio] local start id=%1 source=%2 type=%3 url=%4 existing=%5",
                _id,
                _source,
                typeOf _source,
                _url,
                keys GVAR(sources)
            ];
        };

        // Personal radios are earphone-only and must never be heard by other clients.
        if (_source isKindOf "Man" && {_source isNotEqualTo player}) exitWith {};

        // A fast station change can deliver start before the previous stop has
        // removed the old local source. Keep one OpenAL source per object.
        {
            if (GVAR(debugAudio)) then {
                diag_log format [
                    "[Live Radio][Audio] duplicate prevention id=%1 replacingId=%2 source=%3",
                    _id,
                    _x,
                    _source
                ];
            };
            EXT callExtension ["source:destroy", [_x]];
            GVAR(sources) deleteAt _x;
        } forEach ((keys GVAR(sources)) select {
            (GVAR(sources) get _x) isEqualTo _source && {_x isNotEqualTo _id}
        });

        EXT callExtension ["source:new", [_id, _url, _source getVariable [QGVAR(volume), 1]]];
        _source setVariable [QGVAR(interferenceNeedsInit), true];
        GVAR(sources) set [_id, _source];
        if (GVAR(debugAudio)) then {
            diag_log format ["[Live Radio][Audio] local source created id=%1 activeSources=%2", _id, keys GVAR(sources)];
        };
        [QGVAR(metadataUpdated), [_id, ""]] call CBA_fnc_localEvent;
    }] call CBA_fnc_addEventHandler;

    [QGVAR(stop), {
        params ["_id"];
        private _known = GVAR(sources) getOrDefault [_id, objNull];
        if (GVAR(debugAudio)) then {
            diag_log format ["[Live Radio][Audio] local stop id=%1 known=%2 source=%3", _id, _known isNotEqualTo objNull, _known];
        };
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
    } forEach ([player] + allMissionObjects "");
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
            private _previousStatus = GVAR(sourcesStatus) getOrDefault [_id, "unknown"];
            GVAR(sourcesStatus) set [_id, _status];
            if (GVAR(debugAudio) && {_status isNotEqualTo _previousStatus}) then {
                diag_log format [
                    "[Live Radio][Audio] status change id=%1 previous=%2 current=%3 activeSources=%4",
                    _id,
                    _previousStatus,
                    _status,
                    keys GVAR(sources)
                ];
            };
            [QGVAR(metadataUpdated), [_id, ""]] call CBA_fnc_localEvent;
        };
    };
}];
