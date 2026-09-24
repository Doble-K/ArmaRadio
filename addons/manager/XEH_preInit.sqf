#include "script_component.hpp"
ADDON = false;
#include "XEH_PREP.hpp"
ADDON = true;

GVAR(sources) = createHashMap;
GVAR(sourcesTitles) = createHashMap;
GVAR(sourcesStatus) = createHashMap;
GVAR(nearbyTowers) = [];
GVAR(towersLastScan) = -999;
GVAR(debugInterferenceLastLog) = -1;

// Make sure the extension has been loaded once
EXT callExtension "";

[
    QGVAR(volumeMultiplier),
    "SLIDER",
    [LLSTRING(VolumeMultiplier), LLSTRING(VolumeMultiplierDescription)],
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
    [LLSTRING(StreamerMode), LLSTRING(StreamerModeDescription)],
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
    [LLSTRING(SoundRange), LLSTRING(SoundRangeDescription)],
    LLSTRING(Category),
    [0, 1000, 200, 0, false],
    0
] call CBA_fnc_addSetting;

[
    QGVAR(playClickSound),
    "CHECKBOX",
    [LLSTRING(PlayClickSound), LLSTRING(PlayClickSoundDescription)],
    LLSTRING(Category),
    false,
    2
] call CBA_fnc_addSetting;

[
    QGVAR(enableStatic),
    "CHECKBOX",
    [LLSTRING(EnableStatic), LLSTRING(EnableStaticDescription)],
    LLSTRING(Category),
    true,
    1
] call CBA_fnc_addSetting;

[
    QGVAR(debugInterference),
    "CHECKBOX",
    [LLSTRING(DebugInterference), LLSTRING(DebugInterferenceDescription)],
    LLSTRING(Category),
    false,
    false
] call CBA_fnc_addSetting;

[
    QGVAR(streamFadeOut),
    "SLIDER",
    [LLSTRING(StreamFadeOut), LLSTRING(StreamFadeOutDescription)],
    LLSTRING(Category),
    [0, 1, 1, 2, true],
    1
] call CBA_fnc_addSetting;

[
    QGVAR(enableCone1),
    "CHECKBOX",
    [LLSTRING(EnableCone1), LLSTRING(EnableCone1Description)],
    LLSTRING(Category),
    true,
    false
] call CBA_fnc_addSetting;

[
    QGVAR(enableCone2),
    "CHECKBOX",
    [LLSTRING(EnableCone2), LLSTRING(EnableCone2Description)],
    LLSTRING(Category),
    true,
    false
] call CBA_fnc_addSetting;

[
    QGVAR(enableCone3),
    "CHECKBOX",
    [LLSTRING(EnableCone3), LLSTRING(EnableCone3Description)],
    LLSTRING(Category),
    true,
    false
] call CBA_fnc_addSetting;

[
    QGVAR(cone1OuterRadius),
    "SLIDER",
    [LLSTRING(Cone1OuterRadius), LLSTRING(Cone1OuterRadiusDescription)],
    LLSTRING(Category),
    [0, 3000, 800, 0, false],
    1
] call CBA_fnc_addSetting;

[
    QGVAR(cone2OuterRadius),
    "SLIDER",
    [LLSTRING(Cone2OuterRadius), LLSTRING(Cone2OuterRadiusDescription)],
    LLSTRING(Category),
    [0, 3000, 600, 0, false],
    1
] call CBA_fnc_addSetting;

[
    QGVAR(cone3OuterRadius),
    "SLIDER",
    [LLSTRING(Cone3OuterRadius), LLSTRING(Cone3OuterRadiusDescription)],
    LLSTRING(Category),
    [0, 3000, 400, 0, false],
    1
] call CBA_fnc_addSetting;

[
    QGVAR(cone1InnerRadius),
    "SLIDER",
    [LLSTRING(Cone1InnerRadius), LLSTRING(Cone1InnerRadiusDescription)],
    LLSTRING(Category),
    [0, 3000, 100, 0, false],
    1
] call CBA_fnc_addSetting;

[
    QGVAR(cone2InnerRadius),
    "SLIDER",
    [LLSTRING(Cone2InnerRadius), LLSTRING(Cone2InnerRadiusDescription)],
    LLSTRING(Category),
    [0, 3000, 100, 0, false],
    1
] call CBA_fnc_addSetting;

[
    QGVAR(cone3InnerRadius),
    "SLIDER",
    [LLSTRING(Cone3InnerRadius), LLSTRING(Cone3InnerRadiusDescription)],
    LLSTRING(Category),
    [0, 3000, 100, 0, false],
    1
] call CBA_fnc_addSetting;

[
    QGVAR(cone1VolumeStart),
    "SLIDER",
    [LLSTRING(Cone1VolumeStart), LLSTRING(Cone1VolumeStartDescription)],
    LLSTRING(Category),
    [0, 1, 0, 2, true],
    1
] call CBA_fnc_addSetting;

[
    QGVAR(cone1VolumeEnd),
    "SLIDER",
    [LLSTRING(Cone1VolumeEnd), LLSTRING(Cone1VolumeEndDescription)],
    LLSTRING(Category),
    [0, 1, 1, 2, true],
    1
] call CBA_fnc_addSetting;

[
    QGVAR(cone2VolumeStart),
    "SLIDER",
    [LLSTRING(Cone2VolumeStart), LLSTRING(Cone2VolumeStartDescription)],
    LLSTRING(Category),
    [0, 1, 0, 2, true],
    1
] call CBA_fnc_addSetting;

[
    QGVAR(cone2VolumeEnd),
    "SLIDER",
    [LLSTRING(Cone2VolumeEnd), LLSTRING(Cone2VolumeEndDescription)],
    LLSTRING(Category),
    [0, 1, 1, 2, true],
    1
] call CBA_fnc_addSetting;

[
    QGVAR(cone3VolumeStart),
    "SLIDER",
    [LLSTRING(Cone3VolumeStart), LLSTRING(Cone3VolumeStartDescription)],
    LLSTRING(Category),
    [0, 1, 0, 2, true],
    1
] call CBA_fnc_addSetting;

[
    QGVAR(cone3VolumeEnd),
    "SLIDER",
    [LLSTRING(Cone3VolumeEnd), LLSTRING(Cone3VolumeEndDescription)],
    LLSTRING(Category),
    [0, 1, 1, 2, true],
    1
] call CBA_fnc_addSetting;

[
    QGVAR(enableDamageInterference),
    "CHECKBOX",
    [LLSTRING(EnableDamageInterference), LLSTRING(EnableDamageInterferenceDescription)],
    LLSTRING(Category),
    true,
    false
] call CBA_fnc_addSetting;

[
    QGVAR(enableWeatherInterference),
    "CHECKBOX",
    [LLSTRING(EnableWeatherInterference), LLSTRING(EnableWeatherInterferenceDescription)],
    LLSTRING(Category),
    true,
    false
] call CBA_fnc_addSetting;

[
    QGVAR(enableExplosionInterference),
    "CHECKBOX",
    [LLSTRING(EnableExplosionInterference), LLSTRING(EnableExplosionInterferenceDescription)],
    LLSTRING(Category),
    true,
    false
] call CBA_fnc_addSetting;

[
    QGVAR(enableJammerInterference),
    "CHECKBOX",
    [LLSTRING(EnableJammerInterference), LLSTRING(EnableJammerInterferenceDescription)],
    LLSTRING(Category),
    true,
    false
] call CBA_fnc_addSetting;

[
    QGVAR(enableBurnInterference),
    "CHECKBOX",
    [LLSTRING(EnableBurnInterference), LLSTRING(EnableBurnInterferenceDescription)],
    LLSTRING(Category),
    true,
    false
] call CBA_fnc_addSetting;

[
    QGVAR(enablePersistentRadios),
    "CHECKBOX",
    [LLSTRING(EnablePersistentRadios), LLSTRING(EnablePersistentRadiosDescription)],
    LLSTRING(Category),
    false,
    1
] call CBA_fnc_addSetting;

[
    QGVAR(enableBurn),
    "CHECKBOX",
    [LLSTRING(EnableBurn), LLSTRING(EnableBurnDescription)],
    LLSTRING(Category),
    false,
    1
] call CBA_fnc_addSetting;

[
    QGVAR(burnByWater),
    "CHECKBOX",
    [LLSTRING(BurnByWater), LLSTRING(BurnByWaterDescription)],
    LLSTRING(Category),
    false,
    1
] call CBA_fnc_addSetting;

[
    QGVAR(burnByDamage),
    "CHECKBOX",
    [LLSTRING(BurnByDamage), LLSTRING(BurnByDamageDescription)],
    LLSTRING(Category),
    false,
    1
] call CBA_fnc_addSetting;

[
    QGVAR(autoOffRange),
    "SLIDER",
    [LLSTRING(AutoOffRange), LLSTRING(AutoOffRangeDescription)],
    LLSTRING(Category),
    [0, 500, 30, 0, false],
    1
] call CBA_fnc_addSetting;

[
    QGVAR(autoOffTime),
    "SLIDER",
    [LLSTRING(AutoOffTime), LLSTRING(AutoOffTimeDescription)],
    LLSTRING(Category),
    [0, 600, 120, 0, false],
    1
] call CBA_fnc_addSetting;

[
    QGVAR(interferenceTowers),
    "EDITBOX",
    [LLSTRING(InterferenceTowers), LLSTRING(InterferenceTowersDescription)],
    LLSTRING(Category),
    "[""Land_Communication_F"",""Land_TTowerBig_1_F"",""Land_TTowerBig_2_F"",""Land_TTowerBig_2_ruins_F"",""Land_TTowerSmall_1_F"",""Land_TTowerSmall_2_F""]",
    1
] call CBA_fnc_addSetting;

[
    QGVAR(interferenceTowerRadius),
    "SLIDER",
    [LLSTRING(InterferenceTowerRadius), LLSTRING(InterferenceTowerRadiusDescription)],
    LLSTRING(Category),
    [0, 3000, 1000, 0, false],
    1
] call CBA_fnc_addSetting;

[
    QGVAR(interferenceTowerStrength),
    "SLIDER",
    [LLSTRING(InterferenceTowerStrength), LLSTRING(InterferenceTowerStrengthDescription)],
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
    QGVAR(radioMotorDamageThreshold),
    "SLIDER",
    [LLSTRING(RadioMotorDamageThreshold), LLSTRING(RadioMotorDamageThresholdDescription)],
    LLSTRING(Category),
    [0, 1, 0.8, 2, false],
    1
] call CBA_fnc_addSetting;

[
    QGVAR(underwaterBurnTime),
    "SLIDER",
    [LLSTRING(UnderwaterBurnTime), LLSTRING(UnderwaterBurnTimeDescription)],
    LLSTRING(Category),
    [0, 120, 10, 0, false],
    1
] call CBA_fnc_addSetting;
