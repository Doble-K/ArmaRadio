#include "script_component.hpp"
/*
 * Author: Doble-K
 * Checks if the radio of the given object is burned out.
 *
 * Arguments:
 * 0: Object <OBJECT>
 *
 * Return Value:
 * BOOLEAN
 *
 * Example:
 * [_vehicle] call live_radio_interface_fnc_isBurned
 *
 * Public: No
 */

params ["_object"];

_object getVariable [QEGVAR(manager,burned), false]
