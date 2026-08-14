#include "script_component.hpp"
ADDON = false;
#include "XEH_PREP.hpp"
ADDON = true;

GVAR(sources) = createHashMap;
GVAR(sourcesTitles) = createHashMap;
GVAR(sourcesStatus) = createHashMap;
GVAR(nearbyTowers) = [];
GVAR(towersLastScan) = -999;

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
        [_this] call FUNC(applyGain);
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
        [GVAR(volumeMultiplier)] call FUNC(applyGain);
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
    QGVAR(playClickSound),
    "CHECKBOX",
    LLSTRING(PlayClickSound),
    LLSTRING(Category),
    false,
    2
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

[
    QGVAR(interferenceTowers),
    "EDITBOX",
    [LLSTRING(InterferenceTowers), LLSTRING(InterferenceTowersDescription)],
    LLSTRING(Category),
    "[""Land_Communication_F""]",
    1
] call CBA_fnc_addSetting;

[
    QGVAR(interferenceTowerRadius),
    "SLIDER",
    LLSTRING(InterferenceTowerRadius),
    LLSTRING(Category),
    [0, 3000, 1000, 0, false],
    1
] call CBA_fnc_addSetting;

[
    QGVAR(interferenceTowerStrength),
    "SLIDER",
    LLSTRING(InterferenceTowerStrength),
    LLSTRING(Category),
    [0, 1, 0.5, 2, false],
    1
] call CBA_fnc_addSetting;

[
    QGVAR(interferenceTowerSideFilter),
    "CHECKBOX",
    [LLSTRING(InterferenceTowerSideFilter), LLSTRING(InterferenceTowerSideFilterDescription)],
    LLSTRING(Category),
    false,
    1
] call CBA_fnc_addSetting;

[
    QGVAR(radioBurnDamage),
    "SLIDER",
    LLSTRING(RadioBurnDamage),
    LLSTRING(Category),
    [0, 1, 0.8, 2, false],
    1
] call CBA_fnc_addSetting;

[
    QGVAR(underwaterBurnTime),
    "SLIDER",
    LLSTRING(UnderwaterBurnTime),
    LLSTRING(Category),
    [0, 120, 10, 0, false],
    1
] call CBA_fnc_addSetting;
