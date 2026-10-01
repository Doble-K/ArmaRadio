#include "script_component.hpp"

// TFAR Standalone keeps the public SQF side compatible, but its radio DSP is
// native and does not expose the generated static-noise signal to SQF.
if (!isClass (configFile >> "CfgPatches" >> "tfar_core")) exitWith {};

diag_log "[Live Radio][TFAR] Standalone detected; interference provider enabled";
missionNamespace setVariable ["live_radio_tfarAvailable", true];

missionNamespace setVariable ["live_radio_interferenceProvider", {
    private _receivingDistance = player getVariable ["tf_receivingDistanceMultiplicator", 1];
    private _factor = if (_receivingDistance isEqualType 0) then {
        ((_receivingDistance - 1) max 0) min 1
    } else {
        0
    };

    if (missionNamespace getVariable ["live_radio_manager_debugInterference", false]
        && {diag_tickTime - (missionNamespace getVariable ["live_radio_tfar_lastLog", -1]) >= 1}) then {
        missionNamespace setVariable ["live_radio_tfar_lastLog", diag_tickTime];
        diag_log format [
            "[Live Radio][TFAR] interference: receivingDistanceMultiplicator=%1 factor=%2",
            _receivingDistance,
            _factor
        ];
    };

    _factor
}];
