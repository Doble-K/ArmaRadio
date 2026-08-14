#include "script_component.hpp"
/*
 * Author: matidp4
 * Changes the radio volume for the given object.
 *
 * Arguments:
 * 0: Object <OBJECT>
 * 1: Change <NUMBER> (default: 0.1)
 *
 * Return Value:
 * None
 *
 * Example:
 * [_object, 0.1] call live_radio_interface_fnc_volumeChange
 *
 * Public: No
 */

params ["_object", ["_change", 0.1]];

private _volume = _object getVariable [QEGVAR(manager,volume), DEFAULT_VOLUME];
_volume = ((_volume + _change) min MAX_VOLUME) max MIN_VOLUME;

[_object, _volume] call EFUNC(manager,volume);
