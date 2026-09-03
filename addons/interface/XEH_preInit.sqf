#include "script_component.hpp"

ADDON = false;

#include "XEH_PREP.hpp"

ADDON = true;

GVAR(stations) = [];

[
    QGVAR(customStations),
    "EDITBOX",
    [LLSTRING(CustomStations), LLSTRING(CustomStationsDescription)],
    LLSTRING(Category),
    "[[""Classic Rock 109"",""http://listen.classicrock109.com:10042""],[""PulseEDM Dance Music"",""http://pulseedm.cdnstream1.com:8124/1373_128""],[""Live Ireland"",""http://192.111.140.11:8058/stream?type=http&nocache=325927""]]",
    1,
    {
        call FUNC(buildStations);

        private _display = uiNamespace getVariable [QGVAR(display), displayNull];
        if (!isNull _display) then {
            [_display] call FUNC(updateList);
        };
    }
] call CBA_fnc_addSetting;

call FUNC(buildStations);

[
    QGVAR(driverAndCommanderOnly),
    "CHECKBOX",
    [LLSTRING(DriverAndCommanderOnly), LLSTRING(DriverAndCommanderOnlyDescription)],
    LLSTRING(Category),
    true,
    1
] call CBA_fnc_addSetting;

[
    QGVAR(mainGunnerAndCopilotCanControl),
    "CHECKBOX",
    [LLSTRING(MainGunnerAndCopilotCanControl), LLSTRING(MainGunnerAndCopilotCanControlDescription)],
    LLSTRING(Category),
    true,
    1
] call CBA_fnc_addSetting;

[
    QGVAR(allGunnersCanControl),
    "CHECKBOX",
    [LLSTRING(AllGunnersCanControl), LLSTRING(AllGunnersCanControlDescription)],
    LLSTRING(Category),
    false,
    1
] call CBA_fnc_addSetting;

[
    QGVAR(enableCars),
    "CHECKBOX",
    [LLSTRING(EnableCars), LLSTRING(EnableCarsDescription)],
    LLSTRING(Category),
    true,
    1
] call CBA_fnc_addSetting;

[
    QGVAR(enableArmored),
    "CHECKBOX",
    [LLSTRING(EnableArmored), LLSTRING(EnableArmoredDescription)],
    LLSTRING(Category),
    false,
    1
] call CBA_fnc_addSetting;

[
    QGVAR(enableHelicopters),
    "CHECKBOX",
    [LLSTRING(EnableHelicopters), LLSTRING(EnableHelicoptersDescription)],
    LLSTRING(Category),
    false,
    1
] call CBA_fnc_addSetting;

[
    QGVAR(enablePlanes),
    "CHECKBOX",
    [LLSTRING(EnablePlanes), LLSTRING(EnablePlanesDescription)],
    LLSTRING(Category),
    false,
    1
] call CBA_fnc_addSetting;

[
    QGVAR(enableShips),
    "CHECKBOX",
    [LLSTRING(EnableShips), LLSTRING(EnableShipsDescription)],
    LLSTRING(Category),
    false,
    1
] call CBA_fnc_addSetting;

[
    QGVAR(customVehicleClasses),
    "EDITBOX",
    [LLSTRING(CustomVehicleClasses), LLSTRING(CustomVehicleClassesDescription)],
    LLSTRING(Category),
    "[]",
    1
] call CBA_fnc_addSetting;
