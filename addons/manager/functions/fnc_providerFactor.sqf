#include "script_component.hpp"
/*
 * Reads the optional local interference provider.
 *
 * Return Value:
 * Number <NUMBER> -- normalized external interference factor in [0, 1]
 */

private _provider = missionNamespace getVariable ["live_radio_interferenceProvider", {}];
if !(_provider isEqualType {}) exitWith { 0 };

private _factor = call _provider;
if !(_factor isEqualType 0) exitWith { 0 };

_factor max 0 min 1
