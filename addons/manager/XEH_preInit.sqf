#include "script_component.hpp"
ADDON = false;
#include "XEH_PREP.hpp"
ADDON = true;

GVAR(sources) = createHashMap;
GVAR(sourcesTitles) = createHashMap;
GVAR(sourcesStatus) = createHashMap;

// Make sure the extension has been loaded once
EXT callExtension "";

[
    QGVAR(volumeMultiplier),
    "SLIDER",
    LLSTRING(VolumeMultiplier),
    LLSTRING(Category),
    [0.1, 1, 0.3, 2, true],
    0,
    {
        if !(GVAR(streamerMode)) then {
            EXT callExtension ["source:global_gain", [_this]];
        };
    }
] call CBA_fnc_addSetting;

[
    QGVAR(streamerMode),
    "CHECKBOX",
    LLSTRING(StreamerMode),
    LLSTRING(Category),
    false,
    2,
    {
        private _gain = if (_this) then { 0 } else { GVAR(volumeMultiplier) };
        EXT callExtension ["source:global_gain", [_gain]];
    }
] call CBA_fnc_addSetting;

[
    QGVAR(soundRange),
    "SLIDER",
    LLSTRING(SoundRange),
    LLSTRING(Category),
    [0, 1000, 200, 0, false],
    0
] call CBA_fnc_addSetting;

[
    QGVAR(autoOffRange),
    "SLIDER",
    LLSTRING(AutoOffRange),
    LLSTRING(Category),
    [0, 500, 30, 0, false],
    1
] call CBA_fnc_addSetting;

[
    QGVAR(autoOffTime),
    "SLIDER",
    LLSTRING(AutoOffTime),
    LLSTRING(Category),
    [0, 600, 120, 0, false],
    1
] call CBA_fnc_addSetting;
