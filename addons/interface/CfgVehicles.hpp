#define RADIO_CONDITION QUOTE(_target call FUNC(isCompatible) && {_target call FUNC(canOpen)})

#define REPAIR_CONDITION QUOTE(_target call FUNC(isBurned) && {[_player] call FUNC(canRepair)})

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
    class GVAR(setVolume) { \
        displayName = CSTRING(SetVolume); \
        condition = RADIO_CONDITION; \
        class GVAR(setVolume0) { \
            displayName = "0%"; \
            statement = QUOTE(RADIO_ARR_2(_target,0) call EFUNC(manager,volume)); \
            condition = RADIO_CONDITION; \
        }; \
        class GVAR(setVolume25) { \
            displayName = "25%"; \
            statement = QUOTE(RADIO_ARR_2(_target,0.25) call EFUNC(manager,volume)); \
            condition = RADIO_CONDITION; \
        }; \
        class GVAR(setVolume50) { \
            displayName = "50%"; \
            statement = QUOTE(RADIO_ARR_2(_target,0.5) call EFUNC(manager,volume)); \
            condition = RADIO_CONDITION; \
        }; \
        class GVAR(setVolume100) { \
            displayName = "100%"; \
            statement = QUOTE(RADIO_ARR_2(_target,1) call EFUNC(manager,volume)); \
            condition = RADIO_CONDITION; \
        }; \
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
    }; \
    class GVAR(repair) { \
        displayName = CSTRING(Repair); \
        statement = QUOTE([_target] call FUNC(repair)); \
        condition = REPAIR_CONDITION; \
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

#define RADIO_EXTERNAL_REPAIR \
    class ACE_Actions { \
        class ACE_MainActions { \
            class GVAR(repairRadio) { \
                displayName = CSTRING(Repair); \
                statement = QUOTE([_target] call FUNC(repair)); \
                condition = REPAIR_CONDITION; \
                distance = 5; \
            }; \
        }; \
    };

class CfgVehicles {
    class LandVehicle;
    class Car: LandVehicle {
        RADIO_SELF_ACTIONS
        RADIO_EXTERNAL_REPAIR
    };
    class Tank: LandVehicle {
        RADIO_SELF_ACTIONS
        RADIO_EXTERNAL_REPAIR
    };
    class Air;
    class Helicopter: Air {
        RADIO_SELF_ACTIONS
        RADIO_EXTERNAL_REPAIR
    };
    class Plane: Air {
        RADIO_SELF_ACTIONS
        RADIO_EXTERNAL_REPAIR
    };
    class AllVehicles;
    class Ship: AllVehicles {
        RADIO_SELF_ACTIONS
        RADIO_EXTERNAL_REPAIR
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
