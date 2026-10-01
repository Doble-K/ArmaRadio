#include "script_component.hpp"

if (!isClass (configFile >> "CfgPatches" >> "tfar_core")) exitWith {
    diag_log "[Live Radio][TFAR Realtime] TFAR Standalone not detected; backend unavailable";
};

missionNamespace setVariable ["live_radio_tfarRealtimeAvailable", true];
if (missionNamespace getVariable ["live_radio_manager_debugTfarRealtime", false]) then {
    diag_log "[Live Radio][TFAR Realtime] backend registered; native realtime audio is pending";
};
