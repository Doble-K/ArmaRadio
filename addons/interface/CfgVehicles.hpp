#define RADIO_CONDITION QUOTE(_target call FUNC(isCompatible) && {_target call FUNC(canOpen)})

#define RADIO_ARR_2(ARG1,ARG2) [ARG1, ARG2]

#define RADIO_QUICK_ACTIONS \
    class GVAR(open) { \
        displayName = CSTRING(Open); \
        statement = QUOTE(_target call FUNC(open)); \
        condition = RADIO_CONDITION; \
    }; \
    class GVAR(power) { \
        displayName = CSTRING(Power); \
        statement = QUOTE([_target] call FUNC(power)); \
        condition = RADIO_CONDITION; \
    }; \
    class GVAR(volumeUp) { \
        displayName = CSTRING(VolumeUp); \
        statement = QUOTE(RADIO_ARR_2(_target,0.1) call FUNC(volumeChange)); \
        condition = RADIO_CONDITION; \
    }; \
    class GVAR(volumeDown) { \
        displayName = CSTRING(VolumeDown); \
        statement = QUOTE(RADIO_ARR_2(_target,-0.1) call FUNC(volumeChange)); \
        condition = RADIO_CONDITION; \
    }; \
    class GVAR(stationNext) { \
        displayName = CSTRING(StationNext); \
        statement = QUOTE(RADIO_ARR_2(_target,1) call FUNC(stationChange)); \
        condition = RADIO_CONDITION; \
    }; \
    class GVAR(stationPrev) { \
        displayName = CSTRING(StationPrev); \
        statement = QUOTE(RADIO_ARR_2(_target,-1) call FUNC(stationChange)); \
        condition = RADIO_CONDITION; \
    };

#define RADIO_SELF_ACTIONS \
    class ACE_SelfActions { \
        class GVAR(menu) { \
            displayName = CSTRING(FMRadio); \
            condition = RADIO_CONDITION; \
            RADIO_QUICK_ACTIONS \
        }; \
    };

#define RADIO_STATIC_ACTIONS \
    class ACE_Actions { \
        class ACE_MainActions { \
            selection = "interaction_point"; \
            distance = 5; \
            class GVAR(menu) { \
                displayName = CSTRING(FMRadio); \
                RADIO_QUICK_ACTIONS \
            }; \
        }; \
    };

class CfgVehicles {
    class LandVehicle;
    class Car: LandVehicle {
        RADIO_SELF_ACTIONS
    };
    class Tank: LandVehicle {
        RADIO_SELF_ACTIONS
    };
    class Air;
    class Helicopter: Air {
        RADIO_SELF_ACTIONS
    };
    class Plane: Air {
        RADIO_SELF_ACTIONS
    };
    class AllVehicles;
    class Ship: AllVehicles {
        RADIO_SELF_ACTIONS
    };

    class Items_base_F;
    class Land_FMradio_F: Items_base_F {
        RADIO_STATIC_ACTIONS
    };

    class Module_F;
    class GVAR(moduleToggleRadio): Module_F {
        scope = 2;
        scopeCurator = 2;
        displayName = CSTRING(ModuleToggleRadio);
        icon = QPATHTOF(ui\music_ca.paa);
        category = "Live Radio";
        function = QFUNC(moduleToggleRadio);
        curatorCanAttach = 1;
        isGlobal = 0;
        isDisposable = 1;
        isTriggerActivated = 0;
    };
};
